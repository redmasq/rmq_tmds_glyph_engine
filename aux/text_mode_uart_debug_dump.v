module text_mode_uart_debug_dump #(
  parameter integer CLK_HZ = 74250000,
  parameter integer BAUD_RATE = 115200,
  parameter integer H_RESOLUTION = 1280,
  parameter integer V_RESOLUTION = 720,
  parameter integer EXTRA_BUF_LEN = 32
)(
  input  wire        i_clk,
  input  wire        i_reset,
  input  wire        i_dump_request,
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
  input  wire        i_extra_wr_en,
  input  wire [5:0]  i_extra_wr_addr,
  input  wire [7:0]  i_extra_wr_data,
  input  wire [5:0]  i_extra_len,
  output wire        o_uart_tx
);

  localparam integer BASE_MESSAGE_LEN = 117;
  localparam integer MAX_MESSAGE_LEN = BASE_MESSAGE_LEN + 1 + ((EXTRA_BUF_LEN > 0) ? (EXTRA_BUF_LEN + 1) : 0);
  localparam integer MESSAGE_W = (MAX_MESSAGE_LEN <= 1) ? 1 : $clog2(MAX_MESSAGE_LEN);
  localparam [15:0] H_RES_U16 = H_RESOLUTION[15:0];
  localparam [15:0] V_RES_U16 = V_RESOLUTION[15:0];
  localparam [5:0] EXTRA_BUF_LEN_U6 = EXTRA_BUF_LEN[5:0];

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
  reg [5:0]  snap_extra_len;
  reg [7:0]  extra_buffer [0:EXTRA_BUF_LEN-1];

  reg [7:0] next_message_byte;

  wire tx_ready;
  wire tx_busy;
  wire [MESSAGE_W-1:0] message_len = BASE_MESSAGE_LEN +
                                     ((snap_extra_len != 0) ? ({{(MESSAGE_W-6){1'b0}}, snap_extra_len} + {{(MESSAGE_W-1){1'b0}}, 1'b1}) : {MESSAGE_W{1'b0}}) +
                                     {{(MESSAGE_W-1){1'b0}}, 1'b1};

  function [7:0] hex_ascii;
    input [3:0] nibble;
    begin
      hex_ascii = (nibble < 4'd10) ? (8'h30 + nibble) : (8'h41 + nibble - 4'd10);
    end
  endfunction

  function [7:0] core_message_byte;
    input [6:0] index;
    begin
      case (index)
        0:  core_message_byte = "D";
        1:  core_message_byte = "B";
        2:  core_message_byte = "G";
        3:  core_message_byte = " ";
        4:  core_message_byte = "D";
        5:  core_message_byte = snap_demo_enable ? "1" : "0";
        6:  core_message_byte = " ";
        7:  core_message_byte = "X";
        8:  core_message_byte = hex_ascii({1'b0, snap_cursor_col[6:4]});
        9:  core_message_byte = hex_ascii(snap_cursor_col[3:0]);
        10: core_message_byte = " ";
        11: core_message_byte = "Y";
        12: core_message_byte = hex_ascii({3'b000, snap_cursor_row[4]});
        13: core_message_byte = hex_ascii(snap_cursor_row[3:0]);
        14: core_message_byte = " ";
        15: core_message_byte = "T";
        16: core_message_byte = hex_ascii({1'b0, snap_cursor_template});
        17: core_message_byte = " ";
        18: core_message_byte = "V";
        19: core_message_byte = snap_cursor_vertical ? "1" : "0";
        20: core_message_byte = " ";
        21: core_message_byte = "M";
        22: core_message_byte = hex_ascii({2'b00, snap_cursor_mode});
        23: core_message_byte = " ";
        24: core_message_byte = "C";
        25: core_message_byte = snap_cursor_visible ? "1" : "0";
        26: core_message_byte = " ";
        27: core_message_byte = "B";
        28: core_message_byte = snap_cursor_blink_enable ? "1" : "0";
        29: core_message_byte = " ";
        30: core_message_byte = "P";
        31: core_message_byte = hex_ascii(snap_cursor_blink_period[15:12]);
        32: core_message_byte = hex_ascii(snap_cursor_blink_period[11:8]);
        33: core_message_byte = hex_ascii(snap_cursor_blink_period[7:4]);
        34: core_message_byte = hex_ascii(snap_cursor_blink_period[3:0]);
        35: core_message_byte = " ";
        36: core_message_byte = "A";
        37: core_message_byte = hex_ascii(snap_attr_blink_period[15:12]);
        38: core_message_byte = hex_ascii(snap_attr_blink_period[11:8]);
        39: core_message_byte = hex_ascii(snap_attr_blink_period[7:4]);
        40: core_message_byte = hex_ascii(snap_attr_blink_period[3:0]);
        41: core_message_byte = " ";
        42: core_message_byte = "G";
        43: core_message_byte = hex_ascii(snap_cursor_cell[7:4]);
        44: core_message_byte = hex_ascii(snap_cursor_cell[3:0]);
        45: core_message_byte = " ";
        46: core_message_byte = "U";
        47: core_message_byte = hex_ascii(snap_cursor_cell[15:12]);
        48: core_message_byte = hex_ascii(snap_cursor_cell[11:8]);
        49: core_message_byte = " ";
        50: core_message_byte = "F";
        51: core_message_byte = hex_ascii(snap_cursor_cell[11:8] & 4'hF);
        52: core_message_byte = " ";
        53: core_message_byte = "N";
        54: core_message_byte = hex_ascii({1'b0, snap_cursor_cell[14:12]});
        55: core_message_byte = " ";
        56: core_message_byte = "L";
        57: core_message_byte = snap_cursor_cell[15] ? "1" : "0";
        58: core_message_byte = " ";
        59: core_message_byte = "W";
        60: core_message_byte = hex_ascii(H_RES_U16[15:12]);
        61: core_message_byte = hex_ascii(H_RES_U16[11:8]);
        62: core_message_byte = hex_ascii(H_RES_U16[7:4]);
        63: core_message_byte = hex_ascii(H_RES_U16[3:0]);
        64: core_message_byte = " ";
        65: core_message_byte = "H";
        66: core_message_byte = hex_ascii(V_RES_U16[15:12]);
        67: core_message_byte = hex_ascii(V_RES_U16[11:8]);
        68: core_message_byte = hex_ascii(V_RES_U16[7:4]);
        69: core_message_byte = hex_ascii(V_RES_U16[3:0]);
        70: core_message_byte = " ";
        71: core_message_byte = "S";
        72: core_message_byte = snap_shadow_dirty ? "1" : "0";
        73: core_message_byte = " ";
        74: core_message_byte = "K";
        75: core_message_byte = hex_ascii(snap_frame_counter[15:12]);
        76: core_message_byte = hex_ascii(snap_frame_counter[11:8]);
        77: core_message_byte = hex_ascii(snap_frame_counter[7:4]);
        78: core_message_byte = hex_ascii(snap_frame_counter[3:0]);
        79: core_message_byte = " ";
        80: core_message_byte = "R";
        81: core_message_byte = hex_ascii(snap_last_rx_byte[7:4]);
        82: core_message_byte = hex_ascii(snap_last_rx_byte[3:0]);
        83: core_message_byte = " ";
        84: core_message_byte = "Q";
        85: core_message_byte = hex_ascii(snap_last_cmd_byte[7:4]);
        86: core_message_byte = hex_ascii(snap_last_cmd_byte[3:0]);
        87: core_message_byte = " ";
        88: core_message_byte = "J";
        89: core_message_byte = snap_last_cmd_hit ? "1" : "0";
        90: core_message_byte = " ";
        91: core_message_byte = "Z";
        92: core_message_byte = (snap_last_shape_source == 8'h00) ? "." : snap_last_shape_source;
        93: core_message_byte = " ";
        94: core_message_byte = "O";
        95: core_message_byte = hex_ascii(snap_last_shape_word[15:12]);
        96: core_message_byte = hex_ascii(snap_last_shape_word[11:8]);
        97: core_message_byte = hex_ascii(snap_last_shape_word[7:4]);
        98: core_message_byte = hex_ascii(snap_last_shape_word[3:0]);
        99: core_message_byte = " ";
        100: core_message_byte = "T";
        101: core_message_byte = hex_ascii({1'b0, snap_last_shape_word[6:4]});
        102: core_message_byte = " ";
        103: core_message_byte = "V";
        104: core_message_byte = snap_last_shape_word[2] ? "1" : "0";
        105: core_message_byte = " ";
        106: core_message_byte = "M";
        107: core_message_byte = hex_ascii({2'b00, snap_last_shape_word[1:0]});
        108: core_message_byte = " ";
        109: core_message_byte = "G";
        110: core_message_byte = "B";
        111: core_message_byte = hex_ascii(snap_glyph_bit_base);
        112: core_message_byte = " ";
        113: core_message_byte = "X";
        114: core_message_byte = "O";
        115: core_message_byte = hex_ascii(snap_cursor_x_offset[7:4]);
        116: core_message_byte = hex_ascii(snap_cursor_x_offset[3:0]);
        default: core_message_byte = 8'h0A;
      endcase
    end
  endfunction

  integer extra_idx;
  always @* begin
    extra_idx = 0;
    next_message_byte = 8'h0A;
    if (byte_index < BASE_MESSAGE_LEN) begin
      next_message_byte = core_message_byte(byte_index[6:0]);
    end else if (snap_extra_len != 0) begin
      if (byte_index == BASE_MESSAGE_LEN) begin
        next_message_byte = " ";
      end else if (byte_index < BASE_MESSAGE_LEN + 1 + snap_extra_len) begin
        extra_idx = byte_index - BASE_MESSAGE_LEN - 1;
        next_message_byte = extra_buffer[extra_idx];
      end
    end
  end

  always @(posedge i_clk) begin
    if (i_reset) begin
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
      snap_extra_len <= 6'd0;
    end else begin
      if (i_extra_wr_en && (i_extra_wr_addr < EXTRA_BUF_LEN_U6)) begin
        extra_buffer[i_extra_wr_addr] <= i_extra_wr_data;
      end

      if (tx_valid && !tx_ready) begin
        tx_valid <= tx_valid;
      end else begin
        tx_valid <= 1'b0;
      end

      if (!sending) begin
        if (i_dump_request && !tx_busy && !tx_valid) begin
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
          snap_extra_len <= (i_extra_len > EXTRA_BUF_LEN_U6) ? EXTRA_BUF_LEN_U6 : i_extra_len;
          sending <= 1'b1;
          byte_index <= {MESSAGE_W{1'b0}};
        end
      end else if (!tx_valid && tx_ready) begin
        tx_data <= next_message_byte;
        tx_valid <= 1'b1;
        if (byte_index == message_len - 1) begin
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
