-------------------------------------------------------------------------------
-- File: axi4s_fifo_tb.vhdl
--
-- Self-checking testbench for axi4s_fifo (synchronous packet-to-packet FIFO).
--
-- Drives random-length packets into the write side and randomly stalls
-- valid/ready on both sides, checking:
--   1) Data/tlast integrity and ordering against a software scoreboard.
--   2) The defining "packet to packet" property: s1_axis_tvalid must never
--      assert unless a complete packet has been written and not yet fully
--      read out.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;
  use std.env.all;

entity axi4s_fifo_tb is
end entity axi4s_fifo_tb;

architecture sim of axi4s_fifo_tb is

  constant C_WIDTH      : natural := 8;
  constant C_DEPTH      : natural := 8;
  constant C_CLK_PERIOD : time    := 10 ns;
  constant C_NUM_PACKETS : natural := 60;
  constant C_MAX_PKT_LEN : natural := 6;
  constant C_STALL_PCT   : real    := 0.3;
  constant C_TIMEOUT     : time    := 200 us;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal s0_valid : std_logic := '0';
  signal s0_data  : std_logic_vector(C_WIDTH - 1 downto 0) := (others => '0');
  signal s0_last  : std_logic := '0';
  signal s0_ready : std_logic;

  signal s1_ready : std_logic := '0';
  signal s1_data  : std_logic_vector(C_WIDTH - 1 downto 0);
  signal s1_last  : std_logic;
  signal s1_valid : std_logic;

  signal pkt_ready : std_logic;

  signal write_done : std_logic := '0';
  signal read_done   : std_logic := '0';

  signal wr_pkts_done : integer := 0;
  signal rd_pkts_done : integer := 0;

  signal n_errors  : integer := 0;
  signal n_checked : integer := 0;

  type t_q_entry is record
    data : std_logic_vector(C_WIDTH - 1 downto 0);
    last : std_logic;
  end record;

  type t_q_array is array (0 to 2047) of t_q_entry;

  type t_scoreboard is protected
    procedure push(data : std_logic_vector(C_WIDTH - 1 downto 0); last : std_logic);
    procedure pop(data : out std_logic_vector(C_WIDTH - 1 downto 0); last : out std_logic; ok : out boolean);
    impure function count return integer;
  end protected t_scoreboard;

  type t_scoreboard is protected body
    variable v_arr  : t_q_array;
    variable v_head : integer := 0;
    variable v_tail : integer := 0;
    variable v_cnt  : integer := 0;

    procedure push(data : std_logic_vector(C_WIDTH - 1 downto 0); last : std_logic) is
    begin
      v_arr(v_tail).data := data;
      v_arr(v_tail).last := last;
      v_tail := (v_tail + 1) mod v_arr'length;
      v_cnt  := v_cnt + 1;
    end procedure push;

    procedure pop(data : out std_logic_vector(C_WIDTH - 1 downto 0); last : out std_logic; ok : out boolean) is
    begin
      if v_cnt = 0 then
        ok   := false;
        data := (others => '0');
        last := '0';
      else
        data   := v_arr(v_head).data;
        last   := v_arr(v_head).last;
        v_head := (v_head + 1) mod v_arr'length;
        v_cnt  := v_cnt - 1;
        ok     := true;
      end if;
    end procedure pop;

    impure function count return integer is
    begin
      return v_cnt;
    end function count;
  end protected body t_scoreboard;

  shared variable scoreboard : t_scoreboard;

