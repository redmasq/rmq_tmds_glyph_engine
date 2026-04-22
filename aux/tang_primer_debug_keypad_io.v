// Tang Primer-local keypad/debug adapter. This keeps board-specific PMOD
// electrical details out of the shared scanner and core-facing display path.
//
// Temporary experiment path for the Tang Primer bring-up. The shared scanner
// stays column-driven / row-sampled while this adapter binds those logical
// groups onto the physical PMOD pins.
module tang_primer_debug_keypad_io (
  input  wire       i_clk,
  input  wire       i_reset,
  input  wire       i_target_next_n,
  input  wire       i_rotate_next_n,
  input  wire       i_pattern_next_n,
  inout  wire [7:0] io_debug_pmod_pins,

  output wire       o_unused_debug_pmod,
  output wire       o_debug_any_active,
  output wire [3:0] o_debug_row_bits,
  output wire [3:0] o_debug_col_bits,
  output wire [3:0] o_debug_row_valid,
  output wire [3:0] o_debug_col_valid,
  output wire [3:0] o_debug_raw_rows,
  output wire [3:0] o_debug_raw_col_drive,
  output wire [7:0] o_debug_pmod_bits,
  output wire [7:0] o_debug_pmod_col_mask,
  output wire [4:0] o_debug_target_slot,
  output wire [3:0] o_debug_col_offset,
  output wire [2:0] o_debug_pattern_index,
  output wire [5:0] o_debug_row_pins
);

  localparam integer TARGET_SLOT_COUNT = 17;

  reg  [4:0] target_slot;
  reg  [2:0] col_offset;
  reg        no_bits_selected;
  reg  [2:0] pattern_index;
  reg        target_next_d;
  reg        rotate_next_d;
  reg        pattern_next_d;

  wire target_next_pressed = target_next_d && !i_target_next_n;
  wire rotate_next_pressed = rotate_next_d && !i_rotate_next_n;
  wire pattern_next_pressed = pattern_next_d && !i_pattern_next_n;

  reg  [7:0] base_col_mask;
  wire [3:0] col_offset_u4 = {1'b0, col_offset};
  wire [3:0] rotate_back = 4'd8 - col_offset_u4;
  wire [7:0] rotated_col_mask =
    (base_col_mask << col_offset) |
    (base_col_mask >> rotate_back[2:0]);
  wire [7:0] raw_col_mask = no_bits_selected ? 8'h00 : rotated_col_mask;
  wire [7:0] sampled_pmod = io_debug_pmod_pins;
  wire [3:0] raw_rows = {
    sampled_pmod[(col_offset + 3'd7) & 3'd7],
    sampled_pmod[(col_offset + 3'd6) & 3'd7],
    sampled_pmod[(col_offset + 3'd5) & 3'd7],
    sampled_pmod[(col_offset + 3'd4) & 3'd7]
  };
  wire [3:0] raw_col_drive;
  wire debug_heartbeat;
  wire [2:0] col_idx0 = col_offset + 3'd0;
  wire [2:0] col_idx1 = col_offset + 3'd1;
  wire [2:0] col_idx2 = col_offset + 3'd2;
  wire [2:0] col_idx3 = col_offset + 3'd3;
  wire [7:0] pmod_drive;

  // Primer-specific wiring adaptation for bring-up: rotate a 4-pin column
  // window across the 8 PMOD signals and treat the opposite 4-pin window as
  // rows so the board owner can discover the true connector ordering.
  assign io_debug_pmod_pins = pmod_drive;
  assign o_debug_pmod_bits = sampled_pmod;
  assign o_debug_pmod_col_mask = raw_col_mask;
  assign o_debug_target_slot = target_slot;
  assign o_debug_col_offset = no_bits_selected ? 4'h8 : {1'b0, col_offset};
  assign o_debug_pattern_index = pattern_index;
  assign pmod_drive[0] =
    no_bits_selected ? 1'bz :
    (col_idx0 == 3'd0) ? raw_col_drive[0] :
    (col_idx1 == 3'd0) ? raw_col_drive[1] :
    (col_idx2 == 3'd0) ? raw_col_drive[2] :
    (col_idx3 == 3'd0) ? raw_col_drive[3] : 1'bz;
  assign pmod_drive[1] =
    no_bits_selected ? 1'bz :
    (col_idx0 == 3'd1) ? raw_col_drive[0] :
    (col_idx1 == 3'd1) ? raw_col_drive[1] :
    (col_idx2 == 3'd1) ? raw_col_drive[2] :
    (col_idx3 == 3'd1) ? raw_col_drive[3] : 1'bz;
  assign pmod_drive[2] =
    no_bits_selected ? 1'bz :
    (col_idx0 == 3'd2) ? raw_col_drive[0] :
    (col_idx1 == 3'd2) ? raw_col_drive[1] :
    (col_idx2 == 3'd2) ? raw_col_drive[2] :
    (col_idx3 == 3'd2) ? raw_col_drive[3] : 1'bz;
  assign pmod_drive[3] =
    no_bits_selected ? 1'bz :
    (col_idx0 == 3'd3) ? raw_col_drive[0] :
    (col_idx1 == 3'd3) ? raw_col_drive[1] :
    (col_idx2 == 3'd3) ? raw_col_drive[2] :
    (col_idx3 == 3'd3) ? raw_col_drive[3] : 1'bz;
  assign pmod_drive[4] =
    no_bits_selected ? 1'bz :
    (col_idx0 == 3'd4) ? raw_col_drive[0] :
    (col_idx1 == 3'd4) ? raw_col_drive[1] :
    (col_idx2 == 3'd4) ? raw_col_drive[2] :
    (col_idx3 == 3'd4) ? raw_col_drive[3] : 1'bz;
  assign pmod_drive[5] =
    no_bits_selected ? 1'bz :
    (col_idx0 == 3'd5) ? raw_col_drive[0] :
    (col_idx1 == 3'd5) ? raw_col_drive[1] :
    (col_idx2 == 3'd5) ? raw_col_drive[2] :
    (col_idx3 == 3'd5) ? raw_col_drive[3] : 1'bz;
  assign pmod_drive[6] =
    no_bits_selected ? 1'bz :
    (col_idx0 == 3'd6) ? raw_col_drive[0] :
    (col_idx1 == 3'd6) ? raw_col_drive[1] :
    (col_idx2 == 3'd6) ? raw_col_drive[2] :
    (col_idx3 == 3'd6) ? raw_col_drive[3] : 1'bz;
  assign pmod_drive[7] =
    no_bits_selected ? 1'bz :
    (col_idx0 == 3'd7) ? raw_col_drive[0] :
    (col_idx1 == 3'd7) ? raw_col_drive[1] :
    (col_idx2 == 3'd7) ? raw_col_drive[2] :
    (col_idx3 == 3'd7) ? raw_col_drive[3] : 1'bz;

  // Tang Primer local bring-up hook: mirror the four row inputs onto the
  // nearby auxiliary pins the board owner is probing as 0..3. Pin 4 gets a
  // slow heartbeat so the scanner stays visibly alive during bring-up, and
  // pin 5 remains parked high.
  assign o_debug_row_pins = {1'b1, debug_heartbeat, o_debug_row_bits};

  always @(*) begin
    case (pattern_index)
      3'd0: base_col_mask = 8'b0000_0001; // *.......
      3'd1: base_col_mask = 8'b0000_1111; // ****____
      3'd2: base_col_mask = 8'b0011_0011; // **__**__
      3'd3: base_col_mask = 8'b0101_0101; // *_*_*_*_
      3'd4: base_col_mask = 8'b0001_0111; // ***_*___
      3'd5: base_col_mask = 8'b0001_1101; // *_***___
      default: base_col_mask = 8'b0000_0001;
    endcase
  end

  always @(posedge i_clk) begin
    if (i_reset) begin
      target_slot     <= 5'd0;
      col_offset     <= 3'd0;
      no_bits_selected <= 1'b0;
      pattern_index  <= 3'd0;
      target_next_d  <= 1'b1;
      rotate_next_d  <= 1'b1;
      pattern_next_d <= 1'b1;
    end else begin
      target_next_d <= i_target_next_n;
      rotate_next_d <= i_rotate_next_n;
      pattern_next_d <= i_pattern_next_n;

      if (target_next_pressed) begin
        if (target_slot == TARGET_SLOT_COUNT - 1) begin
          target_slot <= 5'd0;
        end else begin
          target_slot <= target_slot + 5'd1;
        end
      end

      if (rotate_next_pressed) begin
        if (!no_bits_selected) begin
          if (col_offset == 3'd7) begin
            no_bits_selected <= 1'b1;
          end else begin
            col_offset <= col_offset + 3'd1;
          end
        end else begin
          no_bits_selected <= 1'b0;
          col_offset <= 3'd0;
        end
      end

      if (pattern_next_pressed) begin
        if (pattern_index == 3'd5) begin
          pattern_index <= 3'd0;
        end else begin
          pattern_index <= pattern_index + 3'd1;
        end
        col_offset <= 3'd0;
        no_bits_selected <= 1'b0;
      end
    end
  end

  keypad_matrix_scanner #(
    .ROW_MAP_0(3),
    .ROW_MAP_1(2),
    .ROW_MAP_2(1),
    .ROW_MAP_3(0),
    .COL_MAP_0(3),
    .COL_MAP_1(2),
    .COL_MAP_2(1),
    .COL_MAP_3(0)
  ) u_scanner (
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_raw_rows(raw_rows),
    .o_raw_col_drive(raw_col_drive),
    .o_debug_raw_rows(o_debug_raw_rows),
    .o_unused_debug_pmod(o_unused_debug_pmod),
    .o_debug_any_active(o_debug_any_active),
    .o_debug_row_bits(o_debug_row_bits),
    .o_debug_col_bits(o_debug_col_bits),
    .o_debug_heartbeat(debug_heartbeat),
    .o_debug_row_valid(o_debug_row_valid),
    .o_debug_col_valid(o_debug_col_valid)
  );

  assign o_debug_raw_col_drive = raw_col_drive;

endmodule
