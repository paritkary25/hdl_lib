-------------------------------------------------------------------------------
-- File: flash_axis_qspi_adapter.vhd
-- Author: YP
-- Last Modified: 2026-04-20 Mon 22:32
--
-- Designed for MX25L25645G
--    Provides AXI interface to interact with the memory
--    AXI Lite interfaces to R/W status
--    AXIS for data streaming
--    Takes flash into QPI mode soon after boot
--    Does basic check to see if the memory is connected or not
--    Provides a buffer for input
--    Output is not buffered
--    Procedure for writing data
--    Following commands are implemented internally on the flash
--
--    4READ  | n bytes read from the start of page (Addr should be 0x0????_??00)
--    PP     | Write 1-256 bytes from the selected byte address
--
--    While pumping data into flash, write fast enough to not starve the buffer
--
--    Falling edge of nRST in the AXI Lite register triggers flash to reset
--    The clock divider uses simple by two division, 2n+1 numbers will be taken as 2n.
--    Data is handled in 32-bit words
--    Data is stored big endian in the flash, i.e., nibble 7,6,5,4,3,2,1,0 in the corresponding order. Hence, the first byte is the least significant byte.
--    Use stat bit to check for the DPD and BOOT status, for other commands, use WIP (Work In Progress)
-------------------------------------------------------------------------------
-- TODO
-- Need to implement erase commands

-- Far TODO
-- Add speed by changing the (DC) Dummy Cycle configuration at boot
-------------------------------------------------------------------------------
-- LOG
-- The WEN instruction is working correctly.
-- The EQIO instruction is working correctly.
-- QPI mode is working correctly
-- 2026-02-11 Read working
-- 2026-03-09 Write working
-- Failing in hardware
-- Imporoved how the clock is handeled
-- Added control over CS minimum high time
-- 2026-04-10 Initialisation is working on hardware, but read and write are not working, need to debug
-- The issue was integer overflow working in simulation
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity flash_axis_qspi_adapter is
  generic (

    -- Users to add parameters here
    CLK_FREQ_MHZ : integer := 100;
    QPI_FREQ_DIV : integer := 2;
    CS_SET_WAIT  : integer := 4;    -- modify number of wait cycles (QPI domain)
    NRST_THR     : integer := 20;   -- us
    NRST_RDY_THR : integer := 4000; -- us
    DEBUG        : boolean := true;
    -- -- Currently implemented only for DIV by 2
    -- -- Need to change clock generation style for better detection

    -- User parameters ends
    -- Do not modify the parameters beyond this line

    -- Parameters of Axi Slave Bus Interface S00_AXI
    C_S00_AXI_DATA_WIDTH : integer := 32;
    C_S00_AXI_ADDR_WIDTH : integer := 4;

    -- Parameters of Axi Slave Bus Interface S00_AXIS
    C_S00_AXIS_TDATA_WIDTH : integer := 32;

    -- Parameters of Axi Master Bus Interface M00_AXIS
    C_M00_AXIS_TDATA_WIDTH : integer := 32;
    C_M00_AXIS_START_COUNT : integer := 32
  );
  port (
    -- Users to add ports here
    -- -- ports for the flash
    o_qpi_sclk  : out   std_logic;
    o_qpi_ncs   : out   std_logic;
    io_qpi_sio0 : inout std_logic;
    io_qpi_sio1 : inout std_logic;
    io_qpi_sio2 : inout std_logic;
    io_qpi_sio3 : inout std_logic;
    o_qpi_nrst  : out   std_logic;
    i_clk       : in    std_logic;

    -- -- Interrept for the MCU
    o_int_txnc : out   std_logic; -- singals completion of the last issued transaction
    -- User ports ends
    -- Do not modify the ports beyond this line

    -- Ports of Axi Slave Bus Interface S00_AXI
    s00_axi_aclk    : in    std_logic;
    s00_axi_aresetn : in    std_logic;
    s00_axi_awaddr  : in    std_logic_vector(C_S00_AXI_ADDR_WIDTH - 1 downto 0);
    s00_axi_awprot  : in    std_logic_vector(2 downto 0);
    s00_axi_awvalid : in    std_logic;
    s00_axi_awready : out   std_logic;
    s00_axi_wdata   : in    std_logic_vector(C_S00_AXI_DATA_WIDTH - 1 downto 0);
    s00_axi_wstrb   : in    std_logic_vector((C_S00_AXI_DATA_WIDTH / 8) - 1 downto 0);
    s00_axi_wvalid  : in    std_logic;
    s00_axi_wready  : out   std_logic;
    s00_axi_bresp   : out   std_logic_vector(1 downto 0);
    s00_axi_bvalid  : out   std_logic;
    s00_axi_bready  : in    std_logic;
    s00_axi_araddr  : in    std_logic_vector(C_S00_AXI_ADDR_WIDTH - 1 downto 0);
    s00_axi_arprot  : in    std_logic_vector(2 downto 0);
    s00_axi_arvalid : in    std_logic;
    s00_axi_arready : out   std_logic;
    s00_axi_rdata   : out   std_logic_vector(C_S00_AXI_DATA_WIDTH - 1 downto 0);
    s00_axi_rresp   : out   std_logic_vector(1 downto 0);
    s00_axi_rvalid  : out   std_logic;
    s00_axi_rready  : in    std_logic;

    -- Ports of Axi Slave Bus Interface S00_AXIS
    s00_axis_aclk    : in    std_logic;
    s00_axis_aresetn : in    std_logic;
    s00_axis_tready  : out   std_logic;
    s00_axis_tdata   : in    std_logic_vector(C_S00_AXIS_TDATA_WIDTH - 1 downto 0);
    s00_axis_tstrb   : in    std_logic_vector((C_S00_AXIS_TDATA_WIDTH / 8) - 1 downto 0);
    s00_axis_tlast   : in    std_logic;
    s00_axis_tvalid  : in    std_logic;

    -- Ports of Axi Master Bus Interface M00_AXIS
    m00_axis_aclk    : in    std_logic;
    m00_axis_aresetn : in    std_logic;
    m00_axis_tvalid  : out   std_logic;
    m00_axis_tdata   : out   std_logic_vector(C_M00_AXIS_TDATA_WIDTH - 1 downto 0);
    m00_axis_tstrb   : out   std_logic_vector((C_M00_AXIS_TDATA_WIDTH / 8) - 1 downto 0);
    m00_axis_tlast   : out   std_logic;
    m00_axis_tready  : in    std_logic
  );
