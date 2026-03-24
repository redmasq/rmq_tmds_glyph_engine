module artix_pll_480p(
  output wire pixel_clk_5x,
  output wire pixel_clk,
  input  wire reset,
  output wire locked,
  input  wire clk_in_p,
  input  wire clk_in_n
);
  wire clk_in_buf;
  wire clk_in;
  wire clkfb;
  wire clkfb_buf;
  wire pixel_clk_5x_int;
  wire pixel_clk_int;

  // Generated from a local Vivado Clocking Wizard project for the Puhzi board:
  //   input  = 200 MHz differential
  //   output = 135 MHz TMDS serial clock
  //   output = 27 MHz pixel clock
  IBUFDS clkin_ibufds (
    .O (clk_in_buf),
    .I (clk_in_p),
    .IB(clk_in_n)
  );

  BUFG clkin_bufg (
    .O(clk_in),
    .I(clk_in_buf)
  );

  PLLE2_ADV #(
    .BANDWIDTH         ("OPTIMIZED"),
    .COMPENSATION      ("ZHOLD"),
    .STARTUP_WAIT      ("FALSE"),
    .DIVCLK_DIVIDE     (5),
    .CLKFBOUT_MULT     (27),
    .CLKFBOUT_PHASE    (0.000),
    .CLKOUT0_DIVIDE    (8),
    .CLKOUT0_PHASE     (0.000),
    .CLKOUT0_DUTY_CYCLE(0.500),
    .CLKOUT1_DIVIDE    (40),
    .CLKOUT1_PHASE     (0.000),
    .CLKOUT1_DUTY_CYCLE(0.500),
    .CLKIN1_PERIOD     (5.000)
  ) pll_inst (
    .CLKFBOUT (clkfb),
    .CLKOUT0  (pixel_clk_5x_int),
    .CLKOUT1  (pixel_clk_int),
    .CLKOUT2  (),
    .CLKOUT3  (),
    .CLKOUT4  (),
    .CLKOUT5  (),
    .CLKFBIN  (clkfb_buf),
    .CLKIN1   (clk_in),
    .CLKIN2   (1'b0),
    .CLKINSEL (1'b1),
    .DADDR    (7'h0),
    .DCLK     (1'b0),
    .DEN      (1'b0),
    .DI       (16'h0),
    .DO       (),
    .DRDY     (),
    .DWE      (1'b0),
    .LOCKED   (locked),
    .PWRDWN   (1'b0),
    .RST      (reset)
  );

  BUFG clkfb_bufg (
    .O(clkfb_buf),
    .I(clkfb)
  );

  BUFG pixel_clk_5x_bufg (
    .O(pixel_clk_5x),
    .I(pixel_clk_5x_int)
  );

  BUFG pixel_clk_bufg (
    .O(pixel_clk),
    .I(pixel_clk_int)
  );
endmodule
