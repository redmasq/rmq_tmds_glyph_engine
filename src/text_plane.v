module text_plane #(
  parameter H_RESOLUTION = 720,
  parameter V_RESOLUTION = 480,
  parameter TEXT_COLS    = 80,
  parameter TEXT_ROWS    = 25,
  parameter GLYPH_W      = 8,
  parameter GLYPH_H      = 16
)(
  input  wire               i_clk,
  input  wire               i_reset,
  input  wire               i_disp_enable,
  input  wire signed [12:0] i_x,
  input  wire signed [12:0] i_y,

  input  wire               i_wr_en,
  input  wire [10:0]        i_wr_addr,
  input  wire [15:0]        i_wr_data,

  output wire [23:0]        o_rgb
);

  wire [10:0] rd_addr;
  wire [15:0] rd_data;

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

  text_mode_source #(
    .H_RESOLUTION(H_RESOLUTION),
    .V_RESOLUTION(V_RESOLUTION),
    .TEXT_COLS   (TEXT_COLS),
    .TEXT_ROWS   (TEXT_ROWS),
    .GLYPH_W     (GLYPH_W),
    .GLYPH_H     (GLYPH_H)
  ) u_renderer (
    .i_clk        (i_clk),
    .i_reset      (i_reset),
    .i_disp_enable(i_disp_enable),
    .i_x          (i_x),
    .i_y          (i_y),
    .o_cell_rd_addr(rd_addr),
    .i_cell_rd_data(rd_data),
    .o_rgb        (o_rgb)
  );

endmodule