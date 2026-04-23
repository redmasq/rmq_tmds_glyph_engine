module top(
  input  wire sys_clk_p,
  input  wire sys_clk_n,
  input  wire sys_rstn,
  input  wire key1_n,
`ifdef PUHZI_ENABLE_FULL_REINIT_INPUT
  input  wire full_reinit_n,
`endif
  input  wire uart_rx,
  output wire uart_tx,
  output wire HDMI_CLK_P,
  output wire HDMI_CLK_N,
  output wire HDMI_D0_P,
  output wire HDMI_D0_N,
  output wire HDMI_D1_P,
  output wire HDMI_D1_N,
  output wire HDMI_D2_P,
  output wire HDMI_D2_N
);

`ifdef VIDEO_MODE_720P
  localparam VIDEO_MODE = 1;
`else
  localparam VIDEO_MODE = 0;
`endif

  localparam MODE_720X480  = 0;

  localparam H_RESOLUTION    = (VIDEO_MODE == MODE_720X480) ? 720  : 1280;
  localparam V_RESOLUTION    = (VIDEO_MODE == MODE_720X480) ? 480  : 720;
  localparam H_FRONT_PORCH   = (VIDEO_MODE == MODE_720X480) ? 16   : 110;
  localparam H_SYNC          = (VIDEO_MODE == MODE_720X480) ? 64   : 40;
  localparam H_BACK_PORCH    = (VIDEO_MODE == MODE_720X480) ? 60   : 220;
  localparam V_FRONT_PORCH   = (VIDEO_MODE == MODE_720X480) ? 9    : 5;
  localparam V_SYNC          = (VIDEO_MODE == MODE_720X480) ? 6    : 5;
  localparam V_BACK_PORCH    = (VIDEO_MODE == MODE_720X480) ? 18   : 20;
  localparam H_SYNC_POLARITY = (VIDEO_MODE == MODE_720X480) ? 1'b0 : 1'b1;
  localparam V_SYNC_POLARITY = (VIDEO_MODE == MODE_720X480) ? 1'b0 : 1'b1;
  localparam GLYPH_BIT_BASE  = 8;
  localparam signed [13:0] SCAN_X_OFFSET = 14'sd0;
  localparam signed [7:0] CURSOR_X_OFFSET_DEBUG = 8'sd7 - {4'd0, GLYPH_BIT_BASE[3:0]};

  wire pixel_clk;
  wire pixel_clk_5x;
  wire pll_locked;

  artix_video_pll #(
    .VIDEO_MODE(VIDEO_MODE)
  ) u_video_pll (
    .clkin_p     (sys_clk_p),
    .clkin_n     (sys_clk_n),
    .reset       (~sys_rstn),
    .pixel_clk   (pixel_clk),
    .pixel_clk_5x(pixel_clk_5x),
    .locked      (pll_locked)
  );

  wire reset = ~sys_rstn | ~pll_locked;

  wire signed [12:0] x;
  wire signed [12:0] y;
  wire [2:0] hve_sync;
  wire frame_start;
  wire frame_commit;
  wire line_start;
  wire vblank;
  wire vback_porch;
  wire [23:0] scan_rgb;
  wire        scan_display_enable;
  wire        scan_hsync;
  wire        scan_vsync;
  wire [9:0] tmds_ch0;
  wire [9:0] tmds_ch1;
  wire [9:0] tmds_ch2;
  wire uart_cmd_wr_en;
  wire [10:0] uart_cmd_wr_addr;
  wire [15:0] uart_cmd_wr_data;
  wire uart_cmd_ctrl_wr_en;
  wire [2:0] uart_cmd_ctrl_wr_addr;
  wire [15:0] uart_cmd_ctrl_wr_data;
  wire uart_debug_dump_request;
  wire [7:0] uart_debug_last_rx_byte;
  wire [7:0] uart_debug_last_cmd_byte;
  wire uart_debug_last_cmd_hit;
  wire [7:0] uart_debug_last_shape_source;
  wire [15:0] uart_debug_last_shape_word;
  wire uart_demo_enable;
  wire uart_glyph_preview_updates_enable;
  wire uart_screen_clear_request;
  wire uart_full_reinit_request;
  wire status_cursor_visible;
  wire status_cursor_blink_enable;
  wire [15:0] status_cursor_blink_period;
  wire [15:0] status_attr_blink_period;
  wire [6:0] status_cursor_col;
  wire [4:0] status_cursor_row;
  wire status_cursor_vertical;
  wire [1:0] status_cursor_mode;
  wire [2:0] status_cursor_template;
  wire status_shadow_dirty;
  wire [15:0] status_frame_counter;
  wire [15:0] status_cursor_cell;
  wire dump_button_pulse;
  wire full_reinit_button_pulse;
`ifdef PUHZI_ENABLE_FULL_REINIT_INPUT
  wire full_reinit_button_n = full_reinit_n;
