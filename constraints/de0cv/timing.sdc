# ----------
#   Clock
# ----------

create_clock -name clock_in_50mhz_0 -period 20.000 [get_ports {CLK_50M[0]}]
create_clock -name clock_in_50mhz_1 -period 20.000 [get_ports {CLK_50M[1]}]
create_clock -name clock_in_50mhz_2 -period 20.000 [get_ports {CLK_50M[2]}]
create_clock -name clock_in_50mhz_3 -period 20.000 [get_ports {CLK_50M[3]}]

create_generated_clock -name pad_clk -source [get_ports {CLK_50M[0]}] -divide_by 100 [get_registers {clock_generator:clock_generator|pad_clk}]

derive_pll_clocks
derive_clock_uncertainty

# ---------------
#   False Path
# ---------------

# master_clk <-> apu_clk
set_clock_groups -asynchronous -group [get_clocks {clock_generator|pll_master|pll_master_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -group [get_clocks {clock_generator|pll_apu|pll_apu_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]

# master_clk <-> dr_clk
set_clock_groups -asynchronous -group [get_clocks {clock_generator|pll_master|pll_master_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -group [get_clocks {clock_generator|pll_dr|pll_dr_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]

# master_clk <-> pad_clk
set_clock_groups -asynchronous -group [get_clocks {clock_generator|pll_master|pll_master_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -group [get_clocks {pad_clk}]

# dr_clk <-> vga_clk
set_clock_groups -asynchronous -group [get_clocks {clock_generator|pll_dr|pll_dr_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] -group [get_clocks {clock_generator|pll_vga|pll_vga_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]

# CLK_50M[0] <-> apu_clk
set_clock_groups -asynchronous -group [get_clocks {clock_in_50mhz_0}] -group [get_clocks {clock_generator|pll_apu|pll_apu_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
