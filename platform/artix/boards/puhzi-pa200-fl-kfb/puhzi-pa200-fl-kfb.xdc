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

# Temporary generic debug PMOD passthrough using the preferred JM1 GPIO set.
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {debug_pmod_pins[0]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {debug_pmod_pins[1]}]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {debug_pmod_pins[2]}]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {debug_pmod_pins[3]}]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {debug_pmod_pins[4]}]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {debug_pmod_pins[5]}]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {debug_pmod_pins[6]}]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {debug_pmod_pins[7]}]

# HDMI TMDS positive pins from the local Puhzi HDMI reference design.
set_property -dict {PACKAGE_PIN N13 IOSTANDARD TMDS_33} [get_ports HDMI_D2_P]
set_property -dict {PACKAGE_PIN AA18 IOSTANDARD TMDS_33} [get_ports HDMI_D1_P]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD TMDS_33} [get_ports HDMI_D0_P]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD TMDS_33} [get_ports HDMI_CLK_P]

# Input clock timing matches the 200 MHz differential board clock.
create_clock -period 5.000 [get_ports sys_clk_p]
set_input_jitter [get_clocks -of_objects [get_ports sys_clk_p]] 0.050
