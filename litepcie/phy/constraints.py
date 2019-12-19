def add_artix7_timing_constraints(platform):
        platform.add_platform_command("""create_clock -name pcie_phy_clk -period 10 [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pcie_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i/TXOUTCLK}}]""")
        platform.add_platform_command("""
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/PLPHYLNKUPN}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/PLRECEIVEDHOTRST}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXELECIDLE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXPHINITDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXPHALIGNDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXDLYSRESETDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXDLYSRESETDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXPHALIGNDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXCDRLOCK}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/CFGMSGRECEIVEDPMETO}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/PLL0LOCK}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXPMARESETDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXSYNCDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXSYNCDONE}}]

set_false_path -to [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0}}]
set_false_path -to [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1}}]
create_generated_clock -name clk_125mhz_phy [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/mmcm_i/CLKOUT0}}]
create_generated_clock -name clk_250mhz_phy [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/mmcm_i/CLKOUT1}}]
create_generated_clock -name clk_125mhz_mux_phy \
                        -source [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I0}}] \
                        -divide_by 1 \
                        [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}}]
create_generated_clock -name clk_250mhz_mux_phy \
                        -source [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}}] \
                        -divide_by 1 -add -master_clock [get_clocks -of [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}}]] \
                        [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}}]
set_clock_groups -name pcieclkmux -physically_exclusive -group clk_125mhz_mux_phy -group clk_250mhz_mux_phy
        """)

def add_kintex7_timing_constraints(platform):
        platform.add_platform_command("""create_clock -name pcie_phy_clk -period 10 [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pcie_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXOUTCLK}}]""")
        platform.add_platform_command("""
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/PLPHYLNKUPN}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/PLRECEIVEDHOTRST}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXELECIDLE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXPHINITDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXPHALIGNDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXDLYSRESETDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXDLYSRESETDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXPHALIGNDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXCDRLOCK}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/CFGMSGRECEIVEDPMETO}}]

set_false_path -to [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0}}]
set_false_path -to [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1}}]
create_generated_clock -name clk_125mhz_phy [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/mmcm_i/CLKOUT0}}]
create_generated_clock -name clk_250mhz_phy [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/mmcm_i/CLKOUT1}}]
create_generated_clock -name clk_125mhz_mux_phy \
                        -source [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I0}}] \
                        -divide_by 1 \
                        [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}}]
create_generated_clock -name clk_250mhz_mux_phy \
                        -source [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}}] \
                        -divide_by 1 -add -master_clock [get_clocks -of [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}}]] \
                        [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}}]
set_clock_groups -name pcieclkmux -physically_exclusive -group clk_125mhz_mux_phy -group clk_250mhz_mux_phy
        """)

def add_virtex7_timing_constraints(platform):
        platform.add_platform_command("""create_clock -name pcie_phy_clk -period 10 [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pcie_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtx_channel.gtxe2_channel_i/TXOUTCLK}}]""")
        platform.add_platform_command("""
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/PLPHYLNKUPN}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/PLRECEIVEDHOTRST}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXELECIDLE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXPHINITDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXPHALIGNDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/TXDLYSRESETDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXDLYSRESETDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXPHALIGNDONE}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/RXCDRLOCK}}]
set_false_path -through [get_pins -hierarchical -filter {{NAME=~*/CFGMSGRECEIVEDPMETO}}]

set_false_path -to [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0}}]
set_false_path -to [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1}}]
create_generated_clock -name clk_125mhz_phy [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/mmcm_i/CLKOUT0}}]
create_generated_clock -name clk_250mhz_phy [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/mmcm_i/CLKOUT1}}]
create_generated_clock -name clk_125mhz_mux_phy \
                        -source [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I0}}] \
                        -divide_by 1 \
                        [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}}]
create_generated_clock -name clk_250mhz_mux_phy \
                        -source [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}}] \
                        -divide_by 1 -add -master_clock [get_clocks -of [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}}]] \
                        [get_pins -hierarchical -filter {{NAME=~*pcie_phy/pcie_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}}]
set_clock_groups -name pcieclkmux -physically_exclusive -group clk_125mhz_mux_phy -group clk_250mhz_mux_phy
        """)
