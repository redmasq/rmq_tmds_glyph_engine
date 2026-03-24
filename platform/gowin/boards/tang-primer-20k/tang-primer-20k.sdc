create_clock -name clk_in -period 37.037 [get_ports {clk}]
create_clock -name hdmi_clk_5x -period 7.407 [get_pins {hdmi_pll/u_pll/rpll_inst/CLKOUT}]
create_clock -name hdmi_clk -period 37.037 [get_pins {u_clkdiv5/CLKOUT}]
