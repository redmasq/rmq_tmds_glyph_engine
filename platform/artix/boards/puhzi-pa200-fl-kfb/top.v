module top(
  input  wire sys_clk_p,
  input  wire sys_clk_n,
  input  wire sys_rstn,

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

  wire        plane_wr_en   = snap_busy ? snap_wr_en   : init_wr_en;
  wire [10:0] plane_wr_addr = snap_busy ? snap_wr_addr : init_wr_addr;
  wire [15:0] plane_wr_data = snap_busy ? snap_wr_data : init_wr_data;

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
    .i_ctrl_wr_en (init_ctrl_wr_en),
    .i_ctrl_wr_addr(init_ctrl_wr_addr),
    .i_ctrl_wr_data(init_ctrl_wr_data),
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