begin

  clk <= not clk after C_CLK_PERIOD / 2;

  p_rst : process is
  begin
    rst <= '1';
    wait for C_CLK_PERIOD * 5;
    rst <= '0';
    wait;
  end process p_rst;

  p_watchdog : process is
  begin
    wait for C_TIMEOUT;
    assert false report "TIMEOUT: simulation did not complete in time" severity failure;
    wait;
  end process p_watchdog;

  u_dut : entity work.axi4s_fifo
    generic map (
      G_WIDTH => C_WIDTH,
      G_DEPTH => C_DEPTH
    )
    port map (
      i_rst_sync     => rst,
      s0_axis_aclk   => clk,
      s1_axis_aclk   => clk,
      s0_axis_tvalid => s0_valid,
      s0_axis_tdata  => s0_data,
      s0_axis_tlast  => s0_last,
      s1_axis_tready => s1_ready,
      s1_axis_tdata  => s1_data,
      s1_axis_tlast  => s1_last,
      o_pkt_ready    => pkt_ready,
      s0_axis_tready => s0_ready,
      s1_axis_tvalid => s1_valid
    );

  -- Core "packet to packet" invariant: tvalid must never assert unless at
  -- least one fully-written packet has not yet been completely read out.
  p_check_gating : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '0' then
        assert not (s1_valid = '1' and rd_pkts_done >= wr_pkts_done)
          report "PACKET GATING VIOLATION: s1_axis_tvalid asserted without a complete buffered packet"
          severity error;

        assert pkt_ready = s1_valid
          report "o_pkt_ready / s1_axis_tvalid MISMATCH: expected these to always be equal"
          severity error;
      end if;
    end if;
  end process p_check_gating;

  p_write : process is
    variable seed1    : positive := 7;
    variable seed2    : positive := 13;
    variable rnd      : real;
    variable pkt_len  : natural;
    variable data_val : std_logic_vector(C_WIDTH - 1 downto 0);
    variable is_last  : std_logic;
    variable data_int : integer;
  begin
    s0_valid <= '0';
    wait until rst = '0';
    wait until rising_edge(clk);

    for p in 0 to C_NUM_PACKETS - 1 loop
      uniform(seed1, seed2, rnd);
      pkt_len := 1 + integer(rnd * real(C_MAX_PKT_LEN - 1));

      for b in 0 to pkt_len - 1 loop

        uniform(seed1, seed2, rnd);
        if rnd < C_STALL_PCT then
          s0_valid <= '0';
          wait until rising_edge(clk);
        end if;

        uniform(seed1, seed2, rnd);
        data_int := integer(rnd * 255.0);
        data_val := std_logic_vector(to_unsigned(data_int, C_WIDTH));

        if b = pkt_len - 1 then
          is_last := '1';
        else
          is_last := '0';
        end if;

        s0_data  <= data_val;
        s0_last  <= is_last;
        s0_valid <= '1';

        loop
          wait until rising_edge(clk);
          exit when s0_ready = '1';
        end loop;

        scoreboard.push(data_val, is_last);
        if is_last = '1' then
          wr_pkts_done <= wr_pkts_done + 1;
        end if;

      end loop;
    end loop;

    s0_valid <= '0';
    wait until rising_edge(clk);
    write_done <= '1';
    wait;
  end process p_write;

  p_read : process is
    variable seed1  : positive := 101;
    variable seed2  : positive := 202;
    variable rnd    : real;
    variable q_data : std_logic_vector(C_WIDTH - 1 downto 0);
    variable q_last : std_logic;
    variable q_ok   : boolean;
  begin
    s1_ready <= '0';
    wait until rst = '0';
    wait until rising_edge(clk);

    loop
      exit when (write_done = '1' and scoreboard.count = 0);

      uniform(seed1, seed2, rnd);
      if rnd < C_STALL_PCT then
        s1_ready <= '0';
      else
        s1_ready <= '1';
      end if;

      wait until rising_edge(clk);

      if s1_valid = '1' and s1_ready = '1' then
        scoreboard.pop(q_data, q_last, q_ok);
        n_checked <= n_checked + 1;

        if not q_ok then
          n_errors <= n_errors + 1;
          report "ERROR: read beat accepted but scoreboard is empty" severity error;
        else
          if s1_data /= q_data then
            n_errors <= n_errors + 1;
            report "ERROR: data mismatch, got " & to_hstring(s1_data) & " expected " & to_hstring(q_data) severity error;
          end if;
          if s1_last /= q_last then
            n_errors <= n_errors + 1;
            report "ERROR: tlast mismatch" severity error;
          end if;
        end if;

        if q_last = '1' then
          rd_pkts_done <= rd_pkts_done + 1;
        end if;
      end if;
    end loop;

    s1_ready  <= '0';
    read_done <= '1';
    wait;
  end process p_read;

  p_finish : process is
  begin
    wait until read_done = '1';
    wait for C_CLK_PERIOD * 2;
    report "----------------------------------------------------";
    report "Beats checked : " & integer'image(n_checked);
    report "Errors        : " & integer'image(n_errors);
    if n_errors = 0 then
      report "TEST PASSED";
    else
      report "TEST FAILED" severity error;
    end if;
    report "----------------------------------------------------";
    std.env.finish;
  end process p_finish;

end architecture sim;
