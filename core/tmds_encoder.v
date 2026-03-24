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
