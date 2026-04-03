module text_plane #(
  parameter H_RESOLUTION = 720,
  parameter V_RESOLUTION = 480,
  parameter TEXT_COLS    = 80,
  parameter TEXT_ROWS    = 25,
  parameter GLYPH_W      = 8,
  parameter GLYPH_H      = 16,
  parameter GLYPH_BIT_BASE = 7,
  parameter ROW_BUFFER_WIDTH = 1280,
  parameter signed [13:0] SCAN_X_OFFSET = 14'sd0
)(
  input  wire               i_clk,
  input  wire               i_reset,
  input  wire               i_disp_enable,
  input  wire               i_hsync,
  input  wire               i_vsync,
  input  wire               i_frame_start,
  input  wire               i_frame_commit,
  input  wire               i_line_start,
  input  wire signed [12:0] i_x,
  input  wire signed [12:0] i_y,

  input  wire               i_wr_en,
  input  wire [10:0]        i_wr_addr,
  input  wire [15:0]        i_wr_data,
  input  wire               i_ctrl_wr_en,
  input  wire [2:0]         i_ctrl_wr_addr,
  input  wire [15:0]        i_ctrl_wr_data,

  output reg  [23:0]        o_scan_rgb,
  output reg                o_scan_display_enable,
  output reg                o_scan_hsync,
  output reg                o_scan_vsync
);

  wire [10:0] rd_addr;
  wire [15:0] rd_data;

  wire frame_ctrl_shadow_dirty;
  wire [15:0] frame_ctrl_frame_counter;
  wire [15:0] frame_ctrl_cursor_blink_counter;
  wire [15:0] frame_ctrl_attr_blink_counter;
  wire        frame_ctrl_cursor_visible;
  wire        frame_ctrl_cursor_blink_enable;
  wire [15:0] frame_ctrl_cursor_blink_period;
  wire [15:0] frame_ctrl_attr_blink_period;
  wire [1:0]  frame_ctrl_cursor_mode;
  wire [2:0]  frame_ctrl_cursor_template;

  reg               render_disp_enable;
  reg signed [12:0] render_x;
  reg signed [12:0] render_y;
  wire [23:0]       render_rgb;

  reg [23:0] row0_mem [0:ROW_BUFFER_WIDTH-1];
  reg [23:0] row1_mem [0:ROW_BUFFER_WIDTH-1];

  reg        buf0_valid;
  reg [12:0] buf0_row_y;
  reg        buf1_valid;
  reg [12:0] buf1_row_y;

  reg        scan_active_valid;
  reg        scan_active_buf;

  reg        compose_issue_active;
  reg [12:0] compose_issue_x;
  reg [12:0] compose_target_y;
  reg        compose_target_buf;
  reg [12:0] next_compose_y;

  reg        issue_valid_d1;
  reg [12:0] issue_x_d1;
  reg [12:0] issue_row_y_d1;
  reg        issue_buf_d1;

  reg        issue_valid_d2;
  reg [12:0] issue_x_d2;
  reg [12:0] issue_row_y_d2;
  reg        issue_buf_d2;

  localparam integer ROW_ADDR_W = (ROW_BUFFER_WIDTH <= 1) ? 1 : $clog2(ROW_BUFFER_WIDTH);

  wire visible_line_now = (i_y >= 0) && (i_y < V_RESOLUTION);
  wire buf0_matches_y   = buf0_valid && (buf0_row_y == i_y);
  wire buf1_matches_y   = buf1_valid && (buf1_row_y == i_y);

  // The previous active row becomes free at the start of the next physical
  // line, leaving horizontal blanking as the intentional ownership gap before
  // another row can go active or be re-rendered.
  wire buf0_free_next_line = !buf0_valid || (i_line_start && scan_active_valid && !scan_active_buf);
  wire buf1_free_next_line = !buf1_valid || (i_line_start && scan_active_valid && scan_active_buf);
  wire have_free_buffer    = buf0_free_next_line || buf1_free_next_line;
  wire free_buffer_sel     = buf0_free_next_line ? 1'b0 : 1'b1;

  // Scanout remains sink-agnostic: the row buffer produces delayed RGB plus
  // aligned sync signals that can feed TMDS now and a future VGA sink later.
  wire signed [13:0] scan_sample_x = $signed({i_x[12], i_x}) + SCAN_X_OFFSET;
  wire [ROW_ADDR_W-1:0] issue_x_idx = issue_x_d2[ROW_ADDR_W-1:0];
  wire [ROW_ADDR_W-1:0] scan_x_idx  = scan_sample_x[ROW_ADDR_W-1:0];
  wire scan_fetch_now =
    i_disp_enable &&
    scan_active_valid &&
    (scan_sample_x >= 0) &&
    (scan_sample_x < H_RESOLUTION);

  text_cell_bram #(
    .DEPTH(TEXT_COLS * TEXT_ROWS),
    .AW   (11)
  ) u_cell_ram (
    .clk    (i_clk),
    .rd_en  (1'b1),
    .rd_addr(rd_addr),
    .rd_data(rd_data),
    .wr_en  (i_wr_en),
    .wr_addr(i_wr_addr),
    .wr_data(i_wr_data)
  );

  // Keep committed frame-domain control state separate from the shadow write
  // side so future cursor/attribute features can consume a stable view for the
  // full active region after each pre-active commit edge.
  text_frame_ctrl u_frame_ctrl (
    .i_clk                 (i_clk),
    .i_reset               (i_reset),
    .i_frame_commit        (i_frame_commit),
    .i_ctrl_wr_en          (i_ctrl_wr_en),
    .i_ctrl_wr_addr        (i_ctrl_wr_addr),
    .i_ctrl_wr_data        (i_ctrl_wr_data),
    .o_active_cursor_visible(frame_ctrl_cursor_visible),
    .o_active_cursor_blink_enable(frame_ctrl_cursor_blink_enable),
    .o_active_cursor_blink_period(frame_ctrl_cursor_blink_period),
    .o_active_attr_blink_period(frame_ctrl_attr_blink_period),
    .o_active_cursor_mode  (frame_ctrl_cursor_mode),
    .o_active_cursor_template(frame_ctrl_cursor_template),
    .o_shadow_dirty        (frame_ctrl_shadow_dirty),
    .o_frame_counter       (frame_ctrl_frame_counter),
    .o_cursor_blink_counter(frame_ctrl_cursor_blink_counter),
    .o_attr_blink_counter  (frame_ctrl_attr_blink_counter)
  );

  text_mode_source #(
    .H_RESOLUTION(H_RESOLUTION),
    .V_RESOLUTION(V_RESOLUTION),
    .TEXT_COLS   (TEXT_COLS),
    .TEXT_ROWS   (TEXT_ROWS),
    .GLYPH_W     (GLYPH_W),
    .GLYPH_H     (GLYPH_H),
    .GLYPH_BIT_BASE(GLYPH_BIT_BASE)
  ) u_renderer (
    .i_clk        (i_clk),
    .i_reset      (i_reset),
    .i_disp_enable(render_disp_enable),
    .i_x          (render_x),
    .i_y          (render_y),
    .o_cell_rd_addr(rd_addr),
    .i_cell_rd_data(rd_data),
    .o_rgb        (render_rgb)
  );

  always @(posedge i_clk) begin
    if (i_reset) begin
      render_disp_enable    <= 1'b0;
      render_x              <= 13'sd0;
      render_y              <= 13'sd0;

      buf0_valid            <= 1'b0;
      buf0_row_y            <= 13'd0;
      buf1_valid            <= 1'b0;
      buf1_row_y            <= 13'd0;

      scan_active_valid     <= 1'b0;
      scan_active_buf       <= 1'b0;

      compose_issue_active  <= 1'b0;
      compose_issue_x       <= 13'd0;
      compose_target_y      <= 13'd0;
      compose_target_buf    <= 1'b0;
      next_compose_y        <= 13'd0;

      issue_valid_d1        <= 1'b0;
      issue_x_d1            <= 13'd0;
      issue_row_y_d1        <= 13'd0;
      issue_buf_d1          <= 1'b0;
      issue_valid_d2        <= 1'b0;
      issue_x_d2            <= 13'd0;
      issue_row_y_d2        <= 13'd0;
      issue_buf_d2          <= 1'b0;

      o_scan_rgb            <= 24'h000000;
      o_scan_display_enable <= 1'b0;
      o_scan_hsync          <= 1'b0;
      o_scan_vsync          <= 1'b0;
    end else begin
      if (i_frame_commit) begin
        buf0_valid           <= 1'b0;
        buf1_valid           <= 1'b0;
        scan_active_valid    <= 1'b0;
        compose_issue_active <= 1'b0;
        next_compose_y       <= 13'd0;
        issue_valid_d1       <= 1'b0;
        issue_valid_d2       <= 1'b0;
      end

      render_disp_enable <= compose_issue_active;
      render_x           <= compose_issue_active ? $signed(compose_issue_x) : 13'sd0;
      render_y           <= compose_issue_active ? $signed(compose_target_y) : 13'sd0;

      issue_valid_d1 <= compose_issue_active;
      issue_x_d1     <= compose_issue_x;
      issue_row_y_d1 <= compose_target_y;
      issue_buf_d1   <= compose_target_buf;

      issue_valid_d2 <= issue_valid_d1;
      issue_x_d2     <= issue_x_d1;
      issue_row_y_d2 <= issue_row_y_d1;
      issue_buf_d2   <= issue_buf_d1;

      if (compose_issue_active) begin
        if (compose_issue_x == (H_RESOLUTION - 1))
          compose_issue_active <= 1'b0;
        else
          compose_issue_x <= compose_issue_x + 13'd1;
      end

      if (issue_valid_d2) begin
        if (issue_buf_d2)
          row1_mem[issue_x_idx] <= render_rgb;
        else
          row0_mem[issue_x_idx] <= render_rgb;

        if (issue_x_d2 == (H_RESOLUTION - 1)) begin
          if (issue_buf_d2) begin
            buf1_valid <= 1'b1;
            buf1_row_y <= issue_row_y_d2;
          end else begin
            buf0_valid <= 1'b1;
            buf0_row_y <= issue_row_y_d2;
          end
        end
      end

      if (i_line_start) begin
        if (scan_active_valid) begin
          if (scan_active_buf)
            buf1_valid <= 1'b0;
          else
            buf0_valid <= 1'b0;
          scan_active_valid <= 1'b0;
        end

        if (visible_line_now) begin
          if (buf0_matches_y) begin
            scan_active_valid <= 1'b1;
            scan_active_buf   <= 1'b0;
          end else if (buf1_matches_y) begin
            scan_active_valid <= 1'b1;
            scan_active_buf   <= 1'b1;
          end
        end

        // Shadow-register promotion now happens before active video, so row 0
        // can be re-composed during blanking instead of racing the first
        // visible line at frame start.
        if (!compose_issue_active && have_free_buffer && (next_compose_y < V_RESOLUTION)) begin
          compose_issue_active <= 1'b1;
          compose_issue_x      <= 13'd0;
          compose_target_y     <= next_compose_y;
          compose_target_buf   <= free_buffer_sel;
          next_compose_y       <= next_compose_y + 13'd1;
        end
      end

      if (scan_fetch_now) begin
        if (scan_active_buf)
          o_scan_rgb <= row1_mem[scan_x_idx];
        else
          o_scan_rgb <= row0_mem[scan_x_idx];
      end else begin
        o_scan_rgb <= 24'h000000;
      end

      o_scan_display_enable <= i_disp_enable;
      o_scan_hsync          <= i_hsync;
      o_scan_vsync          <= i_vsync;
    end
  end

endmodule
