set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes [current_design]

# Differential 200 MHz logic clock.
set_property -dict {PACKAGE_PIN R4 IOSTANDARD DIFF_SSTL15} [get_ports sys_clk_p]
set_property -dict {PACKAGE_PIN T4 IOSTANDARD DIFF_SSTL15} [get_ports sys_clk_n]

# Active-low reset button.
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports sys_rstn]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33 PULLUP true} [get_ports key1_n]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN W17 IOSTANDARD LVCMOS33 PULLUP true} [get_ports uart_rx]

# HDMI TMDS positive pins from the local Puhzi HDMI reference design.
set_property -dict {PACKAGE_PIN N13 IOSTANDARD TMDS_33} [get_ports HDMI_D2_P]
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD TMDS_33} [get_ports HDMI_D1_P]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD TMDS_33} [get_ports HDMI_D0_P]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD TMDS_33} [get_ports HDMI_CLK_P]

# Input clock timing matches the 200 MHz differential board clock.
create_clock -period 5.000 [get_ports sys_clk_p]
set_input_jitter [get_clocks -of_objects [get_ports sys_clk_p]] 0.050
