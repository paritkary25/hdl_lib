-------------------------------------------------------------------------------
-- File Downloaded from http://www.nandland.com
--
-- Description: Creates a Synchronous FIFO made out of registers.
--              Generic: g_WIDTH sets the width of the FIFO created.
--              Generic: g_DEPTH sets the depth of the FIFO created.
--
--              Total FIFO register usage will be width * depth
--              Note that this fifo should not be used to cross clock domains.
--              (Read and write clocks NEED TO BE the same clock domain)
--
--              FIFO Full Flag will assert as soon as last word is written.
--              FIFO Empty Flag will assert as soon as last word is read.
--
--              FIFO is 100% synthesizable.  It uses assert statements which do
--              not synthesize, but will cause your simulation to crash if you
--              are doing something you shouldn't be doing (reading from an
--              empty FIFO or writing to a full FIFO).
--
--              No Flags = No Almost Full (AF)/Almost Empty (AE) Flags
--              There is a separate module that has programmable AF/AE flags.
-------------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity module_fifo_regs_no_flags is
  generic (
    G_WIDTH : natural := 8;
    G_DEPTH : integer := 32
  );
  port (
    i_rst_sync : in    std_logic;
    i_clk      : in    std_logic;

    -- FIFO Write Interface
    i_wr_en   : in    std_logic;
    i_wr_data : in    std_logic_vector(G_WIDTH - 1 downto 0);
    o_full    : out   std_logic;

    -- FIFO Read Interface
    i_rd_en   : in    std_logic;
    o_rd_data : out   std_logic_vector(G_WIDTH - 1 downto 0);
    o_empty   : out   std_logic
  );
end entity module_fifo_regs_no_flags;

architecture rtl of module_fifo_regs_no_flags is

  type t_fifo_data is array (0 to g_DEPTH - 1) of std_logic_vector(g_WIDTH - 1 downto 0);

  signal r_fifo_data : t_fifo_data := (others => (others => '0'));

  signal r_wr_index : integer range 0 to G_DEPTH - 1 := 0;
  signal r_rd_index : integer range 0 to G_DEPTH - 1 := 0;

  -- # Words in FIFO, has extra range to allow for assert conditions
  signal r_fifo_count : integer range -1 to G_DEPTH + 1 := 0;

  signal w_full  : std_logic;
  signal w_empty : std_logic;

begin

  p_control : process (i_clk) is
  begin

    if rising_edge(i_clk) then
      if (i_rst_sync = '1') then
        r_fifo_count <= 0;
        r_wr_index   <= 0;
        r_rd_index   <= 0;
      else
        -- Keeps track of the total number of words in the FIFO
        if (i_wr_en = '1' and i_rd_en = '0') then
          r_fifo_count <= r_fifo_count + 1;
        elsif (i_wr_en = '0' and i_rd_en = '1') then
          r_fifo_count <= r_fifo_count - 1;
        end if;

        -- Keeps track of the write index (and controls roll-over)
        if (i_wr_en = '1' and w_full = '0') then
          if (r_wr_index = G_DEPTH - 1) then
            r_wr_index <= 0;
          else
            r_wr_index <= r_wr_index + 1;
          end if;
        end if;

        -- Keeps track of the read index (and controls roll-over)
        if (i_rd_en = '1' and w_empty = '0') then
          if (r_rd_index = G_DEPTH - 1) then
            r_rd_index <= 0;
          else
            r_rd_index <= r_rd_index + 1;
          end if;
        end if;

        -- Registers the input data when there is a write
        if (i_wr_en = '1') then
          r_fifo_data(r_wr_index) <= i_wr_data;
        end if;
      end if;                                        -- sync reset
    end if;                                          -- rising_edge(i_clk)

  end process p_control;

  o_rd_data <= r_fifo_data(r_rd_index);

  w_full  <= '1' when r_fifo_count = G_DEPTH else
             '0';
  w_empty <= '1' when r_fifo_count = 0 else
             '0';

  o_full  <= w_full;
  o_empty <= w_empty;

  -- ASSERTION LOGIC - Not synthesized
  -- synthesis translate_off
  p_assert : process (i_clk) is
  begin

    if rising_edge(i_clk) then
      if (i_wr_en = '1' and w_full = '1') then
        report "ASSERT FAILURE - MODULE_REGISTER_FIFO: FIFO IS FULL AND BEING WRITTEN "
          severity failure;
      end if;

      if (i_rd_en = '1' and w_empty = '1') then
        report "ASSERT FAILURE - MODULE_REGISTER_FIFO: FIFO IS EMPTY AND BEING READ "
          severity failure;
      end if;
    end if;

  end process p_assert;

-- synthesis translate_on

end architecture rtl;
