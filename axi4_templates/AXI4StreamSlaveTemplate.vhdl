----------------------------------------------------------------------------------
-- File: AXIStreamSlave.vhd
-- Author: Y.U.P. (Modified from Vivado template)
-- Last Modified: 2026-04-29 Wed 00:03
----------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity axistreamslave is
  generic (
    -- Users to add parameters here

    -- User parameters ends
    -- Do not modify the parameters beyond this line

    -- AXI4Stream sink: Data Width
    C_S_AXIS_TDATA_WIDTH : integer := 32
  );
  port (
    -- Users to add ports here
    -- User ports ends
    -- Do not modify the ports beyond this line

    -- AXI4Stream sink: Clock
    s_axis_aclk : in    std_logic;
    -- AXI4Stream sink: Reset
    s_axis_aresetn : in    std_logic;
    -- Ready to accept data in
    s_axis_tready : out   std_logic;
    -- Data in
    s_axis_tdata : in    std_logic_vector(C_S_AXIS_TDATA_WIDTH - 1 downto 0);
    -- Byte qualifier
    s_axis_tstrb : in    std_logic_vector((C_S_AXIS_TDATA_WIDTH / 8) - 1 downto 0);
    -- Indicates boundary of last packet
    s_axis_tlast : in    std_logic;
    -- Data is in valid
    s_axis_tvalid : in    std_logic
  );
end entity axistreamslave;

architecture arch_imp of axistreamslave is

  -- Add user logic here
  signal rst_sync : std_logic;
  signal wr_en    : std_logic;
  signal full     : std_logic;
  -- port copies
  signal aclk : std_logic;
  signal data : std_logic_vector(31 downto 0);

  component module_fifo_regs_no_flags is
    generic (
      G_WIDTH : natural := 8;
      G_DEPTH : integer := 256
    );
    port (
      i_rst_sync : in    std_logic;
      i_clk      : in    std_logic;

      -- FIFO Write Interface
      i_wr_en   : in    std_logic;
      i_wr_data : in    std_logic_vector(g_WIDTH - 1 downto 0);
      o_full    : out   std_logic;

      -- FIFO Read Interface
      i_rd_en   : in    std_logic;
      o_rd_data : out   std_logic_vector(g_WIDTH - 1 downto 0);
      o_empty   : out   std_logic
    );
  end component module_fifo_regs_no_flags;

begin

  s_axis_tready <= not full;
  rst_sync      <= not s_axis_aresetn;
  wr_en         <= s_axis_tvalid and (not full);
  data          <= s_axis_tdata;
  aclk          <= s_axis_aclk;

  fifo_inst : component module_fifo_regs_no_flags
    generic map (
      g_width => C_S_AXIS_TDATA_WIDTH,
      g_depth => 256
    )
    port map (
      i_rst_sync => rst_sync,
      i_clk      => aclk,

      i_wr_en   => wr_en,
      i_wr_data => data,
      o_full    => full,

      i_rd_en   => i_rd_en,
      o_rd_data => o_rd_data,
      o_empty   => o_empty
    );

-- User logic ends

end architecture arch_imp;
