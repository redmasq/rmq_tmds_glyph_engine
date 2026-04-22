module tang_primer_debug_uart_logger #(
  parameter integer CLK_HZ = 74250000,
  parameter integer BAUD_RATE = 115200,
  parameter integer RELEASE_TICKS = CLK_HZ / 20,
  parameter integer DELTA_COUNTER_BITS = 25
)(
  input  wire       i_clk,
  input  wire       i_reset,
  input  wire       i_capture_next_n,
  input  wire [4:0] i_target_slot,
  input  wire [2:0] i_pattern_index,
  input  wire [3:0] i_col_offset,
  input  wire [7:0] i_mask,
  input  wire [3:0] i_raw_col_drive,
  input  wire [7:0] i_raw_pmod,
  input  wire [3:0] i_raw_rows,
  input  wire [3:0] i_row_bits,
  input  wire [3:0] i_col_bits,
  input  wire       i_any_active,

  output wire       o_uart_tx
);

  localparam integer MESSAGE_LEN = 49;
  localparam integer MESSAGE_W = (MESSAGE_LEN <= 1) ? 1 : $clog2(MESSAGE_LEN);
  localparam integer RELEASE_W = (RELEASE_TICKS <= 1) ? 1 : $clog2(RELEASE_TICKS);
  localparam [DELTA_COUNTER_BITS-1:0] DELTA_MAX = {DELTA_COUNTER_BITS{1'b1}};

  reg        capture_next_d;
  reg        capture_armed;
  reg [RELEASE_W-1:0] release_count;
  reg [DELTA_COUNTER_BITS-1:0] delta_counter;
  reg [7:0]  step_counter;
  reg [7:0]  snap_step;
  reg [4:0]  snap_target_slot;
  reg [DELTA_COUNTER_BITS-1:0] snap_delta;
  reg [2:0]  snap_pattern;
  reg [3:0]  snap_offset;
  reg [7:0]  snap_mask;
  reg [3:0]  snap_raw_col_drive;
  reg [7:0]  snap_raw;
  reg [3:0]  snap_raw_rows;
  reg [3:0]  snap_row;
  reg [3:0]  snap_col;
  reg        snap_any;
  reg        sending;
  reg [MESSAGE_W-1:0] byte_index;
  reg [7:0]  tx_data;
  reg        tx_valid;

  wire capture_pressed = capture_armed && capture_next_d && !i_capture_next_n;
  wire tx_ready;
  wire tx_busy;

  function [7:0] hex_ascii;
    input [3:0] nibble;
    begin
      hex_ascii = (nibble < 4'd10) ? (8'h30 + nibble) : (8'h41 + nibble - 4'd10);
    end
  endfunction

  function [7:0] target_label;
    input [4:0] slot;
    begin
      case (slot)
        5'd0:  target_label = "I";
        5'd1:  target_label = "1";
        5'd2:  target_label = "2";
        5'd3:  target_label = "3";
        5'd4:  target_label = "A";
        5'd5:  target_label = "4";
        5'd6:  target_label = "5";
        5'd7:  target_label = "6";
        5'd8:  target_label = "B";
        5'd9:  target_label = "7";
        5'd10: target_label = "8";
        5'd11: target_label = "9";
        5'd12: target_label = "C";
        5'd13: target_label = "0";
        5'd14: target_label = "F";
        5'd15: target_label = "E";
        5'd16: target_label = "D";
        default: target_label = "?";
      endcase
    end
  endfunction

  function [7:0] message_byte;
    input [MESSAGE_W-1:0] index;
    begin
      case (index)
        0:  message_byte = "S";
        1:  message_byte = hex_ascii(snap_step[7:4]);
        2:  message_byte = hex_ascii(snap_step[3:0]);
        3:  message_byte = " ";
        4:  message_byte = "G";
        5:  message_byte = hex_ascii({3'b000, snap_target_slot[4]});
        6:  message_byte = hex_ascii(snap_target_slot[3:0]);
        7:  message_byte = " ";
        8:  message_byte = "K";
        9:  message_byte = target_label(snap_target_slot);
        10: message_byte = " ";
        11: message_byte = "P";
        12: message_byte = hex_ascii({1'b0, snap_pattern});
        13: message_byte = " ";
        14: message_byte = "R";
        15: message_byte = hex_ascii(snap_offset);
        16: message_byte = " ";
        17: message_byte = "M";
        18: message_byte = hex_ascii(snap_mask[7:4]);
        19: message_byte = hex_ascii(snap_mask[3:0]);
        20: message_byte = " ";
        21: message_byte = "D";
        22: message_byte = hex_ascii(snap_raw_col_drive);
        23: message_byte = " ";
        24: message_byte = "W";
        25: message_byte = hex_ascii(snap_raw[7:4]);
        26: message_byte = hex_ascii(snap_raw[3:0]);
        27: message_byte = " ";
        28: message_byte = "Q";
        29: message_byte = hex_ascii(snap_raw_rows);
        30: message_byte = " ";
        31: message_byte = "Y";
        32: message_byte = hex_ascii(snap_row);
        33: message_byte = " ";
        34: message_byte = "C";
        35: message_byte = hex_ascii(snap_col);
        36: message_byte = " ";
        37: message_byte = "A";
        38: message_byte = snap_any ? "1" : "0";
        39: message_byte = " ";
        40: message_byte = "T";
        41: message_byte = hex_ascii({1'b0, snap_delta[24]});
        42: message_byte = hex_ascii(snap_delta[23:20]);
        43: message_byte = hex_ascii(snap_delta[19:16]);
        44: message_byte = hex_ascii(snap_delta[15:12]);
        45: message_byte = hex_ascii(snap_delta[11:8]);
        46: message_byte = hex_ascii(snap_delta[7:4]);
        47: message_byte = hex_ascii(snap_delta[3:0]);
        default: message_byte = 8'h0A;
      endcase
    end
  endfunction

  always @(posedge i_clk) begin
    if (i_reset) begin
      capture_next_d <= 1'b1;
      capture_armed  <= 1'b1;
      release_count  <= {RELEASE_W{1'b0}};
      delta_counter  <= {DELTA_COUNTER_BITS{1'b0}};
      step_counter   <= 8'h00;
      snap_step      <= 8'h00;
      snap_target_slot <= 5'd0;
      snap_delta     <= {DELTA_COUNTER_BITS{1'b0}};
      snap_pattern   <= 3'd0;
      snap_offset    <= 4'd0;
      snap_mask      <= 8'h00;
      snap_raw_col_drive <= 4'h0;
      snap_raw       <= 8'h00;
      snap_raw_rows  <= 4'h0;
      snap_row       <= 4'hF;
      snap_col       <= 4'hF;
      snap_any       <= 1'b0;
      sending        <= 1'b0;
      byte_index     <= {MESSAGE_W{1'b0}};
      tx_data        <= 8'h00;
      tx_valid       <= 1'b0;
    end else begin
      capture_next_d <= i_capture_next_n;

      if (delta_counter != DELTA_MAX) begin
        delta_counter <= delta_counter + {{(DELTA_COUNTER_BITS-1){1'b0}}, 1'b1};
      end

      if (!i_capture_next_n) begin
        capture_armed <= 1'b0;
        release_count <= {RELEASE_W{1'b0}};
      end else if (!capture_armed) begin
        if (release_count == RELEASE_TICKS - 1) begin
          capture_armed <= 1'b1;
        end else begin
          release_count <= release_count + {{(RELEASE_W-1){1'b0}}, 1'b1};
        end
      end

      if (tx_valid && !tx_ready) begin
        tx_valid <= tx_valid;
      end else begin
        tx_valid <= 1'b0;
      end

      if (!sending) begin
        if (capture_pressed && !tx_busy && !tx_valid) begin
          snap_step    <= step_counter;
          snap_target_slot <= i_target_slot;
          snap_delta   <= delta_counter;
          snap_pattern <= i_pattern_index;
          snap_offset  <= i_col_offset;
          snap_mask    <= i_mask;
          snap_raw_col_drive <= i_raw_col_drive;
          snap_raw     <= i_raw_pmod;
          snap_raw_rows <= i_raw_rows;
          snap_row     <= i_row_bits;
          snap_col     <= i_col_bits;
          snap_any     <= i_any_active;
          delta_counter <= {DELTA_COUNTER_BITS{1'b0}};
          step_counter <= step_counter + 8'h01;
          sending      <= 1'b1;
          byte_index   <= {MESSAGE_W{1'b0}};
        end
      end else if (!tx_valid && tx_ready) begin
        tx_data  <= message_byte(byte_index);
        tx_valid <= 1'b1;
        if (byte_index == MESSAGE_LEN - 1) begin
          sending    <= 1'b0;
          byte_index <= {MESSAGE_W{1'b0}};
        end else begin
          byte_index <= byte_index + {{(MESSAGE_W-1){1'b0}}, 1'b1};
        end
      end
    end
  end

  uart_tx #(
    .CLK_HZ(CLK_HZ),
    .BAUD_RATE(BAUD_RATE)
  ) u_uart_tx (
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_data(tx_data),
    .i_valid(tx_valid),
    .o_ready(tx_ready),
    .o_busy(tx_busy),
    .o_tx(o_uart_tx)
  );

endmodule
