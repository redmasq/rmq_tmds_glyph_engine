`include "generated/video_mode_config.vh"

module gowin_video_pll #(
  parameter PLL_DEVICE = "GW2AR-18C"
)(
  input  wire clkin,
  input  wire reset,
  output wire clkout_5x,
  output wire lock
);

`ifdef VIDEO_MODE_720P
  Gowin_rPLL_720p #(
    .DEVICE(PLL_DEVICE)
  ) u_pll (
    .clkout(clkout_5x),
    .lock  (lock),
    .reset (reset),
    .clkin (clkin)
  );
`else
  Gowin_rPLL_480p #(
    .DEVICE(PLL_DEVICE)
  ) u_pll (
    .clkout(clkout_5x),
    .lock  (lock),
    .reset (reset),
    .clkin (clkin)
  );
`endif

endmodule
