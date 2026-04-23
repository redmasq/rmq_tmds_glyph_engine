module tang_primer_uart_keypad_bridge #(
  parameter integer CLK_HZ = 74250000,
  parameter integer BAUD_RATE = 115200,
  parameter integer TEXT_COLS = 80,
  parameter integer TEXT_ROWS = 25
)(
  input  wire        i_clk,
  input  wire        i_reset,
  input  wire        i_init_done,
  input  wire        i_uart_rx,
  input  wire        i_snoop_wr_en,
  input  wire [10:0] i_snoop_wr_addr,
  input  wire [15:0] i_snoop_wr_data,
  input  wire        i_snoop_ctrl_wr_en,
  input  wire [2:0]  i_snoop_ctrl_wr_addr,
  input  wire [15:0] i_snoop_ctrl_wr_data,

  output reg         o_demo_enable,
  output reg         o_wr_en,
  output reg  [10:0] o_wr_addr,
  output reg  [15:0] o_wr_data,
  output reg         o_ctrl_wr_en,
  output reg  [2:0]  o_ctrl_wr_addr,
  output reg  [15:0] o_ctrl_wr_data
);

  localparam [2:0] CTRL_ADDR_CURSOR_FLAGS        = 3'd0;
  localparam [2:0] CTRL_ADDR_CURSOR_BLINK_PERIOD = 3'd1;
  localparam [2:0] CTRL_ADDR_ATTR_BLINK_PERIOD   = 3'd2;
  localparam [2:0] CTRL_ADDR_CURSOR_SHAPE        = 3'd3;
  localparam [2:0] CTRL_ADDR_CURSOR_COL          = 3'd4;
  localparam [2:0] CTRL_ADDR_CURSOR_ROW          = 3'd5;

  localparam [6:0] MAX_CURSOR_COL = TEXT_COLS - 1;
  localparam [4:0] MAX_CURSOR_ROW = TEXT_ROWS - 1;
  localparam [15:0] RESET_CURSOR_BLINK_PERIOD = 16'd32;
  localparam [15:0] RESET_ATTR_BLINK_PERIOD = 16'd64;
  localparam [6:0] RESET_CURSOR_COL = 7'd10;
  localparam [4:0] RESET_CURSOR_ROW = 5'd12;
  localparam [2:0] RESET_CURSOR_TEMPLATE = 3'd4;
  localparam [1:0] MANUAL_CURSOR_MODE = 2'd0;

  localparam [2:0] SYNC_CURSOR_FLAGS        = 3'd0;
  localparam [2:0] SYNC_CURSOR_BLINK_PERIOD = 3'd1;
  localparam [2:0] SYNC_ATTR_BLINK_PERIOD   = 3'd2;
  localparam [2:0] SYNC_CURSOR_SHAPE        = 3'd3;
  localparam [2:0] SYNC_CURSOR_COL          = 3'd4;
  localparam [2:0] SYNC_CURSOR_ROW          = 3'd5;

  reg        live_cursor_visible;
  reg        live_cursor_blink_enable;
  reg [15:0] live_cursor_blink_period;
  reg [15:0] live_attr_blink_period;
  reg [6:0]  live_cursor_col;
  reg [4:0]  live_cursor_row;
  reg        live_cursor_vertical;
  reg [1:0]  live_cursor_mode;
  reg [2:0]  live_cursor_template;

  reg        manual_cursor_visible;
  reg        manual_cursor_blink_enable;
  reg [15:0] manual_cursor_blink_period;
  reg [15:0] manual_attr_blink_period;
  reg [6:0]  manual_cursor_col;
  reg [4:0]  manual_cursor_row;
  reg        manual_cursor_vertical;
  reg [1:0]  manual_cursor_mode;
  reg [2:0]  manual_cursor_template;

  reg [15:0] shadow_cell_value;
  reg        manual_sync_active;
  reg [2:0]  manual_sync_idx;

  wire [7:0] rx_data;
  wire       rx_valid;
  wire [7:0] cmd = uppercase_ascii(rx_data);
  wire [6:0] active_cursor_col = o_demo_enable ? live_cursor_col : manual_cursor_col;
  wire [4:0] active_cursor_row = o_demo_enable ? live_cursor_row : manual_cursor_row;
  wire [10:0] cursor_addr = cell_addr(active_cursor_col, active_cursor_row);
  wire [15:0] cursor_cell = shadow_cell_value;

  function [7:0] uppercase_ascii;
    input [7:0] value;
    begin
      if ((value >= "a") && (value <= "z"))
        uppercase_ascii = value - 8'd32;
      else
        uppercase_ascii = value;
    end
  endfunction

  function [10:0] cell_addr;
    input [6:0] col;
    input [4:0] row;
    begin
      cell_addr = ({6'd0, row} * TEXT_COLS) + {4'd0, col};
    end
  endfunction

  function [15:0] cursor_shape_data;
    input [2:0] template;
    input       vertical;
    input [1:0] mode;
    begin
      cursor_shape_data = {10'd0, template, vertical, mode};
    end
  endfunction

  function [15:0] cursor_flags_data;
    input visible;
    input blink_enable;
    begin
      cursor_flags_data = {14'd0, blink_enable, visible};
    end
  endfunction

  function [15:0] bump_char;
    input [15:0] cell_word;
    input        increment;
    begin
      bump_char = {
        cell_word[15:8],
        increment ? (cell_word[7:0] + 8'd1) : (cell_word[7:0] - 8'd1)
      };
    end
  endfunction

  function [15:0] bump_attr;
    input [15:0] cell_word;
    input        increment;
    reg [6:0] next_attr;
    begin
      next_attr = increment ? (cell_word[14:8] + 7'd1) : (cell_word[14:8] - 7'd1);
      bump_attr = {cell_word[15], next_attr, cell_word[7:0]};
    end
  endfunction

  function [15:0] toggle_blink_attr;
    input [15:0] cell_word;
    begin
      toggle_blink_attr = {cell_word[15:8] ^ 8'h80, cell_word[7:0]};
    end
  endfunction

  function [15:0] slower_period;
    input [15:0] period;
    begin
      if (period >= 16'd32768)
        slower_period = 16'd65535;
      else
        slower_period = period << 1;
    end
  endfunction

  function [15:0] faster_period;
    input [15:0] period;
    begin
      if (period <= 16'd2)
        faster_period = 16'd1;
      else
        faster_period = period >> 1;
    end
  endfunction

  function [2:0] clamp_manual_template;
    input [2:0] template;
    begin
      if (template == 3'd0)
        clamp_manual_template = 3'd1;
      else
        clamp_manual_template = template;
    end
  endfunction

  uart_rx #(
    .CLK_HZ(CLK_HZ),
    .BAUD_RATE(BAUD_RATE)
  ) u_uart_rx (
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_rx(i_uart_rx),
    .o_data(rx_data),
    .o_valid(rx_valid)
  );

  always @(posedge i_clk) begin
    if (i_reset) begin
      live_cursor_visible <= 1'b1;
      live_cursor_blink_enable <= 1'b1;
      live_cursor_blink_period <= RESET_CURSOR_BLINK_PERIOD;
      live_attr_blink_period <= RESET_ATTR_BLINK_PERIOD;
      live_cursor_col <= RESET_CURSOR_COL;
      live_cursor_row <= RESET_CURSOR_ROW;
      live_cursor_vertical <= 1'b0;
      live_cursor_mode <= MANUAL_CURSOR_MODE;
      live_cursor_template <= RESET_CURSOR_TEMPLATE;

      manual_cursor_visible <= 1'b1;
      manual_cursor_blink_enable <= 1'b1;
      manual_cursor_blink_period <= RESET_CURSOR_BLINK_PERIOD;
      manual_attr_blink_period <= RESET_ATTR_BLINK_PERIOD;
      manual_cursor_col <= RESET_CURSOR_COL;
      manual_cursor_row <= RESET_CURSOR_ROW;
      manual_cursor_vertical <= 1'b0;
      manual_cursor_mode <= MANUAL_CURSOR_MODE;
      manual_cursor_template <= RESET_CURSOR_TEMPLATE;

      shadow_cell_value <= 16'h0720;
      manual_sync_active <= 1'b0;
      manual_sync_idx <= SYNC_CURSOR_FLAGS;

      o_demo_enable <= 1'b1;
      o_wr_en <= 1'b0;
      o_wr_addr <= 11'd0;
      o_wr_data <= 16'h0720;
      o_ctrl_wr_en <= 1'b0;
      o_ctrl_wr_addr <= 3'd0;
      o_ctrl_wr_data <= 16'd0;
    end else begin
      o_wr_en <= 1'b0;
      o_ctrl_wr_en <= 1'b0;

      if (i_snoop_wr_en && (i_snoop_wr_addr == cursor_addr))
        shadow_cell_value <= i_snoop_wr_data;

      if (i_snoop_ctrl_wr_en) begin
        case (i_snoop_ctrl_wr_addr)
          CTRL_ADDR_CURSOR_FLAGS: begin
            live_cursor_visible <= i_snoop_ctrl_wr_data[0];
            live_cursor_blink_enable <= i_snoop_ctrl_wr_data[1];
          end
          CTRL_ADDR_CURSOR_BLINK_PERIOD: begin
            live_cursor_blink_period <= i_snoop_ctrl_wr_data;
          end
          CTRL_ADDR_ATTR_BLINK_PERIOD: begin
            live_attr_blink_period <= i_snoop_ctrl_wr_data;
          end
          CTRL_ADDR_CURSOR_SHAPE: begin
            live_cursor_mode <= i_snoop_ctrl_wr_data[1:0];
            live_cursor_vertical <= i_snoop_ctrl_wr_data[2];
            live_cursor_template <= i_snoop_ctrl_wr_data[6:4];
          end
          CTRL_ADDR_CURSOR_COL: begin
            live_cursor_col <= i_snoop_ctrl_wr_data[6:0];
          end
          CTRL_ADDR_CURSOR_ROW: begin
            live_cursor_row <= i_snoop_ctrl_wr_data[4:0];
          end
          default: begin
          end
        endcase
      end

      if (manual_sync_active) begin
        o_ctrl_wr_en <= 1'b1;
        o_ctrl_wr_addr <= manual_sync_idx;

        case (manual_sync_idx)
          SYNC_CURSOR_FLAGS: begin
            o_ctrl_wr_data <= cursor_flags_data(manual_cursor_visible, manual_cursor_blink_enable);
          end
          SYNC_CURSOR_BLINK_PERIOD: begin
            o_ctrl_wr_data <= manual_cursor_blink_period;
          end
          SYNC_ATTR_BLINK_PERIOD: begin
            o_ctrl_wr_data <= manual_attr_blink_period;
          end
          SYNC_CURSOR_SHAPE: begin
            o_ctrl_wr_data <= cursor_shape_data(
              manual_cursor_template,
              manual_cursor_vertical,
              manual_cursor_mode
            );
          end
          SYNC_CURSOR_COL: begin
            o_ctrl_wr_data <= {9'd0, manual_cursor_col};
          end
          default: begin
            o_ctrl_wr_data <= {11'd0, manual_cursor_row};
          end
        endcase

        if (manual_sync_idx == SYNC_CURSOR_ROW) begin
          manual_sync_active <= 1'b0;
          manual_sync_idx <= SYNC_CURSOR_FLAGS;
        end else begin
          manual_sync_idx <= manual_sync_idx + 3'd1;
        end
      end else if (rx_valid && i_init_done) begin
        if (cmd == "B") begin
          if (o_demo_enable) begin
            manual_cursor_visible <= 1'b1;
            manual_cursor_blink_enable <= live_cursor_blink_enable;
            manual_cursor_blink_period <= live_cursor_blink_period;
            manual_attr_blink_period <= live_attr_blink_period;
            manual_cursor_col <= live_cursor_col;
            manual_cursor_row <= live_cursor_row;
            manual_cursor_vertical <= live_cursor_vertical;
            manual_cursor_mode <= MANUAL_CURSOR_MODE;
            manual_cursor_template <= clamp_manual_template(live_cursor_template);

            manual_sync_active <= 1'b1;
            manual_sync_idx <= SYNC_CURSOR_FLAGS;
            o_demo_enable <= 1'b0;
          end else begin
            o_demo_enable <= 1'b1;
          end
        end else if (!o_demo_enable) begin
          case (cmd)
            "2": begin
              if (manual_cursor_row != 5'd0) begin
                manual_cursor_row <= manual_cursor_row - 5'd1;
                shadow_cell_value <= 16'h0720;
                o_ctrl_wr_en <= 1'b1;
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_ROW;
                o_ctrl_wr_data <= {11'd0, manual_cursor_row - 5'd1};
              end
            end
            "8": begin
              if (manual_cursor_row != MAX_CURSOR_ROW) begin
                manual_cursor_row <= manual_cursor_row + 5'd1;
                shadow_cell_value <= 16'h0720;
                o_ctrl_wr_en <= 1'b1;
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_ROW;
                o_ctrl_wr_data <= {11'd0, manual_cursor_row + 5'd1};
              end
            end
            "4": begin
              if (manual_cursor_col != 7'd0) begin
                manual_cursor_col <= manual_cursor_col - 7'd1;
                shadow_cell_value <= 16'h0720;
                o_ctrl_wr_en <= 1'b1;
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_COL;
                o_ctrl_wr_data <= {9'd0, manual_cursor_col - 7'd1};
              end
            end
            "6": begin
              if (manual_cursor_col != MAX_CURSOR_COL) begin
                manual_cursor_col <= manual_cursor_col + 7'd1;
                shadow_cell_value <= 16'h0720;
                o_ctrl_wr_en <= 1'b1;
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_COL;
                o_ctrl_wr_data <= {9'd0, manual_cursor_col + 7'd1};
              end
            end
            "A": begin
              manual_cursor_vertical <= ~manual_cursor_vertical;
              manual_cursor_mode <= MANUAL_CURSOR_MODE;
              o_ctrl_wr_en <= 1'b1;
              o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_SHAPE;
              o_ctrl_wr_data <= cursor_shape_data(
                manual_cursor_template,
                ~manual_cursor_vertical,
                MANUAL_CURSOR_MODE
              );
            end
            "C": begin
              if (manual_cursor_template != 3'd7) begin
                manual_cursor_template <= manual_cursor_template + 3'd1;
                manual_cursor_mode <= MANUAL_CURSOR_MODE;
                o_ctrl_wr_en <= 1'b1;
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_SHAPE;
                o_ctrl_wr_data <= cursor_shape_data(
                  manual_cursor_template + 3'd1,
                  manual_cursor_vertical,
                  MANUAL_CURSOR_MODE
                );
              end
            end
            "D": begin
              if (manual_cursor_template != 3'd1) begin
                manual_cursor_template <= manual_cursor_template - 3'd1;
                manual_cursor_mode <= MANUAL_CURSOR_MODE;
                o_ctrl_wr_en <= 1'b1;
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_SHAPE;
                o_ctrl_wr_data <= cursor_shape_data(
                  manual_cursor_template - 3'd1,
                  manual_cursor_vertical,
                  MANUAL_CURSOR_MODE
                );
              end
            end
            "*": begin
                manual_cursor_template <= 3'd7
                manual_cursor_mode <= MANUAL_CURSOR_MODE;
                o_ctrl_wr_en <= 1'b1;
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_SHAPE;
                o_ctrl_wr_data <= cursor_shape_data(
                  manual_cursor_template,
                  manual_cursor_vertical,
                  MANUAL_CURSOR_MODE
                );
            end
            "E": begin
              manual_cursor_blink_period <= faster_period(manual_cursor_blink_period);
              o_ctrl_wr_en <= 1'b1;
              o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_BLINK_PERIOD;
              o_ctrl_wr_data <= faster_period(manual_cursor_blink_period);
            end
            "F": begin
              manual_cursor_blink_period <= slower_period(manual_cursor_blink_period);
              o_ctrl_wr_en <= 1'b1;
              o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_BLINK_PERIOD;
              o_ctrl_wr_data <= slower_period(manual_cursor_blink_period);
            end
            "1": begin
              shadow_cell_value <= bump_char(cursor_cell, 1'b0);
              o_wr_en <= 1'b1;
              o_wr_addr <= cursor_addr;
              o_wr_data <= bump_char(cursor_cell, 1'b0);
            end
            "3": begin
              shadow_cell_value <= bump_char(cursor_cell, 1'b1);
              o_wr_en <= 1'b1;
              o_wr_addr <= cursor_addr;
              o_wr_data <= bump_char(cursor_cell, 1'b1);
            end
            "5": begin
              shadow_cell_value <= toggle_blink_attr(cursor_cell);
              o_wr_en <= 1'b1;
              o_wr_addr <= cursor_addr;
              o_wr_data <= toggle_blink_attr(cursor_cell);
            end
            "7": begin
              shadow_cell_value <= bump_attr(cursor_cell, 1'b0);
              o_wr_en <= 1'b1;
              o_wr_addr <= cursor_addr;
              o_wr_data <= bump_attr(cursor_cell, 1'b0);
            end
            "9": begin
              shadow_cell_value <= bump_attr(cursor_cell, 1'b1);
              o_wr_en <= 1'b1;
              o_wr_addr <= cursor_addr;
              o_wr_data <= bump_attr(cursor_cell, 1'b1);
            end
            default: begin
            end
          endcase
        end
      end
    end
  end

endmodule
