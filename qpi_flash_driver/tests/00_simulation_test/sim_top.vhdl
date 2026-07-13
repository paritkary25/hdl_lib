----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/19/2026 12:33:11 PM
-- Design Name: 
-- Module Name: sim_top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Simulation testbench for flash_axis_qspi_adapter with MX25L25645G
-- 
-- Dependencies: 
--   - design_1_wrapper.vhd (VHDL)
--   - MX25L25645G.v (Verilog)
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity sim_top is
--  Port ( );
end sim_top;

architecture Behavioral of sim_top is

    -- Clock period for 100 MHz clock
    constant CLK_PERIOD : time := 10 ns;
    
    -- Signal declarations
    signal sys_clock    : std_logic := '0';
    signal nreset_rtl    : std_logic := '1';
    
    -- Flash interface signals
    signal QPI_SCLK     : std_logic;
    signal QPI_nCS      : std_logic;
    signal QPI_nRST     : std_logic;
    signal QPI_SIO0     : std_logic;
    signal QPI_SIO1     : std_logic;
    signal QPI_SIO2     : std_logic;
    signal QPI_SIO3     : std_logic;
    
    -- Component declaration for design_1_wrapper
    component design_1_wrapper is
        port (
            io_QPI_SIO0_0 : inout STD_LOGIC;
            io_QPI_SIO1_0 : inout STD_LOGIC;
            io_QPI_SIO2_0 : inout STD_LOGIC;
            io_QPI_SIO3_0 : inout STD_LOGIC;
            o_QPI_SCLK_0 : out STD_LOGIC;
            o_QPI_nCS_0 : out STD_LOGIC;
            o_QPI_nRST_0 : out STD_LOGIC;
            nreset_rtl : in STD_LOGIC;
            sys_clock : in STD_LOGIC
        );
    end component;
    
    -- Component declaration for MX25L25645G (Verilog module)
    component MX25L25645G is
        port (
            SCLK  : in std_logic;
            CS    : in std_logic;
            SI    : inout std_logic;
            SO    : inout std_logic;
            WP    : inout std_logic;
            RESET : in std_logic;
            SIO3  : inout std_logic
        );
    end component;

begin

    -- 100 MHz Clock generation
    clk_process : process
    begin
        sys_clock <= '0';
        wait for CLK_PERIOD/2;
        sys_clock <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    -- Reset generation
    reset_process : process
    begin
        nreset_rtl <= '1';
        wait for 100 ns;
        nreset_rtl <= '0';
        wait for 200 ns;
        nreset_rtl <= '1';
        wait;
    end process;
    
    -- Instantiate design_1_wrapper (DUT)
    dut : design_1_wrapper
        port map (
            sys_clock     => sys_clock,
            nreset_rtl     => nreset_rtl,
            o_QPI_SCLK_0  => QPI_SCLK,
            o_QPI_nCS_0   => QPI_nCS,
            o_QPI_nRST_0  => QPI_nRST,
            io_QPI_SIO0_0 => QPI_SIO0,
            io_QPI_SIO1_0 => QPI_SIO1,
            io_QPI_SIO2_0 => QPI_SIO2,
            io_QPI_SIO3_0 => QPI_SIO3
        );
    
    -- Instantiate MX25L25645G flash memory model
    flash_mem : MX25L25645G
        port map (
            SCLK  => QPI_SCLK,
            CS    => QPI_nCS,
            SI    => QPI_SIO0,
            SO    => QPI_SIO1,
            WP    => QPI_SIO2,
            RESET => QPI_nRST,
            SIO3  => QPI_SIO3
        );

end Behavioral;

