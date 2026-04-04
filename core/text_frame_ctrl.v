module text_frame_ctrl (
  input  wire        i_clk,
  input  wire        i_reset,
  input  wire        i_frame_commit,

  input  wire        i_ctrl_wr_en,
  input  wire [2:0]  i_ctrl_wr_addr,
  input  wire [15:0] i_ctrl_wr_data,

  output reg         o_active_cursor_visible,
  output reg         o_active_cursor_blink_enable,
  output reg  [15:0] o_active_cursor_blink_period,
  output reg  [15:0] o_active_attr_blink_period,
  output reg  [6:0]  o_active_cursor_col,
  output reg  [4:0]  o_active_cursor_row,
  output reg         o_active_cursor_vertical,
  output reg  [1:0]  o_active_cursor_mode,
  output reg  [2:0]  o_active_cursor_template,

  output reg         o_shadow_dirty,
  output reg  [15:0] o_frame_counter,
  output reg  [15:0] o_cursor_blink_counter,
  output reg  [15:0] o_attr_blink_counter
);

  localparam [2:0] CTRL_ADDR_CURSOR_FLAGS        = 3'd0;
  localparam [2:0] CTRL_ADDR_CURSOR_BLINK_PERIOD = 3'd1;
  localparam [2:0] CTRL_ADDR_ATTR_BLINK_PERIOD   = 3'd2;
  localparam [2:0] CTRL_ADDR_CURSOR_SHAPE        = 3'd3;
  localparam [2:0] CTRL_ADDR_CURSOR_COL          = 3'd4;
  localparam [2:0] CTRL_ADDR_CURSOR_ROW          = 3'd5;

  // These defaults establish the frame-domain timing contract now; later
  // tickets can consume the committed values for actual cursor/attribute
  // rendering behavior without changing how they commit.
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

  wire        commit_cursor_visible      = o_shadow_dirty ? shadow_cursor_visible      : o_active_cursor_visible;
  wire        commit_cursor_blink_enable = o_shadow_dirty ? shadow_cursor_blink_enable : o_active_cursor_blink_enable;
  wire [15:0] commit_cursor_blink_period = o_shadow_dirty ? shadow_cursor_blink_period : o_active_cursor_blink_period;
  wire [15:0] commit_attr_blink_period   = o_shadow_dirty ? shadow_attr_blink_period   : o_active_attr_blink_period;
  wire [6:0]  commit_cursor_col          = o_shadow_dirty ? shadow_cursor_col          : o_active_cursor_col;
  wire [4:0]  commit_cursor_row          = o_shadow_dirty ? shadow_cursor_row          : o_active_cursor_row;
  wire        commit_cursor_vertical     = o_shadow_dirty ? shadow_cursor_vertical     : o_active_cursor_vertical;
  wire [1:0]  commit_cursor_mode         = o_shadow_dirty ? shadow_cursor_mode         : o_active_cursor_mode;
  wire [2:0]  commit_cursor_template     = o_shadow_dirty ? shadow_cursor_template     : o_active_cursor_template;

  always @(posedge i_clk) begin
    if (i_reset) begin
      o_active_cursor_visible      <= 1'b1;
      o_active_cursor_blink_enable <= 1'b1;
      o_active_cursor_blink_period <= RESET_CURSOR_BLINK_PERIOD;
      o_active_attr_blink_period   <= RESET_ATTR_BLINK_PERIOD;
      o_active_cursor_col          <= 7'd0;
      o_active_cursor_row          <= 5'd0;
      o_active_cursor_vertical     <= 1'b0;
      o_active_cursor_mode         <= 2'd0;
      o_active_cursor_template     <= 3'd7;

      shadow_cursor_visible        <= 1'b1;
      shadow_cursor_blink_enable   <= 1'b1;
      shadow_cursor_blink_period   <= RESET_CURSOR_BLINK_PERIOD;
      shadow_attr_blink_period     <= RESET_ATTR_BLINK_PERIOD;
      shadow_cursor_col            <= 7'd0;
      shadow_cursor_row            <= 5'd0;
      shadow_cursor_vertical       <= 1'b0;
      shadow_cursor_mode           <= 2'd0;
      shadow_cursor_template       <= 3'd7;

      o_shadow_dirty               <= 1'b0;
      o_frame_counter              <= 16'd0;
      o_cursor_blink_counter       <= 16'd0;
      o_attr_blink_counter         <= 16'd0;
    end else begin
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
          o_active_cursor_visible      <= shadow_cursor_visible;
          o_active_cursor_blink_enable <= shadow_cursor_blink_enable;
          o_active_cursor_blink_period <= shadow_cursor_blink_period;
          o_active_attr_blink_period   <= shadow_attr_blink_period;
          o_active_cursor_col          <= shadow_cursor_col;
          o_active_cursor_row          <= shadow_cursor_row;
          o_active_cursor_vertical     <= shadow_cursor_vertical;
          o_active_cursor_mode         <= shadow_cursor_mode;
          o_active_cursor_template     <= shadow_cursor_template;
          o_shadow_dirty               <= 1'b0;
        end

        if (commit_cursor_blink_period <= 16'd1)
          o_cursor_blink_counter <= 16'd0;
        else if (o_cursor_blink_counter == (commit_cursor_blink_period - 16'd1))
          o_cursor_blink_counter <= 16'd0;
        else
          o_cursor_blink_counter <= o_cursor_blink_counter + 16'd1;

        if (commit_attr_blink_period <= 16'd1)
          o_attr_blink_counter <= 16'd0;
        else if (o_attr_blink_counter == (commit_attr_blink_period - 16'd1))
          o_attr_blink_counter <= 16'd0;
        else
          o_attr_blink_counter <= o_attr_blink_counter + 16'd1;
      end
    end
  end

endmodule
