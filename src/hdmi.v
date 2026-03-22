module tmds_encoder(
  input  wire       i_hdmi_clk,
  input  wire       i_reset,
  input  wire [7:0] i_data,
  input  wire [1:0] i_ctrl,
  input  wire       i_display_enable,
  output reg  [9:0] o_tmds
);

  function [3:0] count_ones8;
    input [7:0] v;
    begin
      count_ones8 = v[0] + v[1] + v[2] + v[3] + v[4] + v[5] + v[6] + v[7];
    end
  endfunction

  function signed [4:0] balance8;
    input [7:0] v;
    reg [3:0] n1;
    begin
      n1 = count_ones8(v);
      balance8 = $signed({1'b0, n1}) - 5'sd4;
    end
  endfunction

  reg  [8:0] q_m;
  reg        use_xnor;
  reg signed [5:0] disparity;
  reg signed [4:0] balance;

  always @* begin
    use_xnor = (count_ones8(i_data) > 4) || ((count_ones8(i_data) == 4) && (i_data[0] == 1'b0));

    q_m[0] = i_data[0];
    q_m[1] = use_xnor ? ~(q_m[0] ^ i_data[1]) : (q_m[0] ^ i_data[1]);
    q_m[2] = use_xnor ? ~(q_m[1] ^ i_data[2]) : (q_m[1] ^ i_data[2]);
    q_m[3] = use_xnor ? ~(q_m[2] ^ i_data[3]) : (q_m[2] ^ i_data[3]);
    q_m[4] = use_xnor ? ~(q_m[3] ^ i_data[4]) : (q_m[3] ^ i_data[4]);
    q_m[5] = use_xnor ? ~(q_m[4] ^ i_data[5]) : (q_m[4] ^ i_data[5]);
    q_m[6] = use_xnor ? ~(q_m[5] ^ i_data[6]) : (q_m[5] ^ i_data[6]);
    q_m[7] = use_xnor ? ~(q_m[6] ^ i_data[7]) : (q_m[6] ^ i_data[7]);
    q_m[8] = ~use_xnor;

    balance = balance8(q_m[7:0]);
  end

  always @(posedge i_hdmi_clk) begin
    if (i_reset) begin
      disparity <= 6'sd0;
      o_tmds    <= 10'b1101010100;
    end else if (!i_display_enable) begin
      disparity <= 6'sd0;
      case (i_ctrl)
        2'b00: o_tmds <= 10'b1101010100;
        2'b01: o_tmds <= 10'b0010101011;
        2'b10: o_tmds <= 10'b0101010100;
        2'b11: o_tmds <= 10'b1010101011;
      endcase
    end else begin
      if ((disparity == 0) || (balance == 0)) begin
        if (q_m[8]) begin
          o_tmds    <= {2'b01, q_m[7:0]};
          disparity <= disparity + balance;
        end else begin
          o_tmds    <= {2'b10, ~q_m[7:0]};
          disparity <= disparity - balance;
        end
      end else if (((disparity > 0) && (balance > 0)) ||
                   ((disparity < 0) && (balance < 0))) begin
        o_tmds    <= {1'b1, q_m[8], ~q_m[7:0]};
        disparity <= disparity + (q_m[8] ? 6'sd2 : 6'sd0) - balance;
      end else begin
        o_tmds    <= {1'b0, q_m[8], q_m[7:0]};
        disparity <= disparity + balance - (q_m[8] ? 6'sd0 : 6'sd2);
      end
    end
  end

endmodule


module hdmi(
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