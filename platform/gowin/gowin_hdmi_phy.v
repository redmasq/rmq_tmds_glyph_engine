module gowin_hdmi_phy(
  input  wire        hdmi_clk,
  input  wire        hdmi_clk_5x,
  input  wire [2:0]  hve_sync,   // {display_enable, vsync, hsync}
  input  wire [23:0] rgb,        // {R,G,B}
  input  wire        reset,

  output wire [3:0]  hdmi_tx_n,
  output wire [3:0]  hdmi_tx_p
);

  wire [9:0] tmds_ch0;
  wire [9:0] tmds_ch1;
  wire [9:0] tmds_ch2;

  tmds_encoder encode_b (
    .i_hdmi_clk      (hdmi_clk),
    .i_reset         (reset),
    .i_data          (rgb[7:0]),
    .i_ctrl          (hve_sync[1:0]),
    .i_display_enable(hve_sync[2]),
    .o_tmds          (tmds_ch0)
  );

  tmds_encoder encode_g (
    .i_hdmi_clk      (hdmi_clk),
    .i_reset         (reset),
    .i_data          (rgb[15:8]),
    .i_ctrl          (2'b00),
    .i_display_enable(hve_sync[2]),
    .o_tmds          (tmds_ch1)
  );

  tmds_encoder encode_r (
    .i_hdmi_clk      (hdmi_clk),
    .i_reset         (reset),
    .i_data          (rgb[23:16]),
    .i_ctrl          (2'b00),
    .i_display_enable(hve_sync[2]),
    .o_tmds          (tmds_ch2)
  );

  wire serial_tmds[2:0];

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

  TLVDS_OBUF OBUFDS_clock (.I(hdmi_clk),       .O(hdmi_tx_p[3]), .OB(hdmi_tx_n[3]));
  TLVDS_OBUF OBUFDS_red   (.I(serial_tmds[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  TLVDS_OBUF OBUFDS_green (.I(serial_tmds[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  TLVDS_OBUF OBUFDS_blue  (.I(serial_tmds[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));

endmodule
