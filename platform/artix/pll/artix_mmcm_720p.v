module artix_mmcm_720p(
  output wire pixel_clk,
  output wire pixel_clk_5x,
  input  wire resetn,
  output wire locked,
  input  wire clk_in_p,
  input  wire clk_in_n
);
  wire clk_in;
  wire clkfb;
  wire clkfb_buf;
  wire pixel_clk_int;
  wire pixel_clk_5x_int;

  // Derived from the local Puhzi HDMI course demo:
  //   input  = 200 MHz differential
  //   output = 74.25 MHz pixel clock
  //   output = 371.25 MHz TMDS serial clock
  IBUFDS clkin_ibufds (
    .O (clk_in),
    .I (clk_in_p),
    .IB(clk_in_n)
  );

  MMCME2_ADV #(
    .BANDWIDTH           ("OPTIMIZED"),
    .CLKOUT4_CASCADE     ("FALSE"),
    .COMPENSATION        ("ZHOLD"),
    .STARTUP_WAIT        ("FALSE"),
    .DIVCLK_DIVIDE       (10),
    .CLKFBOUT_MULT_F     (37.125),
    .CLKFBOUT_PHASE      (0.000),
    .CLKFBOUT_USE_FINE_PS("FALSE"),
    .CLKOUT0_DIVIDE_F    (10.000),
    .CLKOUT0_PHASE       (0.000),
    .CLKOUT0_DUTY_CYCLE  (0.500),
    .CLKOUT0_USE_FINE_PS ("FALSE"),
    .CLKOUT1_DIVIDE      (2),
    .CLKOUT1_PHASE       (0.000),
    .CLKOUT1_DUTY_CYCLE  (0.500),
    .CLKOUT1_USE_FINE_PS ("FALSE"),
    .CLKIN1_PERIOD       (5.000)
  ) mmcm_inst (
    .CLKFBOUT    (clkfb),
    .CLKFBOUTB   (),
    .CLKOUT0     (pixel_clk_int),
    .CLKOUT0B    (),
    .CLKOUT1     (pixel_clk_5x_int),
    .CLKOUT1B    (),
    .CLKOUT2     (),
    .CLKOUT2B    (),
    .CLKOUT3     (),
    .CLKOUT3B    (),
    .CLKOUT4     (),
    .CLKOUT5     (),
    .CLKOUT6     (),
    .CLKFBIN     (clkfb_buf),
    .CLKIN1      (clk_in),
    .CLKIN2      (1'b0),
    .CLKINSEL    (1'b1),
    .DADDR       (7'h0),
    .DCLK        (1'b0),
    .DEN         (1'b0),
    .DI          (16'h0),
    .DO          (),
    .DRDY        (),
    .DWE         (1'b0),
    .PSCLK       (1'b0),
    .PSEN        (1'b0),
    .PSINCDEC    (1'b0),
    .PSDONE      (),
    .LOCKED      (locked),
    .CLKINSTOPPED(),
    .CLKFBSTOPPED(),
    .PWRDWN      (1'b0),
    .RST         (~resetn)
  );

  BUFG clkfb_bufg (
    .O(clkfb_buf),
    .I(clkfb)
  );

  BUFG pixel_clk_bufg (
    .O(pixel_clk),
    .I(pixel_clk_int)
  );

  BUFG pixel_clk_5x_bufg (
    .O(pixel_clk_5x),
    .I(pixel_clk_5x_int)
  );
endmodule