`else
  wire full_reinit_button_n = 1'b1;
`endif

  display_signal #(
    .H_RESOLUTION   (H_RESOLUTION),
    .V_RESOLUTION   (V_RESOLUTION),
    .H_FRONT_PORCH  (H_FRONT_PORCH),
    .H_SYNC         (H_SYNC),
    .H_BACK_PORCH   (H_BACK_PORCH),
    .V_FRONT_PORCH  (V_FRONT_PORCH),
    .V_SYNC         (V_SYNC),
    .V_BACK_PORCH   (V_BACK_PORCH),
    .H_SYNC_POLARITY(H_SYNC_POLARITY),
    .V_SYNC_POLARITY(V_SYNC_POLARITY)
  ) u_timing (
    .i_pixel_clk   (pixel_clk),
    .i_reset       (reset),
    .o_hvesync     (hve_sync),
    .o_frame_start (frame_start),
    .o_frame_commit(frame_commit),
    .o_line_start  (line_start),
    .o_vblank      (vblank),
    .o_vback_porch (vback_porch),
    .o_x           (x),
    .o_y           (y)
  );

  wire        init_wr_en;
  wire [10:0] init_wr_addr;
  wire [15:0] init_wr_data;
  wire        init_ctrl_wr_en;
  wire [2:0]  init_ctrl_wr_addr;
  wire [15:0] init_ctrl_wr_data;
  wire        init_done;

  text_init_writer u_init_writer (
    .i_clk    (pixel_clk),
    .i_reset  (reset),
    .i_frame_commit(frame_commit),
    .i_demo_enable(uart_demo_enable),
    .i_screen_clear_request(uart_screen_clear_request),
    .i_full_reinit_request(full_reinit_button_pulse | uart_full_reinit_request),
    .i_glyph_preview_updates_enable(uart_glyph_preview_updates_enable),
    .o_wr_en  (init_wr_en),
    .o_wr_addr(init_wr_addr),
    .o_wr_data(init_wr_data),
    .o_ctrl_wr_en(init_ctrl_wr_en),
    .o_ctrl_wr_addr(init_ctrl_wr_addr),
    .o_ctrl_wr_data(init_ctrl_wr_data),
    .o_done   (init_done)
  );

  wire        snap_wr_en;
  wire [10:0] snap_wr_addr;
  wire [15:0] snap_wr_data;
  wire        snap_busy;

  text_snapshot_loader u_snapshot_loader (
    .i_clk         (pixel_clk),
    .i_reset       (reset),
    .i_enable      (1'b0),
    .i_init_done   (init_done),
    .i_frame_start (frame_start),
    .i_vblank      (vblank),
    .i_vback_porch (vback_porch),
    .o_wr_en       (snap_wr_en),
    .o_wr_addr     (snap_wr_addr),
    .o_wr_data     (snap_wr_data),
    .o_busy        (snap_busy)
  );

  wire        plane_wr_en_base   = snap_busy ? snap_wr_en   : init_wr_en;
  wire [10:0] plane_wr_addr_base = snap_busy ? snap_wr_addr : init_wr_addr;
  wire [15:0] plane_wr_data_base = snap_busy ? snap_wr_data : init_wr_data;
  wire        plane_wr_en;
  wire [10:0] plane_wr_addr;
  wire [15:0] plane_wr_data;
  wire        plane_ctrl_wr_en;
  wire [2:0]  plane_ctrl_wr_addr;
  wire [15:0] plane_ctrl_wr_data;
  wire        init_ctrl_wr_en_active = init_ctrl_wr_en && (~init_done || uart_demo_enable);

  uart_text_cursor_console #(
    .CLK_HZ((VIDEO_MODE == MODE_720X480) ? 27000000 : 74250000),
    .BAUD_RATE(115200)
  ) u_uart_text_cursor_console (
    .i_clk(pixel_clk),
    .i_reset(reset),
    .i_init_done(init_done),
    .i_external_full_reinit(full_reinit_button_pulse),
    .i_uart_rx(uart_rx),
    .i_snoop_wr_en(plane_wr_en),
    .i_snoop_wr_addr(plane_wr_addr),
    .i_snoop_wr_data(plane_wr_data),
    .i_snoop_ctrl_wr_en(plane_ctrl_wr_en),
    .i_snoop_ctrl_wr_addr(plane_ctrl_wr_addr),
    .i_snoop_ctrl_wr_data(plane_ctrl_wr_data),
    .o_demo_enable(uart_demo_enable),
    .o_glyph_preview_updates_enable(uart_glyph_preview_updates_enable),
    .o_screen_clear_request(uart_screen_clear_request),
    .o_full_reinit_request(uart_full_reinit_request),
    .o_debug_dump_request(uart_debug_dump_request),
    .o_debug_last_rx_byte(uart_debug_last_rx_byte),
    .o_debug_last_cmd_byte(uart_debug_last_cmd_byte),
    .o_debug_last_cmd_hit(uart_debug_last_cmd_hit),
    .o_debug_last_shape_source(uart_debug_last_shape_source),
    .o_debug_last_shape_word(uart_debug_last_shape_word),
    .o_wr_en(uart_cmd_wr_en),
    .o_wr_addr(uart_cmd_wr_addr),
    .o_wr_data(uart_cmd_wr_data),
    .o_ctrl_wr_en(uart_cmd_ctrl_wr_en),
    .o_ctrl_wr_addr(uart_cmd_ctrl_wr_addr),
    .o_ctrl_wr_data(uart_cmd_ctrl_wr_data)
  );

  assign plane_wr_en   = uart_cmd_wr_en ? 1'b1 : plane_wr_en_base;
  assign plane_wr_addr = uart_cmd_wr_en ? uart_cmd_wr_addr : plane_wr_addr_base;
  assign plane_wr_data = uart_cmd_wr_en ? uart_cmd_wr_data : plane_wr_data_base;
  assign plane_ctrl_wr_en = uart_cmd_ctrl_wr_en ? 1'b1 : init_ctrl_wr_en_active;
  assign plane_ctrl_wr_addr = uart_cmd_ctrl_wr_en ? uart_cmd_ctrl_wr_addr : init_ctrl_wr_addr;
  assign plane_ctrl_wr_data = uart_cmd_ctrl_wr_en ? uart_cmd_ctrl_wr_data : init_ctrl_wr_data;

  text_mode_status_tracker #(
    .TEXT_COLS(80),
    .TEXT_ROWS(25)
  ) u_status_tracker (
    .i_clk(pixel_clk),
    .i_reset(reset),
    .i_frame_commit(frame_commit),
    .i_wr_en(plane_wr_en),
    .i_wr_addr(plane_wr_addr),
    .i_wr_data(plane_wr_data),
    .i_ctrl_wr_en(plane_ctrl_wr_en),
    .i_ctrl_wr_addr(plane_ctrl_wr_addr),
    .i_ctrl_wr_data(plane_ctrl_wr_data),
    .o_cursor_visible(status_cursor_visible),
    .o_cursor_blink_enable(status_cursor_blink_enable),
    .o_cursor_blink_period(status_cursor_blink_period),
    .o_attr_blink_period(status_attr_blink_period),
    .o_cursor_col(status_cursor_col),
    .o_cursor_row(status_cursor_row),
    .o_cursor_vertical(status_cursor_vertical),
    .o_cursor_mode(status_cursor_mode),
    .o_cursor_template(status_cursor_template),
    .o_shadow_dirty(status_shadow_dirty),
    .o_frame_counter(status_frame_counter),
    .o_cursor_cell(status_cursor_cell)
  );

  active_low_button_pulse #(
    .RELEASE_TICKS(((VIDEO_MODE == MODE_720X480) ? 27000000 : 74250000) / 20)
  ) u_dump_button_pulse (
    .i_clk(pixel_clk),
    .i_reset(reset),
    .i_button_n(key1_n),
    .o_pulse(dump_button_pulse)
  );

  active_low_button_pulse #(
    .RELEASE_TICKS(((VIDEO_MODE == MODE_720X480) ? 27000000 : 74250000) / 20)
  ) u_full_reinit_button_pulse (
    .i_clk(pixel_clk),
    .i_reset(reset),
    .i_button_n(full_reinit_button_n),
    .o_pulse(full_reinit_button_pulse)
  );

  text_mode_uart_debug_dump #(
    .CLK_HZ((VIDEO_MODE == MODE_720X480) ? 27000000 : 74250000),
    .BAUD_RATE(115200),
    .H_RESOLUTION(H_RESOLUTION),
    .V_RESOLUTION(V_RESOLUTION)
  ) u_uart_debug_dump (
    .i_clk(pixel_clk),
    .i_reset(reset),
    .i_dump_request(dump_button_pulse | uart_debug_dump_request),
    .i_debug_last_rx_byte(uart_debug_last_rx_byte),
    .i_debug_last_cmd_byte(uart_debug_last_cmd_byte),
    .i_debug_last_cmd_hit(uart_debug_last_cmd_hit),
    .i_debug_last_shape_source(uart_debug_last_shape_source),
    .i_debug_last_shape_word(uart_debug_last_shape_word),
    .i_debug_glyph_bit_base(GLYPH_BIT_BASE[3:0]),
    .i_debug_cursor_x_offset(CURSOR_X_OFFSET_DEBUG),
    .i_demo_enable(uart_demo_enable),
    .i_cursor_visible(status_cursor_visible),
    .i_cursor_blink_enable(status_cursor_blink_enable),
    .i_cursor_blink_period(status_cursor_blink_period),
    .i_attr_blink_period(status_attr_blink_period),
    .i_cursor_col(status_cursor_col),
    .i_cursor_row(status_cursor_row),
    .i_cursor_vertical(status_cursor_vertical),
    .i_cursor_mode(status_cursor_mode),
    .i_cursor_template(status_cursor_template),
    .i_shadow_dirty(status_shadow_dirty),
    .i_frame_counter(status_frame_counter),
    .i_cursor_cell(status_cursor_cell),
    .i_extra_wr_en(1'b0),
    .i_extra_wr_addr(6'd0),
    .i_extra_wr_data(8'h00),
    .i_extra_len(6'd0),
    .o_uart_tx(uart_tx)
  );

  text_plane #(
    .H_RESOLUTION(H_RESOLUTION),
    .V_RESOLUTION(V_RESOLUTION),
    .TEXT_COLS   (80),
    .TEXT_ROWS   (25),
    .GLYPH_W     (8),
    .GLYPH_H     (16),
    .GLYPH_BIT_BASE(GLYPH_BIT_BASE),
    .SCAN_X_OFFSET(SCAN_X_OFFSET)
  ) u_text_plane (
    .i_clk        (pixel_clk),
    .i_reset      (reset),
    .i_disp_enable(hve_sync[2]),
    .i_hsync      (hve_sync[0]),
    .i_vsync      (hve_sync[1]),
    .i_frame_start(frame_start),
    .i_frame_commit(frame_commit),
    .i_line_start (line_start),
    .i_x          (x),
    .i_y          (y),
    .i_wr_en      (plane_wr_en),
    .i_wr_addr    (plane_wr_addr),
    .i_wr_data    (plane_wr_data),
    .i_ctrl_wr_en (plane_ctrl_wr_en),
    .i_ctrl_wr_addr(plane_ctrl_wr_addr),
    .i_ctrl_wr_data(plane_ctrl_wr_data),
    .o_scan_rgb   (scan_rgb),
    .o_scan_display_enable(scan_display_enable),
    .o_scan_hsync (scan_hsync),
    .o_scan_vsync (scan_vsync)
  );

  tmds_encoder encode_b (
    .i_hdmi_clk      (pixel_clk),
    .i_reset         (reset),
    .i_data          (scan_rgb[7:0]),
    .i_ctrl          ({scan_vsync, scan_hsync}),
    .i_display_enable(scan_display_enable),
    .o_tmds          (tmds_ch0)
  );

  tmds_encoder encode_g (
    .i_hdmi_clk      (pixel_clk),
    .i_reset         (reset),
    .i_data          (scan_rgb[15:8]),
    .i_ctrl          (2'b00),
    .i_display_enable(scan_display_enable),
    .o_tmds          (tmds_ch1)
  );

  tmds_encoder encode_r (
    .i_hdmi_clk      (pixel_clk),
    .i_reset         (reset),
    .i_data          (scan_rgb[23:16]),
    .i_ctrl          (2'b00),
    .i_display_enable(scan_display_enable),
    .o_tmds          (tmds_ch2)
  );

  artix_hdmi_phy u_hdmi_phy (
    .pixel_clk   (pixel_clk),
    .pixel_clk_5x(pixel_clk_5x),
    .tmds_ch0    (tmds_ch0),
    .tmds_ch1    (tmds_ch1),
    .tmds_ch2    (tmds_ch2),
    .reset       (reset),
    .hdmi_tx_p   ({HDMI_CLK_P, HDMI_D2_P, HDMI_D1_P, HDMI_D0_P}),
    .hdmi_tx_n   ({HDMI_CLK_N, HDMI_D2_N, HDMI_D1_N, HDMI_D0_N})
  );
endmodule
