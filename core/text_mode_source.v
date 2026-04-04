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
  localparam [23:0] BORDER_RGB = 24'h0055AA;
  localparam [3:0] GLYPH_W_U4 = GLYPH_W;
  localparam integer CURSOR_X_PAD_I =
    (GLYPH_BIT_BASE > (GLYPH_W - 1)) ? (GLYPH_BIT_BASE - (GLYPH_W - 1)) : 0;
  localparam [2:0] CURSOR_X_PAD = CURSOR_X_PAD_I[2:0];
  localparam [3:0] CURSOR_VISIBLE_W = GLYPH_W_U4 - {1'b0, CURSOR_X_PAD};

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
  reg [6:0]  s0_char_col;
  reg [4:0]  s0_char_row;
  reg [2:0]  s0_glyph_x;
  reg [3:0]  s0_glyph_y;

  // --------------------------------------------------------------------------
  // Stage 1: BRAM response is valid; capture char/attr and launch font read
  // --------------------------------------------------------------------------

  reg        s1_inside;
  reg        s1_disp_enable;
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
      s0_char_col      <= 7'd0;
      s0_char_row      <= 5'd0;
      s0_glyph_x       <= 3'd0;
      s0_glyph_y       <= 4'd0;

      s1_inside        <= 1'b0;
      s1_disp_enable   <= 1'b0;
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
      s0_char_col    <= char_col_now;
      s0_char_row    <= char_row_now;
      s0_glyph_x     <= glyph_x_now;
      s0_glyph_y     <= glyph_y_now;

      // Stage 1: BRAM data belongs to prior cycle's request metadata
      s1_inside      <= s0_inside;
      s1_disp_enable <= s0_disp_enable;
      s1_char_col    <= s0_char_col;
      s1_char_row    <= s0_char_row;
      s1_glyph_x     <= s0_glyph_x;
      s1_glyph_y     <= s0_glyph_y;
      s1_char_code   <= i_cell_rd_data[7:0];
      s1_attr        <= i_cell_rd_data[15:8];

      // Launch font lookup for returned char and saved row
      font_char_code_r <= i_cell_rd_data[7:0];
      font_row_r       <= s0_glyph_y;

      // Stage 2: font bits belong to prior cycle's char/attr/glyph_x
      s2_inside      <= s1_inside;
      s2_disp_enable <= s1_disp_enable;
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

  function [3:0] template_coverage_steps;
    input [2:0] template;
    begin
      case (template)
        3'd0: template_coverage_steps = 4'd0;
        3'd1: template_coverage_steps = 4'd1;
        3'd2: template_coverage_steps = 4'd2;
        3'd3: template_coverage_steps = 4'd3;
        3'd4: template_coverage_steps = 4'd4;
        3'd5: template_coverage_steps = 4'd5;
        3'd6: template_coverage_steps = 4'd6;
        default: template_coverage_steps = 4'd8;
      endcase
    end
  endfunction

  wire [3:0] cursor_coverage = template_coverage_steps(i_cursor_template);
  wire [4:0] cursor_row_span =
    (cursor_coverage == 4'd0) ? 5'd0 : (((GLYPH_H * cursor_coverage) + 7) / 8);
  wire [3:0] cursor_col_span =
    (cursor_coverage == 4'd0) ? 4'd0 : (((CURSOR_VISIBLE_W * cursor_coverage) + 4'd7) >> 3);
  wire cursor_x_inside = (s2_glyph_x >= CURSOR_X_PAD);
  wire [2:0] cursor_glyph_x = s2_glyph_x - CURSOR_X_PAD;
  wire cursor_cell_match =
    s2_inside &&
    i_cursor_visible &&
    (s2_char_col == i_cursor_col) &&
    (s2_char_row == i_cursor_row);
  wire cursor_shape_on =
    !i_cursor_vertical ?
      (cursor_x_inside &&
       (cursor_row_span != 5'd0) &&
       ({1'b0, s2_glyph_y} >= (GLYPH_H - cursor_row_span))) :
      (cursor_x_inside &&
       (cursor_col_span != 4'd0) &&
       ({1'b0, cursor_glyph_x} >= (CURSOR_VISIBLE_W - cursor_col_span)));
  wire cursor_pixel_on = cursor_cell_match && cursor_shape_on;
  wire [23:0] cursor_rgb =
    (i_cursor_mode == 2'd1) ? (base_rgb | fg_rgb) :
    (i_cursor_mode == 2'd2) ? (base_rgb ^ fg_rgb) :
                              fg_rgb;

  assign o_rgb = !s2_disp_enable ? 24'h000000 :
                 s2_inside       ? (cursor_pixel_on ? cursor_rgb : base_rgb) :
                                   BORDER_RGB;

endmodule
