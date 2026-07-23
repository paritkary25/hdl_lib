-------------------------------------------------------------------------------
-- Testbench: tb.vhdl
-- Last Modified: 2026/07/23 11:15
-- Description: Self-checking testbench for uart.vhdl
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb is
end entity tb;

architecture sim of tb is

  -- Generic Constants
  constant C_CLOCK_FREQ : positive := 100_000_000; -- 100 MHz
  constant C_BAUD       : positive := 115_200;     -- 115200 Baud
  constant C_CLK_PERIOD : time     := 10 ns;       -- 100 MHz clock period
  constant C_BIT_PERIOD : time     := 8680.55 ns;  -- 1 / 115200 baud bit duration

  -- UUT Signals
  signal clock               : std_logic                    := '0';
  signal reset               : std_logic                    := '0';
  signal data_stream_in      : std_logic_vector(7 downto 0) := (others => '0');
  signal data_stream_in_stb  : std_logic                    := '0';
  signal data_stream_in_ack  : std_logic;
  signal data_stream_out     : std_logic_vector(7 downto 0);
  signal data_stream_out_stb : std_logic;
  signal tx                  : std_logic;
  signal rx                  : std_logic;

  -- Testbench Control Signals
  signal rx_driver   : std_logic := '1';
  signal loopback_en : std_logic := '0';
  signal sim_done    : boolean   := false;

  -- Signals for strobe latching
  signal rx_strobe_latched : std_logic := '0';
  signal rx_latch_clear    : std_logic := '0';

begin

  ---------------------------------------------------------------------------
  -- Instantiate Unit Under Test (UUT)
  ---------------------------------------------------------------------------
  uut : entity work.uart
    generic map (
      baud            => C_BAUD,
      clock_frequency => C_CLOCK_FREQ
    )
    port map (
      clock               => clock,
      reset               => reset,
      data_stream_in      => data_stream_in,
      data_stream_in_stb  => data_stream_in_stb,
      data_stream_in_ack  => data_stream_in_ack,
      data_stream_out     => data_stream_out,
      data_stream_out_stb => data_stream_out_stb,
      tx                  => tx,
      rx                  => rx
    );

  ---------------------------------------------------------------------------
  -- Mux for RX Pin: Selects between external injection driver and TX loopback
  ---------------------------------------------------------------------------
  rx <= tx when (loopback_en = '1') else
        rx_driver;

  ---------------------------------------------------------------------------
  -- Clock Generator (100 MHz)
  ---------------------------------------------------------------------------
  clk_process : process is
  begin

    while not sim_done loop

      clock <= '0';
      wait for C_CLK_PERIOD / 2;
      clock <= '1';
      wait for C_CLK_PERIOD / 2;

    end loop;

    wait;

  end process clk_process;

  ---------------------------------------------------------------------------
  -- Sticky Latch Process: Captures 1-cycle pulses anytime they occur
  ---------------------------------------------------------------------------
  strobe_latch_proc : process (clock) is
  begin

    if rising_edge(clock) then
      if (reset = '1' or rx_latch_clear = '1') then
        rx_strobe_latched <= '0';
      elsif (data_stream_out_stb = '1') then
        rx_strobe_latched <= '1';
      end if;
    end if;

  end process strobe_latch_proc;

  ---------------------------------------------------------------------------
  -- Main Stimulus & Verification
  ---------------------------------------------------------------------------
  stimulus_proc : process is

    -- Helper procedure: Inject a byte onto RX line manually (8N1, LSB first)

    procedure inject_rx_byte (
      val : in std_logic_vector(7 downto 0)
    ) is
    begin

      -- Start Bit (Low)
      rx_driver <= '0';
      wait for C_BIT_PERIOD;

      -- 8 Data Bits (LSB First)
      for i in 0 to 7 loop

        rx_driver <= val(i);
        wait for C_BIT_PERIOD;

      end loop;

      -- Stop Bit (High)
      rx_driver <= '1';
      wait for C_BIT_PERIOD;

    end procedure inject_rx_byte;

    -- Helper procedure: Transmit a byte using internal TX module

    procedure send_tx_byte (
      val : in std_logic_vector(7 downto 0)
    ) is
    begin

      wait until rising_edge(clock);
      data_stream_in     <= val;
      data_stream_in_stb <= '1';

      -- Wait for transmission acknowledge from UART
      wait until rising_edge(clock) and data_stream_in_ack = '1';
      data_stream_in_stb <= '0';

    end procedure send_tx_byte;

  begin

    -- Reset Assert
    reset <= '1';
    wait for 100 ns;
    reset <= '0';
    wait for 100 ns;

    report "==================================================";
    report "TEST 1: External Serial RX Injection (0xA5)";
    report "==================================================";
    rx_latch_clear <= '1';
    wait until rising_edge(clock);
    rx_latch_clear <= '0';

    loopback_en <= '0';

    -- Inject byte (strobe will fire during this call)
    inject_rx_byte(x"A5");

    -- Check if strobe was captured during or right after injection
    if (rx_strobe_latched /= '1') then
      wait until rising_edge(clock) and rx_strobe_latched = '1' for 20 us;
    end if;

    assert (rx_strobe_latched = '1')
      report "TEST 1 FAILED! No strobe detected on data_stream_out_stb."
      severity failure;

    assert (data_stream_out = x"A5")
      report "TEST 1 FAILED! Data mismatch."
      severity failure;

    report "TEST 1 PASSED: Successfully received 0xA5";

    wait for 20 us;

    report "==================================================";
    report "TEST 2: TX-to-RX Loopback (0x3C and 0xF0)";
    report "==================================================";
    loopback_en <= '1';

    -- Transmit first byte
    send_tx_byte(x"3C");
    wait until rising_edge(clock) and data_stream_out_stb = '1';
    assert (data_stream_out = x"3C")
      report "TEST 2 FAILED (Byte 1)! Received unexpected value."
      severity failure;
    report "TEST 2a PASSED: Transmitted and received 0x3C via loopback";

    -- Transmit second byte
    send_tx_byte(x"F0");
    wait until rising_edge(clock) and data_stream_out_stb = '1';
    assert (data_stream_out = x"F0")
      report "TEST 2 FAILED (Byte 2)! Received unexpected value."
      severity failure;
    report "TEST 2b PASSED: Transmitted and received 0xF0 via loopback";

    report "==================================================";
    report "ALL SIMULATION TESTS COMPLETED SUCCESSFULLY!";
    report "==================================================";

    sim_done <= true;
    wait;

  end process stimulus_proc;

end architecture sim;
