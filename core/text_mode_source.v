module text_mode_source #(
  parameter H_RESOLUTION = 720,
  parameter V_RESOLUTION = 480,
  parameter TEXT_COLS    = 80,
  parameter TEXT_ROWS    = 25,
  parameter GLYPH_W      = 8,
  parameter GLYPH_H      = 16,
  parameter GLYPH_BIT_BASE = 7
)(
  input  wire               i_clk,
  input  wire               i_reset,
  input  wire               i_disp_enable,
  input  wire signed [12:0] i_x,
  input  wire signed [12:0] i_y,
  input  wire               i_attr_blink_visible,
  input  wire               i_debug_any_active,
  input  wire [3:0]         i_debug_row_bits,
  input  wire [3:0]         i_debug_col_bits,
  input  wire [3:0]         i_debug_row_valid,
  input  wire [3:0]         i_debug_col_valid,
  input  wire [7:0]         i_debug_pmod_bits,
  input  wire [7:0]         i_debug_pmod_col_mask,
  input  wire [4:0]         i_debug_target_slot,
  input  wire               i_cursor_visible,
  input  wire [6:0]         i_cursor_col,
  input  wire [4:0]         i_cursor_row,
  input  wire               i_cursor_vertical,
  input  wire [1:0]         i_cursor_mode,
  input  wire [2:0]         i_cursor_template,

  output reg  [10:0]        o_cell_rd_addr,
  input  wire [15:0]        i_cell_rd_data,

  output wire [23:0]        o_rgb
);

  localparam WINDOW_W = TEXT_COLS * GLYPH_W;
  localparam WINDOW_H = TEXT_ROWS * GLYPH_H;
  localparam X0       = (H_RESOLUTION - WINDOW_W) / 2;
  localparam Y0       = (V_RESOLUTION - WINDOW_H) / 2;
  localparam [10:0] TEXT_COLS_ADDR = TEXT_COLS;
  // Keep the temporary keypad probe compact enough to fit entirely inside the
  // 480p border, which is only 40 pixels thick around the centered text area.
  localparam integer DEBUG_INDICATOR_W = 4;
  localparam integer DEBUG_INDICATOR_H = 4;
  localparam integer DEBUG_CELL_W = 6;
  localparam integer DEBUG_CELL_H = 6;
  localparam integer DEBUG_GAP = 2;
  localparam integer DEBUG_PANEL_X0 = 1;
  localparam integer DEBUG_PANEL_Y0 = 1;
  localparam integer DEBUG_GRID_X0 =
    DEBUG_PANEL_X0 + DEBUG_INDICATOR_W + DEBUG_GAP;
  localparam integer DEBUG_GRID_Y0 =
    DEBUG_PANEL_Y0 + DEBUG_INDICATOR_H + DEBUG_GAP;
  localparam integer DEBUG_RAW_PANEL_X0 =
    DEBUG_GRID_X0 + (4 * DEBUG_CELL_W) + (4 * DEBUG_GAP) + 4;
  localparam integer DEBUG_RAW_VALUE_Y0 = DEBUG_PANEL_Y0;
  localparam integer DEBUG_RAW_MASK_Y0 =
    DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H + DEBUG_GAP;
  localparam [23:0] BORDER_RGB = 24'h0055AA;
  localparam [23:0] DEBUG_ACTIVE_BORDER_RGB = 24'hCC3300;
  localparam [23:0] DEBUG_HIGH_RGB = 24'h00AA44;
  localparam [23:0] DEBUG_LOW_RGB = 24'hAA1010;
  localparam [23:0] DEBUG_DISABLED_RGB = 24'h404040;
  localparam [23:0] DEBUG_CELL_ACTIVE_RGB = 24'hFFD000;
  localparam [23:0] DEBUG_CELL_IDLE_RGB = 24'h203860;
  localparam [23:0] DEBUG_RAW_MASK_LOW_RGB = 24'hFFD000;
  localparam [23:0] DEBUG_RAW_MASK_HIGH_RGB = 24'h00FF44;
  localparam [23:0] DEBUG_RAW_READ_LOW_RGB = 24'h808080;
  localparam [23:0] DEBUG_RAW_READ_HIGH_RGB = 24'h0044CC;
  localparam [23:0] DEBUG_RAW_MASK_ON_RGB = 24'hFFFFFF;
  localparam [23:0] DEBUG_RAW_MASK_OFF_RGB = 24'h000000;
  // --------------------------------------------------------------------------
  // Stage 0: derive cell coordinates and issue BRAM read
  // --------------------------------------------------------------------------

  wire inside_now =
    i_disp_enable &&
    (i_x >= X0) && (i_x < (X0 + WINDOW_W)) &&
    (i_y >= Y0) && (i_y < (Y0 + WINDOW_H));

  wire [12:0] rel_x = i_x - X0;
  wire [12:0] rel_y = i_y - Y0;

  wire [6:0] char_col_now   = rel_x[9:3];
  wire [4:0] char_row_now   = rel_y[8:4];
  wire [2:0] glyph_x_now    = rel_x[2:0];
  wire [3:0] glyph_y_now    = rel_y[3:0];
  wire [10:0] char_index_now = ({6'd0, char_row_now} * TEXT_COLS_ADDR) + {4'd0, char_col_now};

  // Save request-side metadata so it lines up with BRAM response next cycle.
  reg        s0_inside;
  reg        s0_disp_enable;
  reg [12:0] s0_x_u;
  reg [12:0] s0_y_u;
  reg [6:0]  s0_char_col;
  reg [4:0]  s0_char_row;
  reg [2:0]  s0_glyph_x;
  reg [3:0]  s0_glyph_y;

  // --------------------------------------------------------------------------
  // Stage 1: BRAM response is valid; capture char/attr and launch font read
  // --------------------------------------------------------------------------

  reg        s1_inside;
  reg        s1_disp_enable;
  reg [12:0] s1_x_u;
  reg [12:0] s1_y_u;
  reg [6:0]  s1_char_col;
  reg [4:0]  s1_char_row;
  reg [2:0]  s1_glyph_x;
  reg [3:0]  s1_glyph_y;
  reg [7:0]  s1_char_code;
  reg [7:0]  s1_attr;

  reg [7:0] font_char_code_r;
  reg [3:0] font_row_r;
  wire [7:0] font_bits;

  // --------------------------------------------------------------------------
  // Stage 2: font row response is valid; select pixel
  // --------------------------------------------------------------------------

  reg        s2_inside;
  reg        s2_disp_enable;
  reg [12:0] s2_x_u;
  reg [12:0] s2_y_u;
  reg [6:0]  s2_char_col;
  reg [4:0]  s2_char_row;
  reg [2:0]  s2_glyph_x;
  reg [3:0]  s2_glyph_y;
  reg        s2_attr_blink;
  reg [3:0]  s2_fg_index;
  reg [3:0]  s2_bg_index;

  cp437_font_rom u_font (
    .clk      (i_clk),
    .char_code(font_char_code_r),
    .row      (font_row_r),
    .bits     (font_bits)
  );

  wire [23:0] fg_rgb;
  wire [23:0] bg_rgb;

  vga16_palette u_fg_pal (
    .index(s2_fg_index),
    .rgb  (fg_rgb)
  );

  vga16_palette u_bg_pal (
    .index(s2_bg_index),
    .rgb  (bg_rgb)
  );

  always @(posedge i_clk) begin
    if (i_reset) begin
      o_cell_rd_addr   <= 11'd0;

      s0_inside        <= 1'b0;
      s0_disp_enable   <= 1'b0;
      s0_x_u          <= 13'd0;
      s0_y_u          <= 13'd0;
      s0_char_col      <= 7'd0;
      s0_char_row      <= 5'd0;
      s0_glyph_x       <= 3'd0;
      s0_glyph_y       <= 4'd0;

      s1_inside        <= 1'b0;
      s1_disp_enable   <= 1'b0;
      s1_x_u          <= 13'd0;
      s1_y_u          <= 13'd0;
      s1_char_col      <= 7'd0;
      s1_char_row      <= 5'd0;
      s1_glyph_x       <= 3'd0;
      s1_glyph_y       <= 4'd0;
      s1_char_code     <= 8'h20;
      s1_attr          <= 8'h07;

      font_char_code_r <= 8'h20;
      font_row_r       <= 4'd0;

      s2_inside        <= 1'b0;
      s2_disp_enable   <= 1'b0;
      s2_x_u          <= 13'd0;
      s2_y_u          <= 13'd0;
      s2_char_col      <= 7'd0;
      s2_char_row      <= 5'd0;
      s2_glyph_x       <= 3'd0;
      s2_glyph_y       <= 4'd0;
      s2_attr_blink    <= 1'b0;
      s2_fg_index      <= 4'h7;
      s2_bg_index      <= 4'h0;
    end else begin
      // Stage 0: request BRAM cell for current pixel
      o_cell_rd_addr <= char_index_now;

      s0_inside      <= inside_now;
      s0_disp_enable <= i_disp_enable;
      s0_x_u         <= i_x[12:0];
      s0_y_u         <= i_y[12:0];
      s0_char_col    <= char_col_now;
      s0_char_row    <= char_row_now;
      s0_glyph_x     <= glyph_x_now;
      s0_glyph_y     <= glyph_y_now;

      // Stage 1: BRAM data belongs to prior cycle's request metadata
      s1_inside      <= s0_inside;
      s1_disp_enable <= s0_disp_enable;
      s1_x_u         <= s0_x_u;
      s1_y_u         <= s0_y_u;
      s1_char_col    <= s0_char_col;
      s1_char_row    <= s0_char_row;
      s1_glyph_x     <= s0_glyph_x;
      s1_glyph_y     <= s0_glyph_y;
      s1_char_code   <= debug_target_cell ? debug_target_char(i_debug_target_slot) : i_cell_rd_data[7:0];
      s1_attr        <= debug_target_cell ? 8'h0F : i_cell_rd_data[15:8];

      // Launch font lookup for returned char and saved row
      font_char_code_r <= debug_target_cell ? debug_target_char(i_debug_target_slot) : i_cell_rd_data[7:0];
      font_row_r       <= s0_glyph_y;

      // Stage 2: font bits belong to prior cycle's char/attr/glyph_x
      s2_inside      <= s1_inside;
      s2_disp_enable <= s1_disp_enable;
      s2_x_u         <= s1_x_u;
      s2_y_u         <= s1_y_u;
      s2_char_col    <= s1_char_col;
      s2_char_row    <= s1_char_row;
      s2_glyph_x     <= s1_glyph_x;
      s2_glyph_y     <= s1_glyph_y;
      s2_attr_blink  <= s1_attr[7];
      s2_fg_index    <= s1_attr[3:0];
      s2_bg_index    <= {1'b0, s1_attr[6:4]};
    end
  end

  // Different serializer / memory timing pipelines can need a small
  // board-specific horizontal bit alignment tweak at the final glyph row tap.
  wire glyph_on = font_bits[GLYPH_BIT_BASE - s2_glyph_x];
  wire blinked_glyph_on = glyph_on && (!s2_attr_blink || i_attr_blink_visible);
  wire [23:0] base_rgb = blinked_glyph_on ? fg_rgb : bg_rgb;

  function [7:0] debug_target_char;
    input [4:0] slot;
    begin
      case (slot)
        5'd0:  debug_target_char = "I";
        5'd1:  debug_target_char = "1";
        5'd2:  debug_target_char = "2";
        5'd3:  debug_target_char = "3";
        5'd4:  debug_target_char = "A";
        5'd5:  debug_target_char = "4";
        5'd6:  debug_target_char = "5";
        5'd7:  debug_target_char = "6";
        5'd8:  debug_target_char = "B";
        5'd9:  debug_target_char = "7";
        5'd10: debug_target_char = "8";
        5'd11: debug_target_char = "9";
        5'd12: debug_target_char = "C";
        5'd13: debug_target_char = "0";
        5'd14: debug_target_char = "F";
        5'd15: debug_target_char = "E";
        5'd16: debug_target_char = "D";
        default: debug_target_char = "?";
      endcase
    end
  endfunction

  wire [4:0] cursor_row_span =
    (i_cursor_template == 3'd0) ? 5'd0 : (((GLYPH_H * i_cursor_template) + 6) / 7);
  wire [3:0] cursor_col_span =
    (i_cursor_template == 3'd0) ? 4'd0 : (((GLYPH_W * i_cursor_template) + 6) / 7);
  wire cursor_cell_match =
    s2_inside &&
    i_cursor_visible &&
    (s2_char_col == i_cursor_col) &&
    (s2_char_row == i_cursor_row);
  wire debug_target_cell =
    s0_inside &&
    (s0_char_col == (TEXT_COLS - 2)) &&
    (s0_char_row == (TEXT_ROWS - 2));
  wire cursor_shape_on =
    !i_cursor_vertical ?
      ((cursor_row_span != 5'd0) &&
       ({1'b0, s2_glyph_y} >= (GLYPH_H - cursor_row_span))) :
      ((cursor_col_span != 4'd0) &&
       ({1'b0, s2_glyph_x} >= (GLYPH_W - cursor_col_span)));
  wire cursor_pixel_on = cursor_cell_match && cursor_shape_on;
  wire [23:0] cursor_rgb =
    (i_cursor_mode == 2'd1) ? (base_rgb | fg_rgb) :
    (i_cursor_mode == 2'd2) ? (base_rgb ^ fg_rgb) :
                              fg_rgb;

  wire [23:0] border_rgb = i_debug_any_active ? DEBUG_ACTIVE_BORDER_RGB : BORDER_RGB;
  wire [12:0] x_u = s2_x_u;
  wire [12:0] y_u = s2_y_u;
  wire col0_hit =
    (y_u >= DEBUG_PANEL_Y0) &&
    (y_u < (DEBUG_PANEL_Y0 + DEBUG_INDICATOR_H)) &&
    (x_u >= (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W));
  wire col1_hit =
    (y_u >= DEBUG_PANEL_Y0) &&
    (y_u < (DEBUG_PANEL_Y0 + DEBUG_INDICATOR_H)) &&
    (x_u >= (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W));
  wire col2_hit =
    (y_u >= DEBUG_PANEL_Y0) &&
    (y_u < (DEBUG_PANEL_Y0 + DEBUG_INDICATOR_H)) &&
    (x_u >= (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W));
  wire col3_hit =
    (y_u >= DEBUG_PANEL_Y0) &&
    (y_u < (DEBUG_PANEL_Y0 + DEBUG_INDICATOR_H)) &&
    (x_u >= (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W));
  wire row0_hit =
    (x_u >= DEBUG_PANEL_X0) &&
    (x_u < (DEBUG_PANEL_X0 + DEBUG_INDICATOR_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire row1_hit =
    (x_u >= DEBUG_PANEL_X0) &&
    (x_u < (DEBUG_PANEL_X0 + DEBUG_INDICATOR_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire row2_hit =
    (x_u >= DEBUG_PANEL_X0) &&
    (x_u < (DEBUG_PANEL_X0 + DEBUG_INDICATOR_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire row3_hit =
    (x_u >= DEBUG_PANEL_X0) &&
    (x_u < (DEBUG_PANEL_X0 + DEBUG_INDICATOR_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell00_hit =
    (x_u >= (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell01_hit =
    (x_u >= (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell02_hit =
    (x_u >= (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell03_hit =
    (x_u >= (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 0 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell10_hit =
    (x_u >= (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell11_hit =
    (x_u >= (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell12_hit =
    (x_u >= (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell13_hit =
    (x_u >= (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 1 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell20_hit =
    (x_u >= (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell21_hit =
    (x_u >= (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell22_hit =
    (x_u >= (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell23_hit =
    (x_u >= (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 2 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell30_hit =
    (x_u >= (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell31_hit =
    (x_u >= (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell32_hit =
    (x_u >= (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire cell33_hit =
    (x_u >= (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_GRID_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP))) &&
    (y_u < (DEBUG_GRID_Y0 + 3 * (DEBUG_CELL_H + DEBUG_GAP) + DEBUG_CELL_H));
  wire raw0_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_VALUE_Y0) &&
    (y_u < (DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H));
  wire raw1_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_VALUE_Y0) &&
    (y_u < (DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H));
  wire raw2_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_VALUE_Y0) &&
    (y_u < (DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H));
  wire raw3_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_VALUE_Y0) &&
    (y_u < (DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H));
  wire raw4_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 4 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 4 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_VALUE_Y0) &&
    (y_u < (DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H));
  wire raw5_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 5 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 5 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_VALUE_Y0) &&
    (y_u < (DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H));
  wire raw6_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 6 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 6 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_VALUE_Y0) &&
    (y_u < (DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H));
  wire raw7_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 7 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 7 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_VALUE_Y0) &&
    (y_u < (DEBUG_RAW_VALUE_Y0 + DEBUG_CELL_H));
  wire raw_mask0_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 0 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_MASK_Y0) &&
    (y_u < (DEBUG_RAW_MASK_Y0 + DEBUG_CELL_H));
  wire raw_mask1_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 1 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_MASK_Y0) &&
    (y_u < (DEBUG_RAW_MASK_Y0 + DEBUG_CELL_H));
  wire raw_mask2_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 2 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_MASK_Y0) &&
    (y_u < (DEBUG_RAW_MASK_Y0 + DEBUG_CELL_H));
  wire raw_mask3_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 3 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_MASK_Y0) &&
    (y_u < (DEBUG_RAW_MASK_Y0 + DEBUG_CELL_H));
  wire raw_mask4_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 4 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 4 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_MASK_Y0) &&
    (y_u < (DEBUG_RAW_MASK_Y0 + DEBUG_CELL_H));
  wire raw_mask5_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 5 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 5 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_MASK_Y0) &&
    (y_u < (DEBUG_RAW_MASK_Y0 + DEBUG_CELL_H));
  wire raw_mask6_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 6 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 6 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_MASK_Y0) &&
    (y_u < (DEBUG_RAW_MASK_Y0 + DEBUG_CELL_H));
  wire raw_mask7_hit =
    (x_u >= (DEBUG_RAW_PANEL_X0 + 7 * (DEBUG_CELL_W + DEBUG_GAP))) &&
    (x_u < (DEBUG_RAW_PANEL_X0 + 7 * (DEBUG_CELL_W + DEBUG_GAP) + DEBUG_CELL_W)) &&
    (y_u >= DEBUG_RAW_MASK_Y0) &&
    (y_u < (DEBUG_RAW_MASK_Y0 + DEBUG_CELL_H));
  wire any_debug_panel_hit =
    col0_hit || col1_hit || col2_hit || col3_hit ||
    row0_hit || row1_hit || row2_hit || row3_hit ||
    cell00_hit || cell01_hit || cell02_hit || cell03_hit ||
    cell10_hit || cell11_hit || cell12_hit || cell13_hit ||
    cell20_hit || cell21_hit || cell22_hit || cell23_hit ||
    cell30_hit || cell31_hit || cell32_hit || cell33_hit ||
    raw0_hit || raw1_hit || raw2_hit || raw3_hit ||
    raw4_hit || raw5_hit || raw6_hit || raw7_hit ||
    raw_mask0_hit || raw_mask1_hit || raw_mask2_hit || raw_mask3_hit ||
    raw_mask4_hit || raw_mask5_hit || raw_mask6_hit || raw_mask7_hit;
  wire row0_active = !i_debug_row_bits[0];
  wire row1_active = !i_debug_row_bits[1];
  wire row2_active = !i_debug_row_bits[2];
  wire row3_active = !i_debug_row_bits[3];
  wire col0_active = !i_debug_col_bits[0];
  wire col1_active = !i_debug_col_bits[1];
  wire col2_active = !i_debug_col_bits[2];
  wire col3_active = !i_debug_col_bits[3];
  wire raw0_low = !i_debug_pmod_bits[0];
  wire raw1_low = !i_debug_pmod_bits[1];
  wire raw2_low = !i_debug_pmod_bits[2];
  wire raw3_low = !i_debug_pmod_bits[3];
  wire raw4_low = !i_debug_pmod_bits[4];
  wire raw5_low = !i_debug_pmod_bits[5];
  wire raw6_low = !i_debug_pmod_bits[6];
  wire raw7_low = !i_debug_pmod_bits[7];
  wire [23:0] debug_panel_rgb =
    raw0_hit ? (i_debug_pmod_col_mask[0] ? (raw0_low ? DEBUG_RAW_MASK_LOW_RGB : DEBUG_RAW_MASK_HIGH_RGB) : (raw0_low ? DEBUG_RAW_READ_LOW_RGB : DEBUG_RAW_READ_HIGH_RGB)) :
    raw1_hit ? (i_debug_pmod_col_mask[1] ? (raw1_low ? DEBUG_RAW_MASK_LOW_RGB : DEBUG_RAW_MASK_HIGH_RGB) : (raw1_low ? DEBUG_RAW_READ_LOW_RGB : DEBUG_RAW_READ_HIGH_RGB)) :
    raw2_hit ? (i_debug_pmod_col_mask[2] ? (raw2_low ? DEBUG_RAW_MASK_LOW_RGB : DEBUG_RAW_MASK_HIGH_RGB) : (raw2_low ? DEBUG_RAW_READ_LOW_RGB : DEBUG_RAW_READ_HIGH_RGB)) :
    raw3_hit ? (i_debug_pmod_col_mask[3] ? (raw3_low ? DEBUG_RAW_MASK_LOW_RGB : DEBUG_RAW_MASK_HIGH_RGB) : (raw3_low ? DEBUG_RAW_READ_LOW_RGB : DEBUG_RAW_READ_HIGH_RGB)) :
    raw4_hit ? (i_debug_pmod_col_mask[4] ? (raw4_low ? DEBUG_RAW_MASK_LOW_RGB : DEBUG_RAW_MASK_HIGH_RGB) : (raw4_low ? DEBUG_RAW_READ_LOW_RGB : DEBUG_RAW_READ_HIGH_RGB)) :
    raw5_hit ? (i_debug_pmod_col_mask[5] ? (raw5_low ? DEBUG_RAW_MASK_LOW_RGB : DEBUG_RAW_MASK_HIGH_RGB) : (raw5_low ? DEBUG_RAW_READ_LOW_RGB : DEBUG_RAW_READ_HIGH_RGB)) :
    raw6_hit ? (i_debug_pmod_col_mask[6] ? (raw6_low ? DEBUG_RAW_MASK_LOW_RGB : DEBUG_RAW_MASK_HIGH_RGB) : (raw6_low ? DEBUG_RAW_READ_LOW_RGB : DEBUG_RAW_READ_HIGH_RGB)) :
    raw7_hit ? (i_debug_pmod_col_mask[7] ? (raw7_low ? DEBUG_RAW_MASK_LOW_RGB : DEBUG_RAW_MASK_HIGH_RGB) : (raw7_low ? DEBUG_RAW_READ_LOW_RGB : DEBUG_RAW_READ_HIGH_RGB)) :
    raw_mask0_hit ? (i_debug_pmod_col_mask[0] ? DEBUG_RAW_MASK_ON_RGB : DEBUG_RAW_MASK_OFF_RGB) :
    raw_mask1_hit ? (i_debug_pmod_col_mask[1] ? DEBUG_RAW_MASK_ON_RGB : DEBUG_RAW_MASK_OFF_RGB) :
    raw_mask2_hit ? (i_debug_pmod_col_mask[2] ? DEBUG_RAW_MASK_ON_RGB : DEBUG_RAW_MASK_OFF_RGB) :
    raw_mask3_hit ? (i_debug_pmod_col_mask[3] ? DEBUG_RAW_MASK_ON_RGB : DEBUG_RAW_MASK_OFF_RGB) :
    raw_mask4_hit ? (i_debug_pmod_col_mask[4] ? DEBUG_RAW_MASK_ON_RGB : DEBUG_RAW_MASK_OFF_RGB) :
    raw_mask5_hit ? (i_debug_pmod_col_mask[5] ? DEBUG_RAW_MASK_ON_RGB : DEBUG_RAW_MASK_OFF_RGB) :
    raw_mask6_hit ? (i_debug_pmod_col_mask[6] ? DEBUG_RAW_MASK_ON_RGB : DEBUG_RAW_MASK_OFF_RGB) :
    raw_mask7_hit ? (i_debug_pmod_col_mask[7] ? DEBUG_RAW_MASK_ON_RGB : DEBUG_RAW_MASK_OFF_RGB) :
    col0_hit ? (i_debug_col_valid[0] ? (col0_active ? DEBUG_LOW_RGB : DEBUG_HIGH_RGB) : DEBUG_DISABLED_RGB) :
    col1_hit ? (i_debug_col_valid[1] ? (col1_active ? DEBUG_LOW_RGB : DEBUG_HIGH_RGB) : DEBUG_DISABLED_RGB) :
    col2_hit ? (i_debug_col_valid[2] ? (col2_active ? DEBUG_LOW_RGB : DEBUG_HIGH_RGB) : DEBUG_DISABLED_RGB) :
    col3_hit ? (i_debug_col_valid[3] ? (col3_active ? DEBUG_LOW_RGB : DEBUG_HIGH_RGB) : DEBUG_DISABLED_RGB) :
    row0_hit ? (i_debug_row_valid[0] ? (row0_active ? DEBUG_LOW_RGB : DEBUG_HIGH_RGB) : DEBUG_DISABLED_RGB) :
    row1_hit ? (i_debug_row_valid[1] ? (row1_active ? DEBUG_LOW_RGB : DEBUG_HIGH_RGB) : DEBUG_DISABLED_RGB) :
    row2_hit ? (i_debug_row_valid[2] ? (row2_active ? DEBUG_LOW_RGB : DEBUG_HIGH_RGB) : DEBUG_DISABLED_RGB) :
    row3_hit ? (i_debug_row_valid[3] ? (row3_active ? DEBUG_LOW_RGB : DEBUG_HIGH_RGB) : DEBUG_DISABLED_RGB) :
    cell00_hit ? ((i_debug_row_valid[0] && i_debug_col_valid[0]) ? ((row0_active && col0_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell01_hit ? ((i_debug_row_valid[0] && i_debug_col_valid[1]) ? ((row0_active && col1_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell02_hit ? ((i_debug_row_valid[0] && i_debug_col_valid[2]) ? ((row0_active && col2_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell03_hit ? ((i_debug_row_valid[0] && i_debug_col_valid[3]) ? ((row0_active && col3_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell10_hit ? ((i_debug_row_valid[1] && i_debug_col_valid[0]) ? ((row1_active && col0_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell11_hit ? ((i_debug_row_valid[1] && i_debug_col_valid[1]) ? ((row1_active && col1_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell12_hit ? ((i_debug_row_valid[1] && i_debug_col_valid[2]) ? ((row1_active && col2_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell13_hit ? ((i_debug_row_valid[1] && i_debug_col_valid[3]) ? ((row1_active && col3_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell20_hit ? ((i_debug_row_valid[2] && i_debug_col_valid[0]) ? ((row2_active && col0_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell21_hit ? ((i_debug_row_valid[2] && i_debug_col_valid[1]) ? ((row2_active && col1_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell22_hit ? ((i_debug_row_valid[2] && i_debug_col_valid[2]) ? ((row2_active && col2_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell23_hit ? ((i_debug_row_valid[2] && i_debug_col_valid[3]) ? ((row2_active && col3_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell30_hit ? ((i_debug_row_valid[3] && i_debug_col_valid[0]) ? ((row3_active && col0_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell31_hit ? ((i_debug_row_valid[3] && i_debug_col_valid[1]) ? ((row3_active && col1_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
    cell32_hit ? ((i_debug_row_valid[3] && i_debug_col_valid[2]) ? ((row3_active && col2_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB) :
               ((i_debug_row_valid[3] && i_debug_col_valid[3]) ? ((row3_active && col3_active) ? DEBUG_CELL_ACTIVE_RGB : DEBUG_CELL_IDLE_RGB) : DEBUG_DISABLED_RGB);

  assign o_rgb = !s2_disp_enable ? 24'h000000 :
                 s2_inside       ? (cursor_pixel_on ? cursor_rgb : base_rgb) :
                 any_debug_panel_hit ? debug_panel_rgb :
                                   border_rgb;

endmodule
