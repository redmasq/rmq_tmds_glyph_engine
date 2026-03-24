module artix_hdmi_phy(
  input  wire        pixel_clk,
  input  wire        pixel_clk_5x,
  input  wire [9:0]  tmds_ch0,
  input  wire [9:0]  tmds_ch1,
  input  wire [9:0]  tmds_ch2,
  input  wire        reset,
  output wire [3:0]  hdmi_tx_p,
  output wire [3:0]  hdmi_tx_n
);
  // The Artix PHY mirrors the Gowin seam: shared logic provides already-encoded
  // 10-bit TMDS symbols and the PHY handles only serialization and differential
  // output buffering.
  localparam [9:0] TMDS_CLK_PATTERN = 10'b1111100000;

  artix_serializer_10to1 ser_clk (
    .pixel_clk   (pixel_clk),
    .pixel_clk_5x(pixel_clk_5x),
    .parallel_in (TMDS_CLK_PATTERN),
    .reset       (reset),
    .serial_out  (hdmi_tx_p[3]),
    .serial_out_n(hdmi_tx_n[3])
  );

  artix_serializer_10to1 ser_d2 (
    .pixel_clk   (pixel_clk),
    .pixel_clk_5x(pixel_clk_5x),
    .parallel_in (tmds_ch2),
    .reset       (reset),
    .serial_out  (hdmi_tx_p[2]),
    .serial_out_n(hdmi_tx_n[2])
  );

  artix_serializer_10to1 ser_d1 (
    .pixel_clk   (pixel_clk),
    .pixel_clk_5x(pixel_clk_5x),
    .parallel_in (tmds_ch1),
    .reset       (reset),
    .serial_out  (hdmi_tx_p[1]),
    .serial_out_n(hdmi_tx_n[1])
  );

  artix_serializer_10to1 ser_d0 (
    .pixel_clk   (pixel_clk),
    .pixel_clk_5x(pixel_clk_5x),
    .parallel_in (tmds_ch0),
    .reset       (reset),
    .serial_out  (hdmi_tx_p[0]),
    .serial_out_n(hdmi_tx_n[0])
  );
endmodule
