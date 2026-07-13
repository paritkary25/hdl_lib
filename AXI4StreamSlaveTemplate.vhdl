----------------------------------------------------------------------------------
-- File: AXIStreamSlave.vhd
-- Author: Y.U.P. (Modified from Vivado template)
-- Last Modified: 2026-04-29 Wed 00:03
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AXIStreamSlave is
    generic (
        -- Users to add parameters here

        -- User parameters ends
        -- Do not modify the parameters beyond this line

        -- AXI4Stream sink: Data Width
        C_S_AXIS_TDATA_WIDTH    : integer    := 32
    );
    port (
        -- Users to add ports here
        -- User ports ends
        -- Do not modify the ports beyond this line

        -- AXI4Stream sink: Clock
        S_AXIS_ACLK    : in std_logic;
        -- AXI4Stream sink: Reset
        S_AXIS_ARESETN    : in std_logic;
        -- Ready to accept data in
        S_AXIS_TREADY    : out std_logic;
        -- Data in
        S_AXIS_TDATA    : in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
        -- Byte qualifier
        S_AXIS_TSTRB    : in std_logic_vector((C_S_AXIS_TDATA_WIDTH/8)-1 downto 0);
        -- Indicates boundary of last packet
        S_AXIS_TLAST    : in std_logic;
        -- Data is in valid
        S_AXIS_TVALID    : in std_logic
    );
end AXIStreamSlave;

architecture arch_imp of AXIStreamSlave is
    -- Add user logic here
    signal rst_sync : std_logic := '0';
    signal wr_en    : std_logic := '0';
    signal full     : std_logic := '0';
    -- port copies
    signal aclk     : std_logic := '0';
    signal data     : std_logic_vector(31 downto 0) := ( others => '0' );

    component module_fifo_regs_no_flags is
        generic (
            g_WIDTH : natural := 8;
            g_DEPTH : integer := 256
        );
        port (
            i_rst_sync : in std_logic;
            i_clk      : in std_logic;

            -- FIFO Write Interface
            i_wr_en   : in  std_logic;
            i_wr_data : in  std_logic_vector(g_WIDTH-1 downto 0);
            o_full    : out std_logic;

            -- FIFO Read Interface
            i_rd_en   : in  std_logic;
            o_rd_data : out std_logic_vector(g_WIDTH-1 downto 0);
            o_empty   : out std_logic
        );
    end component;

begin 
    S_AXIS_TREADY <= not full;
    rst_sync      <= not S_AXIS_ARESETN;
    wr_en         <= S_AXIS_TVALID and (not full);
    data          <= S_AXIS_TDATA;
    aclk          <= S_AXIS_ACLK;
    
    fifo_inst :module_fifo_regs_no_flags
        generic map (
            g_WIDTH => C_S_AXIS_TDATA_WIDTH,
            g_DEPTH => 256
        )
        port map (
            i_rst_sync => rst_sync,
            i_clk      => aclk,

            i_wr_en    => wr_en,
            i_wr_data  => data,
            o_full     => full,

            i_rd_en    => i_rd_en,
            o_rd_data  => o_rd_data,
            o_empty    => o_empty
        );     
    -- User logic ends
end arch_imp;
