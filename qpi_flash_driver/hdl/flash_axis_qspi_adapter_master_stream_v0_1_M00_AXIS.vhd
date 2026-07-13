library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity flash_axis_qspi_adapter_master_stream_v0_1_m00_axis is
  generic (
    -- Users to add parameters here

    -- User parameters ends
    -- Do not modify the parameters beyond this line

    -- Width of S_AXIS address bus. The slave accepts the read and write addresses of width C_M_AXIS_TDATA_WIDTH.
    C_M_AXIS_TDATA_WIDTH : integer := 32;
    -- Start count is the number of clock cycles the master will wait before initiating/issuing any transaction.
    C_M_START_COUNT : integer := 32
  );
  port (
    -- Users to add ports here
    i_axis_dout        : in    std_logic_vector(C_M_AXIS_TDATA_WIDTH - 1 downto 0);
    i_axis_dout_tvalid : in    std_logic;
    i_axis_dout_tlast  : in    std_logic;

    -- User ports ends
    -- Do not modify the ports beyond this line

    -- Global ports
    m_axis_aclk : in    std_logic;
    --
    m_axis_aresetn : in    std_logic;
    -- Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted.
    m_axis_tvalid : out   std_logic;
    -- TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
    m_axis_tdata : out   std_logic_vector(C_M_AXIS_TDATA_WIDTH - 1 downto 0);
    -- TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
    m_axis_tstrb : out   std_logic_vector((C_M_AXIS_TDATA_WIDTH / 8) - 1 downto 0);
    -- TLAST indicates the boundary of a packet.
    m_axis_tlast : out   std_logic;
    -- TREADY indicates that the slave can accept a transfer in the current cycle.
    m_axis_tready : in    std_logic
  );
end entity flash_axis_qspi_adapter_master_stream_v0_1_m00_axis;

architecture implementation of flash_axis_qspi_adapter_master_stream_v0_1_m00_axis is

begin

  m_axis_tdata  <= i_axis_dout;
  m_axis_tvalid <= i_axis_dout_tvalid;
  m_axis_tlast  <= i_axis_dout_tlast;
  m_axis_tstrb  <= (others => '1');

end architecture implementation;
