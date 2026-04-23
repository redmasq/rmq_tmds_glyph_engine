// Shared 4x4 keypad matrix scanner. The host drives one column at a time and
// samples four row inputs after holding that drive level long enough to settle.
//
// The exported debug row/column vectors use the existing active-low one-hot
// convention consumed by the renderer: idle is 4'b1111 and an asserted logical
// row/column drives exactly one bit low.
module keypad_matrix_scanner #(
  parameter integer SCAN_DIV_WIDTH = 16,
  parameter [SCAN_DIV_WIDTH-1:0] SCAN_HOLD_TICKS = 16'd4096,
  parameter integer HEARTBEAT_TICKS = 27000000,
  parameter integer ROW_MAP_0 = 0,
  parameter integer ROW_MAP_1 = 1,
  parameter integer ROW_MAP_2 = 2,
  parameter integer ROW_MAP_3 = 3,
  parameter integer COL_MAP_0 = 0,
  parameter integer COL_MAP_1 = 1,
  parameter integer COL_MAP_2 = 2,
  parameter integer COL_MAP_3 = 3,
  parameter [3:0] ROW_ACTIVE_LOW_MASK = 4'b1111,
  parameter [3:0] COL_ACTIVE_LOW_MASK = 4'b1111,
  parameter [3:0] ROW_VALID_MASK = 4'b1111,
  parameter [3:0] COL_VALID_MASK = 4'b1111
)(
  input  wire       i_clk,
  input  wire       i_reset,
  input  wire [3:0] i_raw_rows,

  output wire [3:0] o_raw_col_drive,
  output wire [3:0] o_debug_raw_rows,
  output wire       o_unused_debug_pmod,
  output reg        o_debug_any_active,
  output reg  [3:0] o_debug_row_bits,
  output reg  [3:0] o_debug_col_bits,
  output reg        o_debug_heartbeat,
  output wire [3:0] o_debug_row_valid,
  output wire [3:0] o_debug_col_valid
);

  localparam integer HEARTBEAT_WIDTH = (HEARTBEAT_TICKS <= 1) ? 1 : $clog2(HEARTBEAT_TICKS);

  reg [SCAN_DIV_WIDTH-1:0] scan_divider;
  reg [HEARTBEAT_WIDTH-1:0] heartbeat_divider;

  wire phase_tick = (scan_divider == SCAN_HOLD_TICKS);
  wire [3:0] raw_col_active = 4'b1111;
  wire [3:0] raw_col_drive =
    (COL_ACTIVE_LOW_MASK & ~raw_col_active) |
    (~COL_ACTIVE_LOW_MASK & raw_col_active);
  wire [3:0] raw_row_active =
    (ROW_ACTIVE_LOW_MASK & ~i_raw_rows) |
    (~ROW_ACTIVE_LOW_MASK & i_raw_rows);
  wire raw_row_any = |raw_row_active;
  wire raw_row_onehot =
    (raw_row_active == 4'b0001) ||
    (raw_row_active == 4'b0010) ||
    (raw_row_active == 4'b0100) ||
    (raw_row_active == 4'b1000);
  wire [3:0] logical_row_active = {
    raw_row_active[ROW_MAP_3],
    raw_row_active[ROW_MAP_2],
    raw_row_active[ROW_MAP_1],
    raw_row_active[ROW_MAP_0]
  };
  wire [3:0] logical_col_active = {
    raw_col_active[COL_MAP_3],
    raw_col_active[COL_MAP_2],
    raw_col_active[COL_MAP_1],
    raw_col_active[COL_MAP_0]
  };

  assign o_raw_col_drive = raw_col_drive;
  assign o_debug_raw_rows = i_raw_rows;
  assign o_unused_debug_pmod = &(i_raw_rows & raw_col_drive);
  assign o_debug_row_valid = ROW_VALID_MASK;
  assign o_debug_col_valid = COL_VALID_MASK;

  always @(posedge i_clk) begin
    if (i_reset) begin
      scan_divider       <= {SCAN_DIV_WIDTH{1'b0}};
      heartbeat_divider  <= {HEARTBEAT_WIDTH{1'b0}};
      o_debug_any_active <= 1'b0;
      o_debug_row_bits   <= 4'b1111;
      o_debug_col_bits   <= 4'b1111;
      o_debug_heartbeat  <= 1'b0;
    end else begin
      if (heartbeat_divider == (HEARTBEAT_TICKS - 1)) begin
        heartbeat_divider <= {HEARTBEAT_WIDTH{1'b0}};
        o_debug_heartbeat <= ~o_debug_heartbeat;
      end else begin
        heartbeat_divider <= heartbeat_divider + {{(HEARTBEAT_WIDTH-1){1'b0}}, 1'b1};
      end

      if (!phase_tick) begin
        scan_divider <= scan_divider + {{(SCAN_DIV_WIDTH-1){1'b0}}, 1'b1};
      end else begin
        scan_divider <= {SCAN_DIV_WIDTH{1'b0}};

        o_debug_any_active <= raw_row_any;
        o_debug_row_bits <= ~logical_row_active;
        o_debug_col_bits <= raw_row_any ? ~logical_col_active : 4'b1111;
      end
    end
  end

endmodule
