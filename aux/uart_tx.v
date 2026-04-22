module uart_tx #(
  parameter integer CLK_HZ = 74250000,
  parameter integer BAUD_RATE = 115200
)(
  input  wire       i_clk,
  input  wire       i_reset,
  input  wire [7:0] i_data,
  input  wire       i_valid,
  output wire       o_ready,
  output wire       o_busy,
  output wire       o_tx
);

  localparam integer DIVISOR = (CLK_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
  localparam integer DIV_W = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);

  reg [DIV_W-1:0] baud_count;
  reg [3:0]       bit_count;
  reg [9:0]       shift_reg;
  reg             busy;
  reg             tx_reg;

  assign o_ready = !busy;
  assign o_busy = busy;
  assign o_tx = tx_reg;

  always @(posedge i_clk) begin
    if (i_reset) begin
      baud_count <= {DIV_W{1'b0}};
      bit_count  <= 4'd0;
      shift_reg  <= 10'h3FF;
      busy       <= 1'b0;
      tx_reg     <= 1'b1;
    end else begin
      if (!busy) begin
        tx_reg <= 1'b1;
        if (i_valid) begin
          shift_reg  <= {1'b1, i_data, 1'b0};
          bit_count  <= 4'd10;
          baud_count <= {DIV_W{1'b0}};
          busy       <= 1'b1;
          tx_reg     <= 1'b0;
        end
      end else begin
        if (baud_count == DIVISOR - 1) begin
          baud_count <= {DIV_W{1'b0}};
          shift_reg  <= {1'b1, shift_reg[9:1]};
          bit_count  <= bit_count - 4'd1;
          tx_reg     <= shift_reg[1];

          if (bit_count == 4'd1) begin
            busy   <= 1'b0;
            tx_reg <= 1'b1;
          end
        end else begin
          baud_count <= baud_count + {{(DIV_W-1){1'b0}}, 1'b1};
        end
      end
    end
  end

endmodule
