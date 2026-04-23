module tang_primer_uart_debug_dump #(
  parameter integer CLK_HZ = 74250000,
  parameter integer BAUD_RATE = 115200,
  parameter integer H_RESOLUTION = 1280,
  parameter integer V_RESOLUTION = 720,
  parameter integer RELEASE_TICKS = CLK_HZ / 20
)(
  input  wire        i_clk,
  input  wire        i_reset,
  input  wire        i_dump_next_n,
  input  wire        i_dump_uart_request,
  input  wire [7:0]  i_debug_last_rx_byte,
  input  wire [7:0]  i_debug_last_cmd_byte,
  input  wire        i_debug_last_cmd_hit,
  input  wire [7:0]  i_debug_last_shape_source,
  input  wire [15:0] i_debug_last_shape_word,
  input  wire [3:0]  i_debug_glyph_bit_base,
  input  wire [7:0]  i_debug_cursor_x_offset,
  input  wire        i_demo_enable,
  input  wire        i_cursor_visible,
  input  wire        i_cursor_blink_enable,
  input  wire [15:0] i_cursor_blink_period,
  input  wire [15:0] i_attr_blink_period,
  input  wire [6:0]  i_cursor_col,
  input  wire [4:0]  i_cursor_row,
  input  wire        i_cursor_vertical,
  input  wire [1:0]  i_cursor_mode,
  input  wire [2:0]  i_cursor_template,
  input  wire        i_shadow_dirty,
  input  wire [15:0] i_frame_counter,
  input  wire [15:0] i_cursor_cell,
  output wire        o_uart_tx
);

  localparam integer MESSAGE_LEN = 118;
  localparam integer MESSAGE_W = (MESSAGE_LEN <= 1) ? 1 : $clog2(MESSAGE_LEN);
  localparam integer RELEASE_W = (RELEASE_TICKS <= 1) ? 1 : $clog2(RELEASE_TICKS);
  localparam [15:0] H_RES_U16 = H_RESOLUTION;
  localparam [15:0] V_RES_U16 = V_RESOLUTION;

  reg        dump_next_d;
  reg        dump_armed;
  reg [RELEASE_W-1:0] release_count;
  reg        sending;
  reg [MESSAGE_W-1:0] byte_index;
  reg [7:0]  tx_data;
  reg        tx_valid;

  reg        snap_demo_enable;
  reg        snap_cursor_visible;
  reg        snap_cursor_blink_enable;
  reg [15:0] snap_cursor_blink_period;
  reg [15:0] snap_attr_blink_period;
  reg [6:0]  snap_cursor_col;
  reg [4:0]  snap_cursor_row;
  reg        snap_cursor_vertical;
  reg [1:0]  snap_cursor_mode;
  reg [2:0]  snap_cursor_template;
  reg        snap_shadow_dirty;
  reg [15:0] snap_frame_counter;
  reg [15:0] snap_cursor_cell;
  reg [7:0]  snap_last_rx_byte;
  reg [7:0]  snap_last_cmd_byte;
  reg        snap_last_cmd_hit;
  reg [7:0]  snap_last_shape_source;
  reg [15:0] snap_last_shape_word;
  reg [3:0]  snap_glyph_bit_base;
  reg [7:0]  snap_cursor_x_offset;

  wire dump_pressed = dump_armed && dump_next_d && !i_dump_next_n;
  wire dump_request = dump_pressed || i_dump_uart_request;
  wire tx_ready;
  wire tx_busy;

  function [7:0] hex_ascii;
    input [3:0] nibble;
    begin
      hex_ascii = (nibble < 4'd10) ? (8'h30 + nibble) : (8'h41 + nibble - 4'd10);
    end
  endfunction

  function [7:0] message_byte;
    input [MESSAGE_W-1:0] index;
    begin
      case (index)
        0:  message_byte = "D";
        1:  message_byte = "B";
        2:  message_byte = "G";
        3:  message_byte = " ";
        4:  message_byte = "D";
        5:  message_byte = snap_demo_enable ? "1" : "0";
        6:  message_byte = " ";
        7:  message_byte = "X";
        8:  message_byte = hex_ascii({1'b0, snap_cursor_col[6:4]});
        9:  message_byte = hex_ascii(snap_cursor_col[3:0]);
        10: message_byte = " ";
        11: message_byte = "Y";
        12: message_byte = hex_ascii({3'b000, snap_cursor_row[4]});
        13: message_byte = hex_ascii(snap_cursor_row[3:0]);
        14: message_byte = " ";
        15: message_byte = "T";
        16: message_byte = hex_ascii({1'b0, snap_cursor_template});
        17: message_byte = " ";
        18: message_byte = "V";
        19: message_byte = snap_cursor_vertical ? "1" : "0";
        20: message_byte = " ";
        21: message_byte = "M";
        22: message_byte = hex_ascii({2'b00, snap_cursor_mode});
        23: message_byte = " ";
        24: message_byte = "C";
        25: message_byte = snap_cursor_visible ? "1" : "0";
        26: message_byte = " ";
        27: message_byte = "B";
        28: message_byte = snap_cursor_blink_enable ? "1" : "0";
        29: message_byte = " ";
        30: message_byte = "P";
        31: message_byte = hex_ascii(snap_cursor_blink_period[15:12]);
        32: message_byte = hex_ascii(snap_cursor_blink_period[11:8]);
        33: message_byte = hex_ascii(snap_cursor_blink_period[7:4]);
        34: message_byte = hex_ascii(snap_cursor_blink_period[3:0]);
        35: message_byte = " ";
        36: message_byte = "A";
        37: message_byte = hex_ascii(snap_attr_blink_period[15:12]);
        38: message_byte = hex_ascii(snap_attr_blink_period[11:8]);
        39: message_byte = hex_ascii(snap_attr_blink_period[7:4]);
        40: message_byte = hex_ascii(snap_attr_blink_period[3:0]);
        41: message_byte = " ";
        42: message_byte = "G";
        43: message_byte = hex_ascii(snap_cursor_cell[7:4]);
        44: message_byte = hex_ascii(snap_cursor_cell[3:0]);
        45: message_byte = " ";
        46: message_byte = "U";
        47: message_byte = hex_ascii(snap_cursor_cell[15:12]);
        48: message_byte = hex_ascii(snap_cursor_cell[11:8]);
        49: message_byte = " ";
        50: message_byte = "F";
        51: message_byte = hex_ascii(snap_cursor_cell[11:8] & 4'hF);
        52: message_byte = " ";
        53: message_byte = "N";
        54: message_byte = hex_ascii({1'b0, snap_cursor_cell[14:12]});
        55: message_byte = " ";
        56: message_byte = "L";
        57: message_byte = snap_cursor_cell[15] ? "1" : "0";
        58: message_byte = " ";
        59: message_byte = "W";
        60: message_byte = hex_ascii(H_RES_U16[15:12]);
        61: message_byte = hex_ascii(H_RES_U16[11:8]);
        62: message_byte = hex_ascii(H_RES_U16[7:4]);
        63: message_byte = hex_ascii(H_RES_U16[3:0]);
        64: message_byte = " ";
        65: message_byte = "H";
        66: message_byte = hex_ascii(V_RES_U16[15:12]);
        67: message_byte = hex_ascii(V_RES_U16[11:8]);
        68: message_byte = hex_ascii(V_RES_U16[7:4]);
        69: message_byte = hex_ascii(V_RES_U16[3:0]);
        70: message_byte = " ";
        71: message_byte = "S";
        72: message_byte = snap_shadow_dirty ? "1" : "0";
        73: message_byte = " ";
        74: message_byte = "K";
        75: message_byte = hex_ascii(snap_frame_counter[15:12]);
        76: message_byte = hex_ascii(snap_frame_counter[11:8]);
        77: message_byte = hex_ascii(snap_frame_counter[7:4]);
        78: message_byte = hex_ascii(snap_frame_counter[3:0]);
        79: message_byte = " ";
        80: message_byte = "R";
        81: message_byte = hex_ascii(snap_last_rx_byte[7:4]);
        82: message_byte = hex_ascii(snap_last_rx_byte[3:0]);
        83: message_byte = " ";
        84: message_byte = "Q";
        85: message_byte = hex_ascii(snap_last_cmd_byte[7:4]);
        86: message_byte = hex_ascii(snap_last_cmd_byte[3:0]);
        87: message_byte = " ";
        88: message_byte = "J";
        89: message_byte = snap_last_cmd_hit ? "1" : "0";
        90: message_byte = " ";
        91: message_byte = "Z";
        92: message_byte = (snap_last_shape_source == 8'h00) ? "." : snap_last_shape_source;
        93: message_byte = " ";
        94: message_byte = "O";
        95: message_byte = hex_ascii(snap_last_shape_word[15:12]);
        96: message_byte = hex_ascii(snap_last_shape_word[11:8]);
        97: message_byte = hex_ascii(snap_last_shape_word[7:4]);
        98: message_byte = hex_ascii(snap_last_shape_word[3:0]);
        99: message_byte = " ";
        100: message_byte = "T";
        101: message_byte = hex_ascii({1'b0, snap_last_shape_word[6:4]});
        102: message_byte = " ";
        103: message_byte = "V";
        104: message_byte = snap_last_shape_word[2] ? "1" : "0";
        105: message_byte = " ";
        106: message_byte = "M";
        107: message_byte = hex_ascii({2'b00, snap_last_shape_word[1:0]});
        108: message_byte = " ";
        109: message_byte = "G";
        110: message_byte = "B";
        111: message_byte = hex_ascii(snap_glyph_bit_base);
        112: message_byte = " ";
        113: message_byte = "X";
        114: message_byte = "O";
        115: message_byte = hex_ascii(snap_cursor_x_offset[7:4]);
        116: message_byte = hex_ascii(snap_cursor_x_offset[3:0]);
        default: message_byte = 8'h0A;
      endcase
    end
  endfunction

  always @(posedge i_clk) begin
    if (i_reset) begin
      dump_next_d <= 1'b1;
      dump_armed <= 1'b1;
      release_count <= {RELEASE_W{1'b0}};
      sending <= 1'b0;
      byte_index <= {MESSAGE_W{1'b0}};
      tx_data <= 8'h00;
      tx_valid <= 1'b0;
      snap_demo_enable <= 1'b0;
      snap_cursor_visible <= 1'b1;
      snap_cursor_blink_enable <= 1'b1;
      snap_cursor_blink_period <= 16'd32;
      snap_attr_blink_period <= 16'd64;
      snap_cursor_col <= 7'd0;
      snap_cursor_row <= 5'd0;
      snap_cursor_vertical <= 1'b0;
      snap_cursor_mode <= 2'd0;
      snap_cursor_template <= 3'd4;
      snap_shadow_dirty <= 1'b0;
      snap_frame_counter <= 16'd0;
      snap_cursor_cell <= 16'h0720;
      snap_last_rx_byte <= 8'h00;
      snap_last_cmd_byte <= 8'h00;
      snap_last_cmd_hit <= 1'b0;
      snap_last_shape_source <= 8'h00;
      snap_last_shape_word <= 16'h0000;
      snap_glyph_bit_base <= 4'd0;
      snap_cursor_x_offset <= 8'h00;
    end else begin
      dump_next_d <= i_dump_next_n;

      if (!i_dump_next_n) begin
        dump_armed <= 1'b0;
        release_count <= {RELEASE_W{1'b0}};
      end else if (!dump_armed) begin
        if (release_count == RELEASE_TICKS - 1) begin
          dump_armed <= 1'b1;
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
        if (dump_request && !tx_busy && !tx_valid) begin
          snap_demo_enable <= i_demo_enable;
          snap_cursor_visible <= i_cursor_visible;
          snap_cursor_blink_enable <= i_cursor_blink_enable;
          snap_cursor_blink_period <= i_cursor_blink_period;
          snap_attr_blink_period <= i_attr_blink_period;
          snap_cursor_col <= i_cursor_col;
          snap_cursor_row <= i_cursor_row;
          snap_cursor_vertical <= i_cursor_vertical;
          snap_cursor_mode <= i_cursor_mode;
          snap_cursor_template <= i_cursor_template;
          snap_shadow_dirty <= i_shadow_dirty;
          snap_frame_counter <= i_frame_counter;
          snap_cursor_cell <= i_cursor_cell;
          snap_last_rx_byte <= i_debug_last_rx_byte;
          snap_last_cmd_byte <= i_debug_last_cmd_byte;
          snap_last_cmd_hit <= i_debug_last_cmd_hit;
          snap_last_shape_source <= i_debug_last_shape_source;
          snap_last_shape_word <= i_debug_last_shape_word;
          snap_glyph_bit_base <= i_debug_glyph_bit_base;
          snap_cursor_x_offset <= i_debug_cursor_x_offset;
          sending <= 1'b1;
          byte_index <= {MESSAGE_W{1'b0}};
        end
      end else if (!tx_valid && tx_ready) begin
        tx_data <= message_byte(byte_index);
        tx_valid <= 1'b1;
        if (byte_index == MESSAGE_LEN - 1) begin
          sending <= 1'b0;
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
