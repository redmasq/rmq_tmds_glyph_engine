module display_signal #(
  parameter H_RESOLUTION    = 720,
  parameter V_RESOLUTION    = 480,
  parameter H_FRONT_PORCH   = 16,
  parameter H_SYNC          = 64,
  parameter H_BACK_PORCH    = 60,
  parameter V_FRONT_PORCH   = 9,
  parameter V_SYNC          = 6,
  parameter V_BACK_PORCH    = 18,
  parameter H_SYNC_POLARITY = 1'b0,
  parameter V_SYNC_POLARITY = 1'b0
)(
  input  wire               i_pixel_clk,
  input  wire               i_reset,
  output wire [2:0]         o_hvesync,       // {display_enable, vsync, hsync}
  output wire               o_frame_start,
  output wire               o_vblank,
  output wire               o_vback_porch,
  output reg  signed [12:0] o_x,
  output reg  signed [12:0] o_y
);

  localparam signed H_START       = -H_BACK_PORCH - H_SYNC - H_FRONT_PORCH;
  localparam signed HSYNC_START   = -H_BACK_PORCH - H_SYNC;
  localparam signed HSYNC_END     = -H_BACK_PORCH;
  localparam signed H_LAST        = H_RESOLUTION - 1;

  localparam signed V_START       = -V_BACK_PORCH - V_SYNC - V_FRONT_PORCH;
  localparam signed VSYNC_START   = -V_BACK_PORCH - V_SYNC;
  localparam signed VSYNC_END     = -V_BACK_PORCH;
  localparam signed V_LAST        = V_RESOLUTION - 1;

  wire display_enable =
    (o_x >= 0) && (o_x < H_RESOLUTION) &&
    (o_y >= 0) && (o_y < V_RESOLUTION);

  wire hsync_active = (o_x >= HSYNC_START) && (o_x < HSYNC_END);
  wire vsync_active = (o_y >= VSYNC_START) && (o_y < VSYNC_END);

  assign o_hvesync = {
    display_enable,
    V_SYNC_POLARITY ^ vsync_active,
    H_SYNC_POLARITY ^ hsync_active
  };

  assign o_frame_start = (o_x == H_START) && (o_y == V_START);
  assign o_vblank      = (o_y < 0);
  assign o_vback_porch = (o_y >= VSYNC_END) && (o_y < 0);

  always @(posedge i_pixel_clk) begin
    if (i_reset) begin
      o_x <= H_START;
      o_y <= V_START;
    end else begin
      if (o_x == H_LAST) begin
        o_x <= H_START;
        if (o_y == V_LAST)
          o_y <= V_START;
        else
          o_y <= o_y + 13'sd1;
      end else begin
        o_x <= o_x + 13'sd1;
      end
    end
  end

endmodule
