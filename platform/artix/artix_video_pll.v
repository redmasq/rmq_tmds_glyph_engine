module artix_video_pll #(
  parameter VIDEO_MODE = 0  // 0 = 720x480p60, 1 = 1280x720p60
)(
  input  wire clkin_p,
  input  wire clkin_n,
  input  wire reset,
  output wire pixel_clk,
  output wire pixel_clk_5x,
  output wire locked
);
  localparam MODE_720X480 = 0;

  generate
    if (VIDEO_MODE == MODE_720X480) begin : g_mode_480p
      artix_pll_480p u_pll (
        .pixel_clk_5x(pixel_clk_5x),
        .pixel_clk   (pixel_clk),
        .reset       (reset),
        .locked      (locked),
        .clk_in_p    (clkin_p),
        .clk_in_n    (clkin_n)
      );
    end else begin : g_mode_720p
      artix_mmcm_720p u_mmcm (
        .pixel_clk   (pixel_clk),
        .pixel_clk_5x(pixel_clk_5x),
        .resetn      (~reset),
        .locked      (locked),
        .clk_in_p    (clkin_p),
        .clk_in_n    (clkin_n)
      );
    end
  endgenerate
endmodule
