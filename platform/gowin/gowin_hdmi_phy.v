module gowin_hdmi_phy(
  input  wire        hdmi_clk,
  input  wire        hdmi_clk_5x,
  input  wire [9:0]  tmds_ch0,   // blue/control lane symbol
  input  wire [9:0]  tmds_ch1,   // green lane symbol
  input  wire [9:0]  tmds_ch2,   // red lane symbol
  input  wire        reset,

  // External HDMI/TMDS differential outputs:
  //   [3] = TMDS clock lane
  //   [2] = TMDS data lane 2 (red channel during active video)
  //   [1] = TMDS data lane 1 (green channel during active video)
  //   [0] = TMDS data lane 0 (blue channel during active video, plus hsync/vsync
  //         control tokens during blanking)
  output wire [3:0]  hdmi_tx_n,
  output wire [3:0]  hdmi_tx_p
);

  // TMDS channel meanings:
  //   channel 0 = blue data / control lane
  //   channel 1 = green data lane
  //   channel 2 = red data lane
  //
  // HDMI pin meanings in this module:
  //   hdmi_tx_p[n] = positive side of the differential pair
  //   hdmi_tx_n[n] = negative side of the differential pair
  //
  // The board-specific PHY only serializes and drives already-encoded TMDS
  // symbols. Shared TMDS encoding lives outside this module so the same encoder
  // logic can be reused across different vendor PHY implementations.
  //
  // Each lane arrives here as one 10-bit TMDS symbol per pixel clock. The
  // serializer turns that into one fast serial bitstream per lane at 10 bits
  // per pixel.
  wire serial_tmds[2:0];

  // OSER10 is Gowin's 10:1 output serializer.
  //
  // - PCLK is the parallel-word clock: one TMDS symbol arrives each pixel.
  // - FCLK is the fast serialization clock: for DDR-style internal operation
  //   Gowin expects a 5x clock in order to shift out 10 bits over one pixel.
  // - D0..D9 are the 10 parallel bits to serialize.
  // - Q is the resulting single-bit high-speed serial stream.
  // - RESET clears the serializer state.
  //
  // Parameters:
  // - GSREN("false"): do not use the device-wide global set/reset network for
  //   this primitive's reset behavior.
  // - LSREN("true"): enable the primitive's local reset input so RESET here
  //   directly controls the serializer.
  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c0 (
    .PCLK (hdmi_clk),
    .FCLK (hdmi_clk_5x),
    .RESET(reset),
    .Q    (serial_tmds[0]),
    .D0   (tmds_ch0[0]), .D1(tmds_ch0[1]), .D2(tmds_ch0[2]), .D3(tmds_ch0[3]), .D4(tmds_ch0[4]),
    .D5   (tmds_ch0[5]), .D6(tmds_ch0[6]), .D7(tmds_ch0[7]), .D8(tmds_ch0[8]), .D9(tmds_ch0[9])
  );

  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c1 (
    .PCLK (hdmi_clk),
    .FCLK (hdmi_clk_5x),
    .RESET(reset),
    .Q    (serial_tmds[1]),
    .D0   (tmds_ch1[0]), .D1(tmds_ch1[1]), .D2(tmds_ch1[2]), .D3(tmds_ch1[3]), .D4(tmds_ch1[4]),
    .D5   (tmds_ch1[5]), .D6(tmds_ch1[6]), .D7(tmds_ch1[7]), .D8(tmds_ch1[8]), .D9(tmds_ch1[9])
  );

  OSER10 #(.GSREN("false"), .LSREN("true")) ser_c2 (
    .PCLK (hdmi_clk),
    .FCLK (hdmi_clk_5x),
    .RESET(reset),
    .Q    (serial_tmds[2]),
    .D0   (tmds_ch2[0]), .D1(tmds_ch2[1]), .D2(tmds_ch2[2]), .D3(tmds_ch2[3]), .D4(tmds_ch2[4]),
    .D5   (tmds_ch2[5]), .D6(tmds_ch2[6]), .D7(tmds_ch2[7]), .D8(tmds_ch2[8]), .D9(tmds_ch2[9])
  );

  // TLVDS_OBUF converts each single-ended internal signal into the external
  // differential pair driven on the HDMI connector:
  //   hdmi_tx_[3] = TMDS clock pair
  //   hdmi_tx_[2] = TMDS data2 / red pair
  //   hdmi_tx_[1] = TMDS data1 / green pair
  //   hdmi_tx_[0] = TMDS data0 / blue-control pair
  TLVDS_OBUF OBUFDS_clock (.I(hdmi_clk),       .O(hdmi_tx_p[3]), .OB(hdmi_tx_n[3]));
  TLVDS_OBUF OBUFDS_red   (.I(serial_tmds[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  TLVDS_OBUF OBUFDS_green (.I(serial_tmds[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  TLVDS_OBUF OBUFDS_blue  (.I(serial_tmds[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));

endmodule
