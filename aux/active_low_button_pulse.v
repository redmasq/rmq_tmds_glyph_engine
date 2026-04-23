module active_low_button_pulse #(
  parameter integer RELEASE_TICKS = 1
)(
  input  wire i_clk,
  input  wire i_reset,
  input  wire i_button_n,
  output reg  o_pulse
);

  localparam integer RELEASE_W = (RELEASE_TICKS <= 1) ? 1 : $clog2(RELEASE_TICKS);
  localparam [RELEASE_W-1:0] RELEASE_MAX = RELEASE_TICKS - 1;

  reg button_d;
  reg armed;
  reg [RELEASE_W-1:0] release_count;

  always @(posedge i_clk) begin
    if (i_reset) begin
      button_d <= 1'b1;
      armed <= 1'b1;
      release_count <= {RELEASE_W{1'b0}};
      o_pulse <= 1'b0;
    end else begin
      button_d <= i_button_n;
      o_pulse <= armed && button_d && !i_button_n;

      if (!i_button_n) begin
        armed <= 1'b0;
        release_count <= {RELEASE_W{1'b0}};
      end else if (!armed) begin
        if (RELEASE_TICKS <= 1) begin
          armed <= 1'b1;
        end else if (release_count == RELEASE_MAX) begin
          armed <= 1'b1;
        end else begin
          release_count <= release_count + {{(RELEASE_W-1){1'b0}}, 1'b1};
        end
      end
    end
  end

endmodule
