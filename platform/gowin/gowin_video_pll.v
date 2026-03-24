module gowin_video_pll #(
  parameter VIDEO_MODE = 0,
  parameter PLL_DEVICE = "GW2AR-18C"
)(
  input  wire clkin,
  input  wire reset,
  output wire clkout_5x,
  output wire lock
);

  localparam MODE_720X480  = 0;

  generate
    if (VIDEO_MODE == MODE_720X480) begin : g_mode_480p
      Gowin_rPLL_480p #(
        .DEVICE(PLL_DEVICE)
      ) u_pll (
        .clkout(clkout_5x),
        .lock  (lock),
        .reset (reset),
        .clkin (clkin)
      );
    end else begin : g_mode_720p
      Gowin_rPLL_720p #(
        .DEVICE(PLL_DEVICE)
      ) u_pll (
        .clkout(clkout_5x),
        .lock  (lock),
        .reset (reset),
        .clkin (clkin)
      );
    end
  endgenerate

endmodule
