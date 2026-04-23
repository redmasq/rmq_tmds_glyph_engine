module uart_rx #(
  parameter integer CLK_HZ = 74250000,
  parameter integer BAUD_RATE = 115200
)(
  input  wire       i_clk,
  input  wire       i_reset,
  input  wire       i_rx,
  output reg  [7:0] o_data,
  output reg        o_valid
);

  localparam integer DIVISOR = (CLK_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
  localparam integer DIV_W = (DIVISOR <= 1) ? 1 : $clog2(DIVISOR);
  localparam [2:0] S_IDLE = 3'd0;
  localparam [2:0] S_START = 3'd1;
  localparam [2:0] S_DATA = 3'd2;
  localparam [2:0] S_STOP = 3'd3;

  reg [2:0] state;
  reg [DIV_W-1:0] baud_count;
  reg [2:0] bit_count;
  reg [7:0] shift_reg;
  reg rx_d0;
  reg rx_d1;

  wire rx_falling = rx_d1 && !rx_d0;

  always @(posedge i_clk) begin
    if (i_reset) begin
      state <= S_IDLE;
      baud_count <= {DIV_W{1'b0}};
      bit_count <= 3'd0;
      shift_reg <= 8'h00;
      rx_d0 <= 1'b1;
      rx_d1 <= 1'b1;
      o_data <= 8'h00;
      o_valid <= 1'b0;
    end else begin
      rx_d0 <= i_rx;
      rx_d1 <= rx_d0;
      o_valid <= 1'b0;

      case (state)
        S_IDLE: begin
          baud_count <= {DIV_W{1'b0}};
          bit_count <= 3'd0;
          if (rx_falling) begin
            state <= S_START;
          end
        end

        S_START: begin
          if (baud_count == ((DIVISOR / 2) - 1)) begin
            baud_count <= {DIV_W{1'b0}};
            if (!rx_d0) begin
              state <= S_DATA;
            end else begin
              state <= S_IDLE;
            end
          end else begin
            baud_count <= baud_count + {{(DIV_W-1){1'b0}}, 1'b1};
          end
        end

        S_DATA: begin
          if (baud_count == DIVISOR - 1) begin
            baud_count <= {DIV_W{1'b0}};
            shift_reg[bit_count] <= rx_d0;
            if (bit_count == 3'd7) begin
              bit_count <= 3'd0;
              state <= S_STOP;
            end else begin
              bit_count <= bit_count + 3'd1;
            end
          end else begin
            baud_count <= baud_count + {{(DIV_W-1){1'b0}}, 1'b1};
          end
        end

        S_STOP: begin
          if (baud_count == DIVISOR - 1) begin
            baud_count <= {DIV_W{1'b0}};
            state <= S_IDLE;
            if (rx_d0) begin
              o_data <= shift_reg;
              o_valid <= 1'b1;
            end
          end else begin
            baud_count <= baud_count + {{(DIV_W-1){1'b0}}, 1'b1};
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
