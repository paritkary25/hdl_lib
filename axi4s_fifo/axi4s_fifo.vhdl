-------------------------------------------------------------------------------
-- File: axi4s_fifo.vhdl
-- Author: Y.U.P.
-- Last modified: 2026/07/08 20:36
--
-- Description: Synchronous AXI4Stream packet to packet FIFO
-- Do short the clock ports
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.all;

entity axi4s_fifo is
  generic (
    G_WIDTH : natural := 64;
    G_DEPTH : integer := 2048
  );
  port (
    i_rst_sync   : in    std_logic;
    s0_axis_aclk : in    std_logic;
    s1_axis_aclk : in    std_logic;

    -- FIFO Write Interface
    s0_axis_tvalid : in    std_logic;
    s0_axis_tdata  : in    std_logic_vector(G_WIDTH - 1 downto 0);
    s0_axis_tlast  : in    std_logic;

    -- FIFO Read Interface
    s1_axis_tready : in    std_logic;
    s1_axis_tdata  : out   std_logic_vector(G_WIDTH - 1 downto 0);
    s1_axis_tlast  : out   std_logic;

    -- Occupancy indicators
    o_pkt_ready : out   std_logic;

    s0_axis_tready : out   std_logic;
    s1_axis_tvalid : out   std_logic
  );
end entity axi4s_fifo;

architecture rtl of axi4s_fifo is

  constant C_ADDR_WIDTH : integer := integer(ceil(log2(real(G_DEPTH))));

  type t_fifo_data is array (0 to g_DEPTH - 1) of std_logic_vector(G_WIDTH downto 0);

  signal r_fifo_data : t_fifo_data := (others => (others => '0'));

  signal r_wr_index : unsigned(C_ADDR_WIDTH  downto 0) := (others => '0');
  signal r_rd_index : unsigned(C_ADDR_WIDTH  downto 0) := (others => '0');

  -- Keep track of number of packets inside the FIFO
  -- Converts this to packet to packet FIFO
  signal npkt_inside : unsigned(C_ADDR_WIDTH  downto 0) := (others => '0');

  signal w_full  : std_logic;
  signal w_empty : std_logic;

  signal w_wr_data : std_logic_vector(G_WIDTH downto 0);

  -- Pulse high for one cycle when a write/read completes a whole packet.
  -- npkt_inside must only ever be driven by one process (p_npkt below) -
  -- driving it from both p_write and p_read would create two drivers on
  -- the same signal and corrupt it via std_logic resolution.
  signal w_wr_pkt_done : std_logic;
  signal w_rd_pkt_done : std_logic;

begin

  w_empty <= '1' when (r_wr_index = r_rd_index) else
             '0';
  w_full  <= '1' when (r_wr_index(C_ADDR_WIDTH - 1 downto 0) = r_rd_index(C_ADDR_WIDTH - 1 downto 0) and
                        r_wr_index(C_ADDR_WIDTH) /= r_rd_index(C_ADDR_WIDTH)) else
             '0';

  w_wr_pkt_done <= '1' when (s0_axis_tvalid = '1' and w_full = '0' and s0_axis_tlast = '1') else
                   '0';
  w_rd_pkt_done <= '1' when (s1_axis_tready = '1' and s1_axis_tvalid = '1' and s1_axis_tlast = '1') else
                   '0';

  s0_axis_tready <= not w_full;

  o_pkt_ready <= '0' when npkt_inside = 0 else
                 '1';

  s1_axis_tvalid <= '0' when npkt_inside = 0 else
                    '1' and (not w_empty);

  w_wr_data <= s0_axis_tlast & s0_axis_tdata;

  s1_axis_tdata <= r_fifo_data(to_integer(r_rd_index(C_ADDR_WIDTH - 1 downto 0)))(G_WIDTH - 1 downto 0);
  s1_axis_tlast <= r_fifo_data(to_integer(r_rd_index(C_ADDR_WIDTH - 1 downto 0)))(G_WIDTH);

  p_write : process (s0_axis_aclk) is
  begin

    if rising_edge(s0_axis_aclk) then
      if (i_rst_sync = '1') then
        r_wr_index <= (others => '0');
      elsif (s0_axis_tvalid = '1' and w_full = '0') then
        r_fifo_data(to_integer(r_wr_index( c_ADDR_WIDTH - 1 downto 0))) <= w_wr_data;
        r_wr_index                                                      <= r_wr_index + 1;
      end if;
    end if;

  end process p_write;

  p_read : process (s1_axis_aclk) is
  begin

    if rising_edge(s1_axis_aclk) then
      if (i_rst_sync = '1') then
        r_rd_index <= (others => '0');
      elsif (s1_axis_tready = '1' and s1_axis_tvalid = '1') then
        r_rd_index <= r_rd_index + 1;
      end if;
    end if;

  end process p_read;

  -- Single driver for npkt_inside, combining both the write-side and
  -- read-side packet-completion events on the (shorted) common clock.
  p_npkt : process (s0_axis_aclk) is
  begin

    if rising_edge(s0_axis_aclk) then
      if (i_rst_sync = '1') then
        npkt_inside <= (others => '0');
      elsif (w_wr_pkt_done = '1' and w_rd_pkt_done = '0') then
        npkt_inside <= npkt_inside + 1;
      elsif (w_wr_pkt_done = '0' and w_rd_pkt_done = '1') then
        npkt_inside <= npkt_inside - 1;
      end if;
    end if;

  end process p_npkt;

end architecture rtl;