end entity flash_axis_qspi_adapter;

architecture arch_imp of flash_axis_qspi_adapter is

  -- Flash Commands
  constant CLK_FREQ_HZ  : integer                       := CLK_FREQ_MHZ * 1_000_000;
  constant CMD_4READ    : std_logic_vector(7 downto 0)  := x"EB";
  constant CMD_PP       : std_logic_vector(7 downto 0)  := x"02";
  constant CMD_WREN     : std_logic_vector(7 downto 0)  := x"06";
  constant CMD_EQIO_SPI : std_logic_vector(31 downto 0) := "ZZZ0ZZZ0ZZZ1ZZZ1ZZZ0ZZZ1ZZZ0ZZZ1";
  constant CMD_WREN_SPI : std_logic_vector(31 downto 0) := "ZZZ0ZZZ0ZZZ0ZZZ0ZZZ0ZZZ1ZZZ1ZZZ0";
  constant CMD_RDSR     : std_logic_vector(7 downto 0)  := x"05";
  constant CMD_WREAR    : std_logic_vector(7 downto 0)  := x"C5";
  constant CMD_RES      : std_logic_vector(7 downto 0)  := x"AB";
  constant CMD_DP       : std_logic_vector(7 downto 0)  := x"B9";
  constant CMD_RDP      : std_logic_vector(7 downto 0)  := x"AB";
  constant CMD_SE       : std_logic_vector(7 downto 0)  := x"20";
  constant CMD_BE       : std_logic_vector(7 downto 0)  := x"D8";
  constant CMD_CE       : std_logic_vector(7 downto 0)  := x"60";
  -- Flash Commands ends

  -- Probe FLASH_ELECTRONIC_ID to check if the flash is connected with QPI mode and then SPI mode if failed
  constant FLASH_ELECTRONIC_ID    : std_logic_vector(7 downto 0) := x"18";
  constant FLASH_QPI_NRST_THR     : integer                      := CLK_FREQ_MHZ * NRST_THR;
  constant FLASH_QPI_NRST_RDY_THR : integer                      := CLK_FREQ_MHZ * NRST_RDY_THR;
  constant FLASH_RDP_TRES_THR     : integer                      := CLK_FREQ_MHZ * 60;
  constant FLASH_RST_CYCLES       : integer                      := FLASH_QPI_NRST_RDY_THR + FLASH_QPI_NRST_THR;

  -- this is like a constant but it can be changed later when in HS mode
  signal flash_dc_cnt : integer range 0 to 15 := 6;
  signal s_int_txnc   : std_logic             := '0'; -- transaction complete interrept

  -------------------------------------------------------------------------------
  -- Operating modes of flash adapter
  -------------------------------------------------------------------------------
  constant BOOT                : std_logic_vector( 2 downto 0) := "000";
  constant FLASH_RESET         : std_logic_vector( 2 downto 0) := "001";
  constant RD                  : std_logic_vector( 2 downto 0) := "010";
  constant WR                  : std_logic_vector( 2 downto 0) := "011";
  constant SE                  : std_logic_vector( 2 downto 0) := "100";
  constant BE                  : std_logic_vector( 2 downto 0) := "101";
  constant CE                  : std_logic_vector( 2 downto 0) := "110";
  constant DPD                 : std_logic_vector( 2 downto 0) := "111";
  signal   flash_adapter_state : std_logic_vector( 2 downto 0) := BOOT; -- BOOT at startup
  -------------------------------------------------------------------------------

  signal clk : std_logic := '0'; -- just to simplify the use

  -- -- port copies for the flash
  signal s_qpi_nrst : std_logic                    := '1';
  signal s_qpi_sclk : std_logic                    := '0';
  signal s_qpi_ncs  : std_logic                    := '1';
  signal s_qpi_sio  : std_logic_vector(3 downto 0) := (others => '1');

  signal s_divclk : std_logic                                             := '0';
  signal s_addr   : std_logic_vector(C_S00_AXIS_TDATA_WIDTH - 1 downto 0) := (others => '0');

  -- -- Temporary signals for read write
  signal qpi_tx_en : std_logic                    := '0'; -- enable transmission to flash
  signal s_d_out   : std_logic_vector(3 downto 0) := (others => '1');
  signal s_d_in    : std_logic_vector(3 downto 0) := (others => '1');

  -- -- Clock generation signals
  signal qpi_clkdiv_cnt : integer range 0 to QPI_FREQ_DIV + 1     := 0;   -- clk divider counter
  signal qpi_clk_en     : std_logic                               := '0'; -- clk enable for QPI operations
  signal cntrst         : integer range 0 to FLASH_RST_CYCLES + 1 := 0;

  -------------------------------------------------------------------------------
  -- QPI transceiver signals
  -------------------------------------------------------------------------------
  -- qpi_trx_tx_cnt: decides number of bytes to send
  -- qpi_trx_rx_cnt: decides number of bytes to receive, for reading responses, make this non zero
  -- qpi_trx_dc_cnt: dummy cycle counter for the current transaction
  -- rising edge of qpi_trx_en starts the transaction

  -- start transaction like this:
  -- set qpi_trx_type, qpi_trx_rx_cnt, qpi_trx_dc_cnt and make rising edge on qpi_trx_en
  -------------------------------------------------------------------------------
  -- Operating modes for QPI TRX
  -------------------------------------------------------------------------------
  constant TX            : std_logic_vector( 1 downto 0) := "00";
  constant DC            : std_logic_vector( 1 downto 0) := "01";
  constant RX            : std_logic_vector( 1 downto 0) := "10";
  constant CS            : std_logic_vector( 1 downto 0) := "11";
  signal   qpi_trx_state : std_logic_vector( 1 downto 0) := TX; -- default in TX
  -------------------------------------------------------------------------------

  signal qpi_reg_out     : std_logic_vector(31 downto 0) := (others => '0'); -- transmit this reg to flash
  signal qpi_reg_in      : std_logic_vector(31 downto 0) := (others => '0'); -- transmit this reg to flash
  signal qpi_trx_txs     : std_logic                     := '0';             -- transmission stream (for PP)
  signal qpi_trx_tx_cnt  : integer range 0 to 4          := 0;               -- number of bytes to send
  signal qpi_trx_dc_cnt  : integer range 0 to 15         := 0;               -- dummy cycle counter for the current transaction
  signal qpi_trx_rx_cnt  : integer range 0 to 2 ** 28    := 0;               -- numbers of bytes to reveive
  signal qpi_trx_busy    : std_logic                     := '0';             -- trx in progress
  signal qpi_trx_done    : std_logic                     := '0';             -- marks end of trn
  signal qpi_trx_en      : std_logic                     := '0';             -- start signal
  signal qpi_trx_en_prev : std_logic                     := '0';             -- start signal
  signal qpi_trx_last    : std_logic                     := '0';             -- indicate the last nibble, feed new word just after sensing this in PP
  -- indicate last byte while RD, synchronise AXI TLAST with this
  signal qpi_trx_word : std_logic              := '0';             -- marks word added to qpi_reg_in
  signal nibble_cnt   : unsigned( 27 downto 0) := (others => '0'); -- counts the number of nibbles transmitted/received, max is full memory (2**27 * 2)
  ------------------------------------------------------------------

  -- -- port copies for the axi lite
  signal s_status : std_logic := '0';
  signal s_id_ok  : std_logic := '0'; -- 0 for incorrect

  signal s_mode            : std_logic_vector( 2 downto 0) := (others => '0'); -- operating mode
  signal s_wip             : std_logic                     := '0';             -- work in progress trx_busy is more of a inter process comm
  signal s_flash_nrst      : std_logic                     := '1';             -- reset from AXI Lite
  signal s_flash_nrst_prev : std_logic                     := '1';

  -- -- flash state information
  signal s_wrear : std_logic                  := '0'; -- Extended Address Reg value
  signal nread   : integer range 0 to 2 ** 28 := 0;   -- number of bytes to read, can empty whole memory

  -- -- port copies for the din axis slave port
  signal fifo_rd_data : std_logic_vector(31 downto 0) := (others => '0');
  signal fifo_rd_en   : std_logic                     := '0';
  signal fifo_empty   : std_logic                     := '0';

  -- -- port copies for the dout axis master port
  signal axis_dout             : std_logic_vector(31 downto 0) := (others => '0');
  signal axis_dout_tvalid      : std_logic                     := '0';
  signal axis_dout_tvalid_curr : std_logic                     := '0';
  signal axis_dout_tvalid_prev : std_logic                     := '0';
  signal axis_dout_tlast       : std_logic                     := '0';

  signal cnt : integer range 0 to 15 := 0; -- small generic counter
  -- user signal declarations ends

  -- component declaration
  component flash_axis_qspi_adapter_slave_lite_v0_1_s00_axi is
    generic (
      C_S_AXI_DATA_WIDTH : integer       := 32;
      C_S_AXI_ADDR_WIDTH : integer       := 4
    );
    port (
      -- Users to add ports here
      -- -- Bringing signals from main file
      i_status       : in    std_logic;
      i_id_ok        : in    std_logic;
      i_wip          : in    std_logic;
      i_qpi_trx_busy : in    std_logic;
      i_last_read    : in    std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);

      -- -- Responses back to the main file
      o_mode       : out   std_logic_vector( 2 downto 0);
      o_flash_nrst : out   std_logic;

      -- User ports ends

      s_axi_aclk    : in    std_logic;
      s_axi_aresetn : in    std_logic;
      s_axi_awaddr  : in    std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
      s_axi_awprot  : in    std_logic_vector(2 downto 0);
      s_axi_awvalid : in    std_logic;
      s_axi_awready : out   std_logic;
      s_axi_wdata   : in    std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
      s_axi_wstrb   : in    std_logic_vector((C_S_AXI_DATA_WIDTH / 8) - 1 downto 0);
      s_axi_wvalid  : in    std_logic;
      s_axi_wready  : out   std_logic;
      s_axi_bresp   : out   std_logic_vector(1 downto 0);
      s_axi_bvalid  : out   std_logic;
      s_axi_bready  : in    std_logic;
      s_axi_araddr  : in    std_logic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
      s_axi_arprot  : in    std_logic_vector(2 downto 0);
      s_axi_arvalid : in    std_logic;
      s_axi_arready : out   std_logic;
      s_axi_rdata   : out   std_logic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
      s_axi_rresp   : out   std_logic_vector(1 downto 0);
      s_axi_rvalid  : out   std_logic;
      s_axi_rready  : in    std_logic
    );
  end component flash_axis_qspi_adapter_slave_lite_v0_1_s00_axi;

  component flash_axis_qspi_adapter_slave_stream_v0_1_s00_axis is
    generic (
      C_S_AXIS_TDATA_WIDTH : integer       := 32
    );
    port (
      -- Users to add ports here
      i_rd_en   : in    std_logic;
      o_rd_data : out   std_logic_vector(C_S_AXIS_TDATA_WIDTH - 1 downto 0);
      o_empty   : out   std_logic;

      -- User ports ends
      s_axis_aclk    : in    std_logic;
      s_axis_aresetn : in    std_logic;
      s_axis_tready  : out   std_logic;
      s_axis_tdata   : in    std_logic_vector(C_S_AXIS_TDATA_WIDTH - 1 downto 0);
      s_axis_tstrb   : in    std_logic_vector((C_S_AXIS_TDATA_WIDTH / 8) - 1 downto 0);
      s_axis_tlast   : in    std_logic;
      s_axis_tvalid  : in    std_logic
    );
  end component flash_axis_qspi_adapter_slave_stream_v0_1_s00_axis;

  component flash_axis_qspi_adapter_master_stream_v0_1_m00_axis is
    generic (
      C_M_AXIS_TDATA_WIDTH : integer       := 32;
      C_M_START_COUNT      : integer       := 32
    );
    port (
      i_axis_dout        : in    std_logic_vector(C_M_AXIS_TDATA_WIDTH - 1 downto 0);
      i_axis_dout_tvalid : in    std_logic;
      i_axis_dout_tlast  : in    std_logic;
      m_axis_aclk        : in    std_logic;
      m_axis_aresetn     : in    std_logic;
      m_axis_tvalid      : out   std_logic;
      m_axis_tdata       : out   std_logic_vector(C_M_AXIS_TDATA_WIDTH - 1 downto 0);
      m_axis_tstrb       : out   std_logic_vector((C_M_AXIS_TDATA_WIDTH / 8) - 1 downto 0);
      m_axis_tlast       : out   std_logic;
      m_axis_tready      : in    std_logic
    );
  end component flash_axis_qspi_adapter_master_stream_v0_1_m00_axis;

  -- DEBUGGER for the IO ports
  component ila_0 is
    port (
      clk : in    std_logic;

      probe0 : in    std_logic_vector(0 downto 0);
      probe1 : in    std_logic_vector(0 downto 0);
      probe2 : in    std_logic_vector(0 downto 0);
      probe3 : in    std_logic_vector(0 downto 0);
      probe4 : in    std_logic_vector(0 downto 0);
      probe5 : in    std_logic_vector(0 downto 0);
      probe6 : in    std_logic_vector(0 downto 0);
      probe7 : in    std_logic_vector(0 downto 0);
      probe8 : in    std_logic_vector(2 downto 0);
      probe9 : in    std_logic_vector(0 downto 0)
    );
  end component ila_0;

