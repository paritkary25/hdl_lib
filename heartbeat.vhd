----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10/07/2025 11:34:49 PM
-- Design Name: 
-- Module Name: heartbeat - Behavioral
-- Project Name: generic
-- Target Devices: none
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Generate a heartbeat signal at 1 Hz
entity heartbeat is
    GENERIC (
        clk_freq : integer := 100000000 -- 1 second at 50MHz, should be multiple of two
    );
--  Port ( );
    PORT(
        i_clk  : in std_logic;
        i_nRST : in std_logic;
        o_RST  : out std_logic;
        o_hb   : out std_logic
    );
    
end heartbeat;

architecture Behavioral of heartbeat is
    signal counter : integer := 0;
    signal hb : std_logic := '0';
begin
    o_RST <= not i_nRST;
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if counter < clk_freq / 2 - 1 then
                counter <= counter + 1;
            else
                counter <= 0;
                hb <= not hb; -- Toggle heartbeat signal
            end if;
        end if;
    end process;
    o_hb <= hb;

end Behavioral;
