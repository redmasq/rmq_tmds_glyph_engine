module top #(
  parameter VIDEO_MODE = 0   // 0 = 720x480p60, 1 = 1280x720p60
)(
  input  wire clk,
  input  wire reset_button,
  output wire [3:0] hdmi_tx_n,
  output wire [3:0] hdmi_tx_p
);

  localparam MODE_720X480  = 0;

  localparam H_RESOLUTION    = (VIDEO_MODE == MODE_720X480)  ? 720  : 1280;
  localparam V_RESOLUTION    = (VIDEO_MODE == MODE_720X480)  ? 480  : 720;
  localparam H_FRONT_PORCH   = (VIDEO_MODE == MODE_720X480)  ? 16   : 110;
  localparam H_SYNC          = (VIDEO_MODE == MODE_720X480)  ? 64   : 40;
  localparam H_BACK_PORCH    = (VIDEO_MODE == MODE_720X480)  ? 60   : 220;
  localparam V_FRONT_PORCH   = (VIDEO_MODE == MODE_720X480)  ? 9    : 5;
  localparam V_SYNC          = (VIDEO_MODE == MODE_720X480)  ? 6    : 5;
  localparam V_BACK_PORCH    = (VIDEO_MODE == MODE_720X480)  ? 18   : 20;
  localparam H_SYNC_POLARITY = (VIDEO_MODE == MODE_720X480)  ? 1'b0 : 1'b1;
  localparam V_SYNC_POLARITY = (VIDEO_MODE == MODE_720X480)  ? 1'b0 : 1'b1;

  wire hdmi_clk_5x;
  wire hdmi_clk;
  wire hdmi_clk_lock;

  gowin_video_pll #(
    .VIDEO_MODE(VIDEO_MODE)
  ) hdmi_pll (
    .clkin    (clk),
    .reset    (1'b0),
    .clkout_5x(hdmi_clk_5x),
    .lock     (hdmi_clk_lock)
  );

  wire reset  = ~reset_button | ~hdmi_clk_lock;
  wire resetn = ~reset;

  CLKDIV #(
    .DIV_MODE("5")
  ) u_clkdiv5 (
    .HCLKIN(hdmi_clk_5x),
    .RESETN(resetn),
    .CALIB (1'b0),
    .CLKOUT(hdmi_clk)
  );

  wire signed [12:0] x;
  wire signed [12:0] y;
  wire [2:0] hve_sync;
  wire frame_start;
  wire vblank;
  wire vback_porch;
  wire [23:0] rgb;

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
    .i_pixel_clk   (hdmi_clk),
    .i_reset       (reset),
    .o_hvesync     (hve_sync),
    .o_frame_start (frame_start),
    .o_vblank      (vblank),
    .o_vback_porch (vback_porch),
    .o_x           (x),
    .o_y           (y)
  );

  wire        init_wr_en;
  wire [10:0] init_wr_addr;
  wire [15:0] init_wr_data;
  wire        init_done;

  text_init_writer u_init_writer (
    .i_clk    (hdmi_clk),
    .i_reset  (reset),
    .o_wr_en  (init_wr_en),
    .o_wr_addr(init_wr_addr),
    .o_wr_data(init_wr_data),
    .o_done   (init_done)
  );

  wire        snap_wr_en;
  wire [10:0] snap_wr_addr;
  wire [15:0] snap_wr_data;
  wire        snap_busy;

  text_snapshot_loader u_snapshot_loader (
    .i_clk         (hdmi_clk),
    .i_reset       (reset),
    .i_enable      (1'b0),       // turn on when SDRAM path exists
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

  reg [2:0] hve_sync_d1;
  reg [2:0] hve_sync_d2;

  always @(posedge hdmi_clk) begin
    if (reset) begin
      hve_sync_d1 <= 3'b000;
      hve_sync_d2 <= 3'b000;
    end else begin
      hve_sync_d1 <= hve_sync;
      hve_sync_d2 <= hve_sync_d1;
    end
  end

  text_plane #(
    .H_RESOLUTION(H_RESOLUTION),
    .V_RESOLUTION(V_RESOLUTION),
    .TEXT_COLS   (80),
    .TEXT_ROWS   (25),
    .GLYPH_W     (8),
    .GLYPH_H     (16)
  ) u_text_plane (
    .i_clk        (hdmi_clk),
    .i_reset      (reset),
    .i_disp_enable(hve_sync[2]),
    .i_x          (x),
    .i_y          (y),
    .i_wr_en      (plane_wr_en),
    .i_wr_addr    (plane_wr_addr),
    .i_wr_data    (plane_wr_data),
    .o_rgb        (rgb)
  );

  gowin_hdmi_phy u_hdmi (
    .reset      (reset),
    .hdmi_clk   (hdmi_clk),
    .hdmi_clk_5x(hdmi_clk_5x),
    .hve_sync   (hve_sync_d2),
    .rgb        (rgb),
    .hdmi_tx_n  (hdmi_tx_n),
    .hdmi_tx_p  (hdmi_tx_p)
  );

endmodule
