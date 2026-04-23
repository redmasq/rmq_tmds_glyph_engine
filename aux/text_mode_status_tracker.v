module text_mode_status_tracker #(
  parameter integer TEXT_COLS = 80,
  parameter integer TEXT_ROWS = 25,
  parameter integer CELL_DEPTH = TEXT_COLS * TEXT_ROWS
)(
  input  wire        i_clk,
  input  wire        i_reset,
  input  wire        i_frame_commit,
  input  wire        i_wr_en,
  input  wire [10:0] i_wr_addr,
  input  wire [15:0] i_wr_data,
  input  wire        i_ctrl_wr_en,
  input  wire [2:0]  i_ctrl_wr_addr,
  input  wire [15:0] i_ctrl_wr_data,

  output reg         o_cursor_visible,
  output reg         o_cursor_blink_enable,
  output reg  [15:0] o_cursor_blink_period,
  output reg  [15:0] o_attr_blink_period,
  output reg  [6:0]  o_cursor_col,
  output reg  [4:0]  o_cursor_row,
  output reg         o_cursor_vertical,
  output reg  [1:0]  o_cursor_mode,
  output reg  [2:0]  o_cursor_template,
  output reg         o_shadow_dirty,
  output reg  [15:0] o_frame_counter,
  output reg  [15:0] o_cursor_cell
);

  localparam [2:0] CTRL_ADDR_CURSOR_FLAGS        = 3'd0;
  localparam [2:0] CTRL_ADDR_CURSOR_BLINK_PERIOD = 3'd1;
  localparam [2:0] CTRL_ADDR_ATTR_BLINK_PERIOD   = 3'd2;
  localparam [2:0] CTRL_ADDR_CURSOR_SHAPE        = 3'd3;
  localparam [2:0] CTRL_ADDR_CURSOR_COL          = 3'd4;
  localparam [2:0] CTRL_ADDR_CURSOR_ROW          = 3'd5;
  localparam [15:0] RESET_CURSOR_BLINK_PERIOD = 16'd32;
  localparam [15:0] RESET_ATTR_BLINK_PERIOD   = 16'd64;

  reg        shadow_cursor_visible;
  reg        shadow_cursor_blink_enable;
  reg [15:0] shadow_cursor_blink_period;
  reg [15:0] shadow_attr_blink_period;
  reg [6:0]  shadow_cursor_col;
  reg [4:0]  shadow_cursor_row;
  reg        shadow_cursor_vertical;
  reg [1:0]  shadow_cursor_mode;
  reg [2:0]  shadow_cursor_template;
  wire [10:0] cursor_addr = ({6'd0, o_cursor_row} * TEXT_COLS) + {4'd0, o_cursor_col};
  wire [15:0] cursor_cell_rd;

  text_cell_bram #(
    .DEPTH(CELL_DEPTH),
    .AW   (11)
  ) u_status_shadow_cells (
    .clk    (i_clk),
    .rd_en  (1'b1),
    .rd_addr(cursor_addr),
    .rd_data(cursor_cell_rd),
    .wr_en  (i_wr_en),
    .wr_addr(i_wr_addr),
    .wr_data(i_wr_data)
  );

  always @(posedge i_clk) begin
    if (i_reset) begin
      o_cursor_visible      <= 1'b1;
      o_cursor_blink_enable <= 1'b1;
      o_cursor_blink_period <= RESET_CURSOR_BLINK_PERIOD;
      o_attr_blink_period   <= RESET_ATTR_BLINK_PERIOD;
      o_cursor_col          <= 7'd10;
      o_cursor_row          <= 5'd12;
      o_cursor_vertical     <= 1'b0;
      o_cursor_mode         <= 2'd0;
      o_cursor_template     <= 3'd4;
      o_shadow_dirty        <= 1'b0;
      o_frame_counter       <= 16'd0;
      o_cursor_cell         <= 16'h0720;

      shadow_cursor_visible      <= 1'b1;
      shadow_cursor_blink_enable <= 1'b1;
      shadow_cursor_blink_period <= RESET_CURSOR_BLINK_PERIOD;
      shadow_attr_blink_period   <= RESET_ATTR_BLINK_PERIOD;
      shadow_cursor_col          <= 7'd10;
      shadow_cursor_row          <= 5'd12;
      shadow_cursor_vertical     <= 1'b0;
      shadow_cursor_mode         <= 2'd0;
      shadow_cursor_template     <= 3'd4;
    end else begin
      o_cursor_cell <= cursor_cell_rd;

      if (i_ctrl_wr_en) begin
        case (i_ctrl_wr_addr)
          CTRL_ADDR_CURSOR_FLAGS: begin
            shadow_cursor_visible      <= i_ctrl_wr_data[0];
            shadow_cursor_blink_enable <= i_ctrl_wr_data[1];
            o_shadow_dirty             <= 1'b1;
          end
          CTRL_ADDR_CURSOR_BLINK_PERIOD: begin
            shadow_cursor_blink_period <= i_ctrl_wr_data;
            o_shadow_dirty             <= 1'b1;
          end
          CTRL_ADDR_ATTR_BLINK_PERIOD: begin
            shadow_attr_blink_period <= i_ctrl_wr_data;
            o_shadow_dirty           <= 1'b1;
          end
          CTRL_ADDR_CURSOR_SHAPE: begin
            shadow_cursor_mode     <= i_ctrl_wr_data[1:0];
            shadow_cursor_vertical <= i_ctrl_wr_data[2];
            shadow_cursor_template <= i_ctrl_wr_data[6:4];
            o_shadow_dirty         <= 1'b1;
          end
          CTRL_ADDR_CURSOR_COL: begin
            shadow_cursor_col <= i_ctrl_wr_data[6:0];
            o_shadow_dirty    <= 1'b1;
          end
          CTRL_ADDR_CURSOR_ROW: begin
            shadow_cursor_row <= i_ctrl_wr_data[4:0];
            o_shadow_dirty    <= 1'b1;
          end
          default: begin
          end
        endcase
      end

      if (i_frame_commit) begin
        o_frame_counter <= o_frame_counter + 16'd1;
        if (o_shadow_dirty) begin
          o_cursor_visible      <= shadow_cursor_visible;
          o_cursor_blink_enable <= shadow_cursor_blink_enable;
          o_cursor_blink_period <= shadow_cursor_blink_period;
          o_attr_blink_period   <= shadow_attr_blink_period;
          o_cursor_col          <= shadow_cursor_col;
          o_cursor_row          <= shadow_cursor_row;
          o_cursor_vertical     <= shadow_cursor_vertical;
          o_cursor_mode         <= shadow_cursor_mode;
          o_cursor_template     <= shadow_cursor_template;
          o_shadow_dirty        <= 1'b0;
        end
      end
    end
  end

endmodule