begin

  -- assign port copies
  clk        <= i_clk;
  o_qpi_sclk <= s_qpi_sclk;
  o_qpi_ncs  <= s_qpi_ncs;

  io_qpi_sio0 <= s_qpi_sio(0);
  io_qpi_sio1 <= s_qpi_sio(1);
  io_qpi_sio2 <= s_qpi_sio(2);
  io_qpi_sio3 <= s_qpi_sio(3);

  io_map : for i in 0 to 3 generate
    s_qpi_sio(i) <= s_d_out(i) when qpi_tx_en = '1' else
                    'Z';
  end generate io_map;

  s_d_in(0) <= io_qpi_sio0;
  s_d_in(1) <= io_qpi_sio1;
  s_d_in(2) <= io_qpi_sio2;
  s_d_in(3) <= io_qpi_sio3;

  o_qpi_nrst       <= s_qpi_nrst;
  o_int_txnc       <= s_int_txnc;
  axis_dout_tvalid <= axis_dout_tvalid_curr and (not axis_dout_tvalid_prev);

  -- DEBUGGER INSTANTIATION

  gen_debug : if DEBUG generate

    your_instance_name : component ila_0
      port map (
        clk => i_clk,

        probe0 => s_d_in(0 downto 0),
        probe1 => s_d_in(1 downto 1),
        probe2 => s_d_in(2 downto 2),
        probe3 => s_d_in(3 downto 3),
        probe4 => (0 => qpi_tx_en),
        probe5 => (0 => s_qpi_sclk),
        probe6 => (0 => s_qpi_ncs),
        probe7 => (0 => s_qpi_nrst),
        probe8 => flash_adapter_state,
        probe9 => (0 => s_divclk)
      );

  end generate gen_debug;

  -- Instantiation of Axi Bus Interface S00_AXI
  flash_axis_qspi_adapter_slave_lite_v0_1_s00_axi_inst : component flash_axis_qspi_adapter_slave_lite_v0_1_s00_axi
    generic map (
      c_s_axi_data_width => C_S00_AXI_DATA_WIDTH,
      c_s_axi_addr_width => C_S00_AXI_ADDR_WIDTH
    )
    port map (
      i_status       => s_status,
      i_id_ok        => s_id_ok,
      i_wip          => s_wip,
      i_last_read    => qpi_reg_in,
      i_qpi_trx_busy => qpi_trx_busy,

      o_mode       => s_mode,
      o_flash_nrst => s_flash_nrst,

      s_axi_aclk    => s00_axi_aclk,
      s_axi_aresetn => s00_axi_aresetn,
      s_axi_awaddr  => s00_axi_awaddr,
      s_axi_awprot  => s00_axi_awprot,
      s_axi_awvalid => s00_axi_awvalid,
      s_axi_awready => s00_axi_awready,
      s_axi_wdata   => s00_axi_wdata,
      s_axi_wstrb   => s00_axi_wstrb,
      s_axi_wvalid  => s00_axi_wvalid,
      s_axi_wready  => s00_axi_wready,
      s_axi_bresp   => s00_axi_bresp,
      s_axi_bvalid  => s00_axi_bvalid,
      s_axi_bready  => s00_axi_bready,
      s_axi_araddr  => s00_axi_araddr,
      s_axi_arprot  => s00_axi_arprot,
      s_axi_arvalid => s00_axi_arvalid,
      s_axi_arready => s00_axi_arready,
      s_axi_rdata   => s00_axi_rdata,
      s_axi_rresp   => s00_axi_rresp,
      s_axi_rvalid  => s00_axi_rvalid,
      s_axi_rready  => s00_axi_rready
    );

  -- Instantiation of Axi Bus Interface S00_AXIS
  flash_axis_qspi_adapter_slave_stream_v0_1_s00_axis_inst : component flash_axis_qspi_adapter_slave_stream_v0_1_s00_axis
    generic map (
      c_s_axis_tdata_width => C_S00_AXIS_TDATA_WIDTH
    )
    port map (
      i_rd_en        => fifo_rd_en,
      o_rd_data      => fifo_rd_data,
      o_empty        => fifo_empty,
      s_axis_aclk    => s00_axis_aclk,
      s_axis_aresetn => s00_axis_aresetn,
      s_axis_tready  => s00_axis_tready,
      s_axis_tdata   => s00_axis_tdata,
      s_axis_tstrb   => s00_axis_tstrb,
      s_axis_tlast   => s00_axis_tlast,
      s_axis_tvalid  => s00_axis_tvalid
    );

  -- Instantiation of Axi Bus Interface M00_AXIS
  flash_axis_qspi_adapter_master_stream_v0_1_m00_axis_inst : component flash_axis_qspi_adapter_master_stream_v0_1_m00_axis
    generic map (
      c_m_axis_tdata_width => C_M00_AXIS_TDATA_WIDTH,
      c_m_start_count      => C_M00_AXIS_START_COUNT
    )
    port map (
      i_axis_dout_tvalid => axis_dout_tvalid,
      i_axis_dout        => axis_dout,
      i_axis_dout_tlast  => axis_dout_tlast,
      m_axis_aclk        => m00_axis_aclk,
      m_axis_aresetn     => m00_axis_aresetn,
      m_axis_tvalid      => m00_axis_tvalid,
      m_axis_tdata       => m00_axis_tdata,
      m_axis_tstrb       => m00_axis_tstrb,
      m_axis_tlast       => m00_axis_tlast,
      m_axis_tready      => m00_axis_tready
    );

  -- Process to generate clock
  clk_div_process : process (clk) is
  begin

    if (rising_edge(clk)) then
      if (qpi_clkdiv_cnt = (QPI_FREQ_DIV / 2) - 1) then
        s_divclk       <= not s_divclk;
        qpi_clkdiv_cnt <= 0;
      else
        qpi_clkdiv_cnt <= qpi_clkdiv_cnt + 1;
      end if;

      if (qpi_clk_en = '0') then
        s_divclk   <= '0';
        s_qpi_sclk <= '0';
      else
        s_qpi_sclk <= s_divclk;
      end if;
    end if;

  end process clk_div_process;

  -- Process to control the QPI transactions
  qpi_trx_control : process (clk) is

    variable high_idx : integer range 0 to 31;
    variable low_idx  : integer range 0 to 31;

  begin

    if (rising_edge(clk)) then
      qpi_trx_en_prev <= qpi_trx_en;
      qpi_trx_word    <= '0';
      qpi_trx_last    <= '0';
      qpi_trx_done    <= '0';

      if (s00_axi_aresetn = '0') then
        s_qpi_ncs     <= '1';
        nibble_cnt    <= (others => '0');
        qpi_tx_en     <= '0';
        qpi_clk_en    <= '0';
        qpi_trx_state <= TX;
        qpi_trx_busy  <= '0';
        qpi_reg_out   <= (others => '0');
      else

        case qpi_trx_state is

          when TX =>

            s_qpi_ncs <= '1';
            qpi_tx_en <= '0';

            high_idx := 31 - (to_integer(unsigned(nibble_cnt(2 downto 0))) * 4);
            low_idx  := 28 - (to_integer(unsigned(nibble_cnt(2 downto 0))) * 4);
            s_d_out  <= qpi_reg_in(high_idx downto low_idx);
            -- s_d_out   <= qpi_reg_in( ( 31 - to_unsigned( nibble_cnt( 4 downto 0 ) * 4 ) ) downto ( 28 - to_unsigned( nibble_cnt (4 downto 0 ) ) * 4 ) );

            -- if not busy and rising edge then start transmitting according to
            if ((qpi_trx_busy = '1') or ((qpi_trx_en and (not qpi_trx_en_prev)) = '1')) then
              qpi_trx_busy <= '1';
              qpi_tx_en    <= '1';
              s_qpi_ncs    <= '0';

              if (nibble_cnt < 2 * qpi_trx_tx_cnt) then
                qpi_clk_en <= '1';

                if ((qpi_clkdiv_cnt = (QPI_FREQ_DIV / 2) - 1) and (s_divclk = '1')) then
                  nibble_cnt <= nibble_cnt + 1;
                end if;
              else
                -- if further sending needs to be done, do it
                if (qpi_trx_txs = '0') then
                  if (qpi_trx_dc_cnt /= 0) then
                    nibble_cnt    <= (others => '0');
                    qpi_trx_state <= DC;
                  elsif (qpi_trx_rx_cnt /= 0) then
                    nibble_cnt    <= (others => '0');
                    qpi_trx_state <= RX;
                  elsif (qpi_clkdiv_cnt = (QPI_FREQ_DIV / 2) - 1) then -- correcting width while stopping communications
                    nibble_cnt    <= (others => '0');
                    qpi_trx_busy  <= '0';
                    qpi_clk_en    <= '0';
                    s_qpi_ncs     <= '1';
                    qpi_trx_state <= CS;
                    qpi_tx_en     <= '0';
                  end if;
                else
                  nibble_cnt <= (others => '0');
                end if;
              end if;

              -- contengencies to handle PP
              if ((nibble_cnt = 2 * qpi_trx_tx_cnt - 1) and (qpi_clkdiv_cnt = (QPI_FREQ_DIV / 2) - 1) and (s_qpi_sclk = '1')) then
                qpi_trx_last <= '1';
              end if;
            end if;

          when DC =>

            -- send the dummy cycles
            if ((qpi_clkdiv_cnt = (QPI_FREQ_DIV / 2) - 1) and (s_qpi_sclk = '0')) then
              nibble_cnt <= nibble_cnt + 1;
              s_d_out    <= "0000";
            end if;

            if (nibble_cnt = qpi_trx_dc_cnt) then
              nibble_cnt <= (others => '0');
              if (qpi_trx_rx_cnt /= 0) then
                qpi_trx_state <= RX;
                if (QPI_FREQ_DIV = 2) then
                  qpi_tx_en <= '0';
                end if;
              else
                s_qpi_ncs     <= '1';
                qpi_trx_busy  <= '0';
                qpi_clk_en    <= '0';
                qpi_trx_state <= CS;
              end if;
            end if;

          when RX =>

            -- read back the answer
            qpi_tx_en <= '0';
            if (nibble_cnt < 2 * qpi_trx_rx_cnt) then
              if ((qpi_clkdiv_cnt = (QPI_FREQ_DIV / 2) - 1) and (s_qpi_sclk = '0')) then
                nibble_cnt                                                                                                                <= nibble_cnt + 1;
                qpi_reg_out( ( 31 - to_integer( nibble_cnt(2 downto 0) ) * 4 ) downto ( 28 - to_integer( nibble_cnt(2 downto 0) ) * 4 ) ) <= s_d_in;
              end if;
            else
              nibble_cnt    <= (others => '0');
              qpi_trx_busy  <= '0';
              s_qpi_ncs     <= '0';
              qpi_clk_en    <= '0';
              qpi_trx_state <= CS;
            end if;

            if ((nibble_cnt /= 0) and ((nibble_cnt(2 downto 0)) = 0)) then
              qpi_trx_word <= '1';
              if (nibble_cnt = 2 * qpi_trx_rx_cnt) then
                qpi_trx_last <= '1';
              end if;
            end if;

          when CS =>

            s_qpi_ncs <= '1';
            if (nibble_cnt < CS_SET_WAIT * QPI_FREQ_DIV) then
              nibble_cnt <= nibble_cnt + 1;
            else
              nibble_cnt    <= (others => '0');
              qpi_trx_state <= TX;
              qpi_trx_done  <= '1';
            end if;

          when others =>

            qpi_trx_state <= TX;

        end case;

      end if;
    end if;

  end process qpi_trx_control;

  -- main state machine, handles mode swithings
  main_process : process (clk) is
  begin

    if (rising_edge(clk)) then
      -- div2 clock generation, generates a free running by 2 clk -- we can enable the regular clock at the rising edge of this
      -- this will allow usage of falling edge to write data and start the actual clock at the rising edge

      s_flash_nrst_prev     <= s_flash_nrst;
      s_int_txnc            <= '0';                                                                      -- keep low unless transaction complete
      fifo_rd_en            <= '0';                                                                      -- default value
      axis_dout_tvalid_curr <= '0';
      axis_dout_tlast       <= '0';
      qpi_trx_en            <= '0';
      s_qpi_nrst            <= '1';
      axis_dout_tvalid_prev <= axis_dout_tvalid_curr;

      if ((s00_axi_aresetn = '0') or (s_flash_nrst = '1' and s_flash_nrst_prev = '0')) then
        cntrst              <= 0;
        flash_adapter_state <= FLASH_RESET;                                                              -- perform a reset on flash
        qpi_trx_txs         <= '0';
        s_status            <= '0';
        s_wip               <= '0';
        s_wrear             <= '0';
        cnt                 <= 0;
      else

        case flash_adapter_state is

          when FLASH_RESET =>

            if (cntrst < FLASH_QPI_NRST_THR) then
              s_qpi_nrst <= '0';
              cntrst     <= cntrst + 1;
            elsif (cntrst < FLASH_RST_CYCLES) then
              cntrst <= cntrst + 1;
            else
              cntrst              <= 0;
              flash_adapter_state <= BOOT;
            end if;

          when BOOT =>

            case cnt is

              when 0 =>

                qpi_reg_in     <= CMD_RES & x"000000";
                qpi_trx_tx_cnt <= 1;
                qpi_trx_dc_cnt <= flash_dc_cnt;
                qpi_trx_rx_cnt <= 1;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  qpi_trx_en <= '0';
                  if (qpi_reg_out( 31 downto 24) = FLASH_ELECTRONIC_ID) then
                    cnt     <= 3;
                    s_id_ok <= '1';
                  else
                    cnt <= 1;
                  end if;
                end if;

              when 1 =>

                -- send WREN -> EQIO command, obv in SPI mode
                qpi_reg_in     <= CMD_WREN_SPI;
                qpi_trx_tx_cnt <= 4;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 0;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  qpi_trx_en <= '0';
                  cnt        <= 2;
                end if;

              when 2 =>

                -- send WREN -> EQIO command, obv in SPI mode
                qpi_reg_in     <= CMD_EQIO_SPI;
                qpi_trx_tx_cnt <= 4;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 0;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  qpi_trx_en <= '0';
                  cnt        <= 0;
                end if;

              when 3 =>

                -- send WREN -> WREAR
                qpi_reg_in     <= CMD_WREN & x"000000";
                qpi_trx_tx_cnt <= 1;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 0;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  qpi_trx_en <= '0';
                  cnt        <= 4;
                end if;

              when 4 =>

                qpi_reg_in     <= CMD_WREAR & x"000000";
                qpi_trx_tx_cnt <= 2;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 0;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  s_wrear             <= '0';
                  qpi_trx_en          <= '0';
                  cnt                 <= 0;
                  s_status            <= '1';
                  flash_adapter_state <= RD;
                end if;

              when others =>

                cnt <= 0;

            end case;

          when RD =>

            -- first chek if the WEN bit is high or not
            if ((s_mode /= RD) and (s_mode /= BOOT) and (s_mode /= FLASH_RESET)) then
              flash_adapter_state <= s_mode;
            else
              -- get read address
              case cnt is

                when 0 =>

                  if (fifo_empty = '0') then
                    fifo_rd_en <= '1';
                    cnt        <= 1;
                    s_wip      <= '1';
                  end if;

                when 1 =>

                  if (fifo_empty = '0') then
                    s_addr     <= fifo_rd_data;
                    fifo_rd_en <= '1';
                    cnt        <= 2;
                  end if;

                when 2 =>

                  -- get read count
                  if (fifo_empty = '0') then
                    nread      <= to_integer(unsigned(fifo_rd_data));
                    fifo_rd_en <= '0';
                  end if;

                  -- correct the EAR value
                  if (s_wrear /= s_addr(24)) then
                    cnt <= 3;
                  else
                    cnt <= 5;
                  end if;

                when 3 =>

                  -- write enable
                  qpi_reg_in     <= CMD_WREN & x"000000";
                  qpi_trx_tx_cnt <= 1;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 4;
                  end if;

                when 4 =>

                  -- CMD_WREAR
                  qpi_reg_in     <= CMD_WREAR & s_addr( 31 downto 24) & x"0000";
                  qpi_trx_tx_cnt <= 2;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 5;
                    s_wrear    <= s_addr(24);
                  end if;

                when 5 =>

                  -- send read command
                  qpi_reg_in     <= CMD_4READ & s_addr( 23 downto 0);
                  qpi_trx_tx_cnt <= 4;
                  qpi_trx_dc_cnt <= flash_dc_cnt;
                  qpi_trx_rx_cnt <= nread;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_word = '1') then
                    axis_dout             <= qpi_reg_out;
                    axis_dout_tvalid_curr <= '1';
                    if (qpi_trx_last = '1') then
                      axis_dout_tlast <= '1';
                    end if;
                  end if;

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    s_wip      <= '0';
                    cnt        <= 0;
                    s_int_txnc <= '1';
                  end if;

                when others =>

                  cnt <= 0;

              end case;

            end if;

          when WR =>

            if ((s_mode /= WR) and (s_mode /= BOOT) and (s_mode /= FLASH_RESET)) then
              flash_adapter_state <= s_mode;
            else

              case cnt is

                when 0 =>

                  if (fifo_empty = '0') then
                    s_addr     <= fifo_rd_data;
                    fifo_rd_en <= '1';
                    s_wip      <= '1';

                    -- correct the EAR value
                    if (s_wrear /= fifo_rd_data(24)) then
                      cnt <= 1;
                    else
                      cnt <= 3;
                    end if;
                  end if;

                when 1 =>

                  -- write enable
                  qpi_reg_in     <= CMD_WREN & x"000000";
                  qpi_trx_tx_cnt <= 1;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 2;
                  end if;

                when 2 =>

                  -- CMD_WREAR
                  qpi_reg_in     <= CMD_WREAR & s_addr( 31 downto 24) & x"0000";
                  qpi_trx_tx_cnt <= 2;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 3;
                    s_wrear    <= s_addr(24);
                  end if;

                when 3 =>

                  -- write enable
                  qpi_reg_in     <= CMD_WREN & x"000000";
                  qpi_trx_tx_cnt <= 1;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 4;
                  end if;

                when 4 =>

                  -- CMD_PP
                  qpi_reg_in     <= CMD_PP & s_addr( 23 downto 0);
                  qpi_trx_tx_cnt <= 4;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';
                  qpi_trx_txs    <= '1';

                  -- for this command, we should be ready when command is about to end
                  if (qpi_trx_busy = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 5;
                  end if;

                when 5 =>

                  -- write the data
                  if (fifo_empty = '0') then
                    if (qpi_trx_last = '1') then
                      qpi_trx_en <= '1';
                      qpi_reg_in <= fifo_rd_data;
                      fifo_rd_en <= '1';
                    end if;
                  else
                    qpi_trx_txs <= '0';
                  end if;

                  if ((fifo_empty = '1') and (qpi_trx_done = '1')) then
                    cnt <= 6;
                  end if;

                when 6 =>

                  -- poll for the WIP bit to be cleared in the status register
                  qpi_reg_in     <= CMD_RDSR & x"000000";
                  qpi_trx_tx_cnt <= 1;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 1;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    if (qpi_reg_out( 24) = '0') then
                      cnt        <= 0;
                      s_wip      <= '0';
                      s_int_txnc <= '1';
                    end if;
                  end if;

                when others =>

                  cnt <= 0;

              end case;

            end if;

          when SE | BE =>

            if ((s_mode /= SE) and (s_mode /= BE) and (s_mode /= BOOT) and (s_mode /= FLASH_RESET)) then
              flash_adapter_state <= s_mode;
            else

              case cnt is

                when 0 =>

                  if (fifo_empty = '0') then
                    s_addr     <= fifo_rd_data;
                    fifo_rd_en <= '1';
                    s_wip      <= '1';

                    -- correct the EAR value
                    if (s_wrear /= fifo_rd_data(24)) then
                      cnt <= 1;
                    else
                      cnt <= 3;
                    end if;
                  end if;

                when 1 =>

                  -- write enable
                  qpi_reg_in     <= CMD_WREN & x"000000";
                  qpi_trx_tx_cnt <= 1;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 2;
                  end if;

                when 2 =>

                  -- CMD_WREAR
                  qpi_reg_in     <= CMD_WREAR & s_addr( 31 downto 24) & x"0000";
                  qpi_trx_tx_cnt <= 2;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 3;
                    s_wrear    <= s_addr(24);
                  end if;

                when 3 =>

                  -- write enable
                  qpi_reg_in     <= CMD_WREN & x"000000";
                  qpi_trx_tx_cnt <= 1;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 4;
                  end if;

                when 4 =>

                  if (flash_adapter_state = SE) then
                    qpi_reg_in <= CMD_SE & s_addr( 23 downto 0);
                  else                                                                                   -- block erase
                    qpi_reg_in <= CMD_BE & s_addr( 23 downto 0);
                  end if;
                  qpi_trx_tx_cnt <= 4;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 0;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    cnt        <= 5;
                  end if;

                when 5 =>

                  -- poll for the WIP bit to be cleared in the status register
                  qpi_reg_in     <= CMD_RDSR & x"000000";
                  qpi_trx_tx_cnt <= 1;
                  qpi_trx_dc_cnt <= 0;
                  qpi_trx_rx_cnt <= 1;
                  qpi_trx_en     <= '1';

                  if (qpi_trx_done = '1') then
                    qpi_trx_en <= '0';
                    if (qpi_reg_out( 24) = '0') then
                      cnt        <= 0;
                      s_wip      <= '0';
                      s_int_txnc <= '1';
                    end if;
                  end if;

                when others =>

                  cnt <= 0;

              end case;

            end if;

          when CE =>

            case cnt is

              when 0 =>

                -- write enable
                qpi_reg_in     <= CMD_WREN & x"000000";
                qpi_trx_tx_cnt <= 1;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 0;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  qpi_trx_en <= '0';
                  cnt        <= 1;
                end if;

              when 1 =>

                -- CMD_CE
                qpi_reg_in     <= CMD_CE & x"000000";
                qpi_trx_tx_cnt <= 1;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 0;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  qpi_trx_en <= '0';
                  cnt        <= 2;
                  s_wrear    <= s_addr(24);
                end if;

              when 2 =>

                -- poll for the WIP bit to be cleared in the status register
                qpi_reg_in     <= CMD_RDSR & x"000000";
                qpi_trx_tx_cnt <= 1;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 1;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  qpi_trx_en <= '0';
                  if (qpi_reg_out( 24) = '0') then
                    cnt        <= 3;
                    s_wip      <= '0';
                    s_int_txnc <= '1';
                  end if;
                end if;

              when 3 =>

                -- This is an autoexecuted state, this prevents CE cycle
                if (s_mode /= CE) then
                  flash_adapter_state <= BOOT;
                  cnt                 <= 0;
                end if;

              when others =>

                cnt <= 0;

            end case;

          when DPD =>

            -- implement deep power down procedure
            case cnt is

              when 0 =>

                -- Send CMD_DP
                qpi_reg_in     <= CMD_DP & x"000000";
                qpi_trx_tx_cnt <= 1;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 0;
                qpi_trx_en     <= '1';
                s_status       <= '0';

                if (qpi_trx_done = '1') then
                  cnt <= 1;
                end if;

              when 1 =>

                if (s_mode /= DPD) then
                  cnt <= 2;
                end if;

              when 2 =>

                -- Send CMD_RDP
                qpi_reg_in     <= CMD_RDP & x"000000";
                qpi_trx_tx_cnt <= 1;
                qpi_trx_dc_cnt <= 0;
                qpi_trx_rx_cnt <= 0;
                qpi_trx_en     <= '1';

                if (qpi_trx_done = '1') then
                  cnt <= 3;
                end if;

              when 3 =>

                -- wait for tRES1 and then go to read mode
                if (cntrst < FLASH_RDP_TRES_THR) then
                  cntrst <= cntrst + 1;
                else
                  cntrst              <= 0;
                  s_int_txnc          <= '1';
                  cnt                 <= 0;
                  flash_adapter_state <= BOOT;
                end if;

              when others =>

                cnt <= 0;

            end case;

          when others =>

            flash_adapter_state <= BOOT;

        end case;

      end if;
    end if;

  end process main_process;

end architecture arch_imp;
