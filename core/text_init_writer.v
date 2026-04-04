module text_init_writer (
  input  wire        i_clk,
  input  wire        i_reset,
  input  wire        i_frame_commit,
  output reg         o_wr_en,
  output reg  [10:0] o_wr_addr,
  output reg  [15:0] o_wr_data,
  output reg         o_ctrl_wr_en,
  output reg  [2:0]  o_ctrl_wr_addr,
  output reg  [15:0] o_ctrl_wr_data,
  output reg         o_done
);

  localparam TEXT_COLS  = 80;
  localparam TEXT_ROWS  = 25;
  localparam CELL_COUNT = TEXT_COLS * TEXT_ROWS;

  localparam [2:0] CTRL_ADDR_CURSOR_FLAGS        = 3'd0;
  localparam [2:0] CTRL_ADDR_CURSOR_BLINK_PERIOD = 3'd1;
  localparam [2:0] CTRL_ADDR_ATTR_BLINK_PERIOD   = 3'd2;
  localparam [2:0] CTRL_ADDR_CURSOR_SHAPE        = 3'd3;
  localparam [2:0] CTRL_ADDR_CURSOR_COL          = 3'd4;
  localparam [2:0] CTRL_ADDR_CURSOR_ROW          = 3'd5;

  localparam [15:0] INIT_CURSOR_BLINK_PERIOD = 16'd32;
  localparam [15:0] INIT_ATTR_BLINK_PERIOD   = 16'd64;
  localparam [1:0]  INIT_CURSOR_MODE         = 2'd0;
  localparam [2:0]  INIT_CURSOR_TEMPLATE     = 3'd4;
  localparam        INIT_CURSOR_VERTICAL     = 1'b0;
  localparam [6:0]  INIT_CURSOR_COL          = 7'd10;
  localparam [4:0]  INIT_CURSOR_ROW          = 5'd12;
  localparam [15:0] DEMO_FRAMES_PER_PHASE    = 16'd600;
  localparam [6:0]  DEMO_ATTR_COL_START      = 7'd11;
  localparam [3:0]  DEMO_ATTR_COL_LAST_STEP  = 4'd15;
  localparam [6:0]  GLYPH_PREVIEW_COL_START  = 7'd72;
  localparam [4:0]  GLYPH_PREVIEW_ROW_START  = 5'd0;
  localparam [15:0] GLYPH_PREVIEW_PAGE_FRAMES = 16'd120;
  localparam [15:0] DEMO_SLOW_MOVE_PERIOD    = 16'd30;
  localparam [15:0] DEMO_FAST_MOVE_PERIOD    = 16'd6;

  localparam [2:0] S_CLEAR = 3'd0;
  localparam [2:0] S_LINE  = 3'd1;
  localparam [2:0] S_GLYPH = 3'd2;
  localparam [2:0] S_CTRL  = 3'd3;
  localparam [2:0] S_DONE  = 3'd4;

  reg [2:0]  state;
  reg [10:0] clear_addr;
  reg [3:0]  line_idx;
  reg [6:0]  col_idx;
  reg [2:0]  ctrl_idx;
  reg [15:0] demo_frame_counter;
  reg [3:0]  demo_phase;
  reg [3:0]  pending_demo_phase;
  reg        demo_update_active;
  reg [15:0] demo_motion_counter;
  reg [3:0]  demo_motion_step;
  reg [15:0] glyph_preview_frame_counter;
  reg [1:0]  glyph_preview_page;
  reg [1:0]  pending_glyph_preview_page;
  reg        glyph_preview_update_active;
  reg [5:0]  glyph_preview_cell_idx;

  function [4:0] line_row;
    input [3:0] line;
    begin
      case (line)
        2'd0: line_row = 5'd0;
        2'd1: line_row = 5'd2;
        2'd2: line_row = 5'd4;
        2'd3: line_row = 5'd6;
        4'd4: line_row = 5'd8;
        4'd5: line_row = 5'd10;
        4'd6: line_row = 5'd12;
        4'd7: line_row = 5'd14;
        4'd8: line_row = 5'd16;
        4'd9: line_row = 5'd18;
        4'd10: line_row = 5'd20;
        4'd11: line_row = 5'd22;
        default: line_row = 5'd0;
      endcase
    end
  endfunction

  function [6:0] line_start_col;
    input [3:0] line;
    begin
      case (line)
        2'd0: line_start_col = 7'd0;
        2'd1: line_start_col = 7'd0;
        2'd2: line_start_col = 7'd0;
        2'd3: line_start_col = 7'd0;
        4'd4: line_start_col = 7'd0;
        4'd5: line_start_col = 7'd0;
        4'd6: line_start_col = 7'd0;
        4'd7: line_start_col = 7'd0;
        4'd8: line_start_col = 7'd0;
        4'd9: line_start_col = 7'd0;
        4'd10: line_start_col = 7'd0;
        4'd11: line_start_col = 7'd0;
        default: line_start_col = 7'd0;
      endcase
    end
  endfunction

  function [6:0] line_len;
    input [3:0] line;
    begin
      case (line)
        2'd0: line_len = 7'd26; // "TMDS TX text mode bring-up"
        2'd1: line_len = 7'd29; // "BRAM-backed active text plane"
        2'd2: line_len = 7'd34; // "Next: SDRAM snapshot during vblank"
        2'd3: line_len = 7'd31; // "VGA16 palette: 0123456789ABCDEF"
        4'd4: line_len = 7'd27; // "Blink bg0: 0123456789ABCDEF"
        4'd5: line_len = 7'd27; // "Blink bg1: 0123456789ABCDEF"
        4'd6: line_len = 7'd27; // "Blink bg2: 0123456789ABCDEF"
        4'd7: line_len = 7'd27; // "Blink bg3: 0123456789ABCDEF"
        4'd8: line_len = 7'd27; // "Blink bg4: 0123456789ABCDEF"
        4'd9: line_len = 7'd27; // "Blink bg5: 0123456789ABCDEF"
        4'd10: line_len = 7'd27; // "Blink bg6: 0123456789ABCDEF"
        4'd11: line_len = 7'd27; // "Blink bg7: 0123456789ABCDEF"
        default: line_len = 7'd0;
      endcase
    end
  endfunction

  function [7:0] hex_char;
    input [3:0] value;
    begin
      case (value)
        4'h0: hex_char = "0";
        4'h1: hex_char = "1";
        4'h2: hex_char = "2";
        4'h3: hex_char = "3";
        4'h4: hex_char = "4";
        4'h5: hex_char = "5";
        4'h6: hex_char = "6";
        4'h7: hex_char = "7";
        4'h8: hex_char = "8";
        4'h9: hex_char = "9";
        4'hA: hex_char = "A";
        4'hB: hex_char = "B";
        4'hC: hex_char = "C";
        4'hD: hex_char = "D";
        4'hE: hex_char = "E";
        4'hF: hex_char = "F";
        default: hex_char = " ";
      endcase
    end
  endfunction

  function [7:0] line_char;
    input [3:0] line;
    input [6:0] col;
    begin
      case (line)
        2'd0: begin
          case (col)
             7'd0: line_char = "T";
             7'd1: line_char = "M";
             7'd2: line_char = "D";
             7'd3: line_char = "S";
             7'd4: line_char = " ";
             7'd5: line_char = "T";
             7'd6: line_char = "X";
             7'd7: line_char = " ";
             7'd8: line_char = "t";
             7'd9: line_char = "e";
            7'd10: line_char = "x";
            7'd11: line_char = "t";
            7'd12: line_char = " ";
            7'd13: line_char = "m";
            7'd14: line_char = "o";
            7'd15: line_char = "d";
            7'd16: line_char = "e";
            7'd17: line_char = " ";
            7'd18: line_char = "b";
            7'd19: line_char = "r";
            7'd20: line_char = "i";
            7'd21: line_char = "n";
            7'd22: line_char = "g";
            7'd23: line_char = "-";
            7'd24: line_char = "u";
            7'd25: line_char = "p";
            default: line_char = " ";
          endcase
        end

        2'd1: begin
          case (col)
             7'd0: line_char = "B";
             7'd1: line_char = "R";
             7'd2: line_char = "A";
             7'd3: line_char = "M";
             7'd4: line_char = "-";
             7'd5: line_char = "b";
             7'd6: line_char = "a";
             7'd7: line_char = "c";
             7'd8: line_char = "k";
             7'd9: line_char = "e";
            7'd10: line_char = "d";
            7'd11: line_char = " ";
            7'd12: line_char = "a";
            7'd13: line_char = "c";
            7'd14: line_char = "t";
            7'd15: line_char = "i";
            7'd16: line_char = "v";
            7'd17: line_char = "e";
            7'd18: line_char = " ";
            7'd19: line_char = "t";
            7'd20: line_char = "e";
            7'd21: line_char = "x";
            7'd22: line_char = "t";
            7'd23: line_char = " ";
            7'd24: line_char = "p";
            7'd25: line_char = "l";
            7'd26: line_char = "a";
            7'd27: line_char = "n";
            7'd28: line_char = "e";
            default: line_char = " ";
          endcase
        end

        2'd2: begin
          case (col)
             7'd0: line_char = "N";
             7'd1: line_char = "e";
             7'd2: line_char = "x";
             7'd3: line_char = "t";
             7'd4: line_char = ":";
             7'd5: line_char = " ";
             7'd6: line_char = "S";
             7'd7: line_char = "D";
             7'd8: line_char = "R";
             7'd9: line_char = "A";
            7'd10: line_char = "M";
            7'd11: line_char = " ";
            7'd12: line_char = "s";
            7'd13: line_char = "n";
            7'd14: line_char = "a";
            7'd15: line_char = "p";
            7'd16: line_char = "s";
            7'd17: line_char = "h";
            7'd18: line_char = "o";
            7'd19: line_char = "t";
            7'd20: line_char = " ";
            7'd21: line_char = "d";
            7'd22: line_char = "u";
            7'd23: line_char = "r";
            7'd24: line_char = "i";
            7'd25: line_char = "n";
            7'd26: line_char = "g";
            7'd27: line_char = " ";
            7'd28: line_char = "v";
            7'd29: line_char = "b";
            7'd30: line_char = "l";
            7'd31: line_char = "a";
            7'd32: line_char = "n";
            7'd33: line_char = "k";
            default: line_char = " ";
          endcase
        end

        2'd3: begin
          case (col)
             7'd0: line_char = "V";
             7'd1: line_char = "G";
             7'd2: line_char = "A";
             7'd3: line_char = "1";
             7'd4: line_char = "6";
             7'd5: line_char = " ";
             7'd6: line_char = "p";
             7'd7: line_char = "a";
             7'd8: line_char = "l";
             7'd9: line_char = "e";
            7'd10: line_char = "t";
            7'd11: line_char = "t";
            7'd12: line_char = "e";
            7'd13: line_char = ":";
            7'd14: line_char = " ";
            7'd15: line_char = "0";
            7'd16: line_char = "1";
            7'd17: line_char = "2";
            7'd18: line_char = "3";
            7'd19: line_char = "4";
            7'd20: line_char = "5";
            7'd21: line_char = "6";
            7'd22: line_char = "7";
            7'd23: line_char = "8";
            7'd24: line_char = "9";
            7'd25: line_char = "A";
            7'd26: line_char = "B";
            7'd27: line_char = "C";
            7'd28: line_char = "D";
            7'd29: line_char = "E";
            7'd30: line_char = "F";
            default: line_char = " ";
          endcase
        end

        4'd4,
        4'd5,
        4'd6,
        4'd7,
        4'd8,
        4'd9,
        4'd10,
        4'd11: begin
          case (col)
             7'd0: line_char = "B";
             7'd1: line_char = "l";
             7'd2: line_char = "i";
             7'd3: line_char = "n";
             7'd4: line_char = "k";
             7'd5: line_char = " ";
             7'd6: line_char = "b";
             7'd7: line_char = "g";
             7'd8: line_char = hex_char(line - 4'd4);
             7'd9: line_char = ":";
            7'd10: line_char = " ";
            7'd11: line_char = "0";
            7'd12: line_char = "1";
            7'd13: line_char = "2";
            7'd14: line_char = "3";
            7'd15: line_char = "4";
            7'd16: line_char = "5";
            7'd17: line_char = "6";
            7'd18: line_char = "7";
            7'd19: line_char = "8";
            7'd20: line_char = "9";
            7'd21: line_char = "A";
            7'd22: line_char = "B";
            7'd23: line_char = "C";
            7'd24: line_char = "D";
            7'd25: line_char = "E";
            7'd26: line_char = "F";
            default: line_char = " ";
          endcase
        end

        default: line_char = " ";
      endcase
    end
  endfunction

  function [7:0] line_attr;
    input [3:0] line;
    input [6:0] col;
    begin
      case (line)
        2'd0: line_attr = 8'h1F; // white on blue
        2'd1: line_attr = 8'h0A; // bright green on black
        2'd2: line_attr = 8'h0E; // yellow on black
        2'd3: begin
          if (col < 7'd15) begin
            line_attr = 8'h07;
          end else begin
            case (col)
              7'd15: line_attr = 8'h00;
              7'd16: line_attr = 8'h01;
              7'd17: line_attr = 8'h02;
              7'd18: line_attr = 8'h03;
              7'd19: line_attr = 8'h04;
              7'd20: line_attr = 8'h05;
              7'd21: line_attr = 8'h06;
              7'd22: line_attr = 8'h07;
              7'd23: line_attr = 8'h08;
              7'd24: line_attr = 8'h09;
              7'd25: line_attr = 8'h0A;
              7'd26: line_attr = 8'h0B;
              7'd27: line_attr = 8'h0C;
              7'd28: line_attr = 8'h0D;
              7'd29: line_attr = 8'h0E;
              7'd30: line_attr = 8'h0F;
              default: line_attr = 8'h07;
            endcase
          end
        end
        4'd4,
        4'd5,
        4'd6,
        4'd7,
        4'd8,
        4'd9,
        4'd10,
        4'd11: begin
          if (col < 7'd11)
            line_attr = 8'h07;
          else
            line_attr = 8'h80 | ({1'b0, (line - 4'd4)} << 4) | {1'b0, (col - 7'd11)};
        end
        default: line_attr = 8'h07;
      endcase
    end
  endfunction

  function [15:0] demo_phase_move_period;
    input [3:0] phase;
    begin
      case (phase)
        4'd1,
        4'd3,
        4'd5,
        4'd8: demo_phase_move_period = DEMO_FAST_MOVE_PERIOD;
        default: demo_phase_move_period = DEMO_SLOW_MOVE_PERIOD;
      endcase
    end
  endfunction

  function [4:0] demo_phase_cursor_row;
    input [3:0] phase;
    begin
      case (phase)
        4'd0: demo_phase_cursor_row = 5'd0;
        4'd1: demo_phase_cursor_row = 5'd2;
        4'd2: demo_phase_cursor_row = 5'd4;
        4'd3: demo_phase_cursor_row = 5'd6;
        4'd4: demo_phase_cursor_row = 5'd8;
        4'd5: demo_phase_cursor_row = 5'd10;
        4'd6: demo_phase_cursor_row = 5'd12;
        4'd7: demo_phase_cursor_row = 5'd14;
        4'd8: demo_phase_cursor_row = 5'd16;
        default: demo_phase_cursor_row = 5'd18;
      endcase
    end
  endfunction

  function [6:0] demo_phase_cursor_col;
    input [3:0] phase;
    input [3:0] motion_step;
    begin
      case (phase)
        4'd0: demo_phase_cursor_col = 7'd0 + {3'd0, motion_step};
        4'd1: demo_phase_cursor_col = 7'd0 + {3'd0, motion_step};
        4'd2: demo_phase_cursor_col = 7'd0 + {3'd0, (DEMO_ATTR_COL_LAST_STEP - motion_step)};
        4'd3: demo_phase_cursor_col = 7'd15 + {3'd0, motion_step};
        4'd4,
        4'd6,
        4'd8: demo_phase_cursor_col = DEMO_ATTR_COL_START + {3'd0, (DEMO_ATTR_COL_LAST_STEP - motion_step)};
        default: demo_phase_cursor_col = DEMO_ATTR_COL_START + {3'd0, motion_step};
      endcase
    end
  endfunction

  function [2:0] glyph_preview_col_offset;
    input [5:0] cell_idx;
    begin
      glyph_preview_col_offset = cell_idx[2:0];
    end
  endfunction

  function [2:0] glyph_preview_row_offset;
    input [5:0] cell_idx;
    begin
      glyph_preview_row_offset = cell_idx[5:3];
    end
  endfunction

  function [10:0] glyph_preview_addr;
    input [5:0] cell_idx;
    begin
      glyph_preview_addr =
        (({6'd0, GLYPH_PREVIEW_ROW_START} + {8'd0, glyph_preview_row_offset(cell_idx)}) * TEXT_COLS_ADDR) +
        {4'd0, (GLYPH_PREVIEW_COL_START + {4'd0, glyph_preview_col_offset(cell_idx)})};
    end
  endfunction

  function [7:0] glyph_preview_char;
    input [1:0] page;
    input [5:0] cell_idx;
    begin
      glyph_preview_char = {page, cell_idx};
    end
  endfunction

  localparam [10:0] TEXT_COLS_ADDR = TEXT_COLS;

  wire [10:0] line_base_addr =
    (line_row(line_idx) * TEXT_COLS_ADDR) + {4'd0, line_start_col(line_idx)} + {4'd0, col_idx};

  always @(posedge i_clk) begin
    if (i_reset) begin
      state      <= S_CLEAR;
      clear_addr <= 11'd0;
      line_idx   <= 4'd0;
      col_idx    <= 7'd0;
      ctrl_idx   <= 3'd0;
      demo_frame_counter <= 16'd0;
      demo_phase <= 4'd0;
      pending_demo_phase <= 4'd0;
      demo_update_active <= 1'b0;
      demo_motion_counter <= 16'd0;
      demo_motion_step <= 4'd0;
      glyph_preview_frame_counter <= 16'd0;
      glyph_preview_page <= 2'd0;
      pending_glyph_preview_page <= 2'd0;
      glyph_preview_update_active <= 1'b0;
      glyph_preview_cell_idx <= 6'd0;
      o_wr_en    <= 1'b0;
      o_wr_addr  <= 11'd0;
      o_wr_data  <= 16'h0720;
      o_ctrl_wr_en   <= 1'b0;
      o_ctrl_wr_addr <= 3'd0;
      o_ctrl_wr_data <= 16'd0;
      o_done     <= 1'b0;
    end else begin
      o_wr_en      <= 1'b0;
      o_ctrl_wr_en <= 1'b0;

      if (i_frame_commit && o_done) begin
        if (demo_frame_counter == (DEMO_FRAMES_PER_PHASE - 16'd1)) begin
          demo_frame_counter  <= 16'd0;
          pending_demo_phase  <= (demo_phase == 4'd9) ? 4'd0 : (demo_phase + 4'd1);
          demo_phase          <= (demo_phase == 4'd9) ? 4'd0 : (demo_phase + 4'd1);
          demo_update_active  <= 1'b1;
          demo_motion_counter <= 16'd0;
          demo_motion_step    <= 4'd0;
          ctrl_idx            <= 3'd0;
        end else begin
          demo_frame_counter <= demo_frame_counter + 16'd1;

          if (demo_motion_counter == (demo_phase_move_period(demo_phase) - 16'd1)) begin
            demo_motion_counter <= 16'd0;
            if (demo_motion_step == DEMO_ATTR_COL_LAST_STEP)
              demo_motion_step <= 4'd0;
            else
              demo_motion_step <= demo_motion_step + 4'd1;
            pending_demo_phase <= demo_phase;
            demo_update_active <= 1'b1;
            ctrl_idx           <= 3'd0;
          end else begin
            demo_motion_counter <= demo_motion_counter + 16'd1;
          end
        end

        if (glyph_preview_frame_counter == (GLYPH_PREVIEW_PAGE_FRAMES - 16'd1)) begin
          glyph_preview_frame_counter <= 16'd0;
          pending_glyph_preview_page <= (glyph_preview_page == 2'd3) ? 2'd0 : (glyph_preview_page + 2'd1);
          glyph_preview_page         <= (glyph_preview_page == 2'd3) ? 2'd0 : (glyph_preview_page + 2'd1);
          glyph_preview_update_active <= 1'b1;
          glyph_preview_cell_idx     <= 6'd0;
        end else begin
          glyph_preview_frame_counter <= glyph_preview_frame_counter + 16'd1;
        end
      end

      case (state)
        S_CLEAR: begin
          o_wr_en   <= 1'b1;
          o_wr_addr <= clear_addr;
          o_wr_data <= {8'h07, 8'h20};

          if (clear_addr == (CELL_COUNT - 1)) begin
            state      <= S_LINE;
            clear_addr <= 11'd0;
            line_idx   <= 4'd0;
            col_idx    <= 7'd0;
            ctrl_idx   <= 3'd0;
          end else begin
            clear_addr <= clear_addr + 11'd1;
          end
        end

        S_LINE: begin
          o_wr_en   <= 1'b1;
          o_wr_addr <= line_base_addr;
          o_wr_data <= {line_attr(line_idx, col_idx), line_char(line_idx, col_idx)};

          if (col_idx == (line_len(line_idx) - 1)) begin
            col_idx <= 7'd0;
            if (line_idx == 4'd11) begin
              state                <= S_GLYPH;
              glyph_preview_cell_idx <= 6'd0;
            end else begin
              line_idx <= line_idx + 4'd1;
            end
          end else begin
            col_idx <= col_idx + 7'd1;
          end
        end

        S_GLYPH: begin
          o_wr_en   <= 1'b1;
          o_wr_addr <= glyph_preview_addr(glyph_preview_cell_idx);
          o_wr_data <= {8'h07, glyph_preview_char(2'd0, glyph_preview_cell_idx)};

          if (glyph_preview_cell_idx == 6'd63) begin
            state      <= S_CTRL;
            ctrl_idx   <= 3'd0;
            glyph_preview_cell_idx <= 6'd0;
          end else begin
            glyph_preview_cell_idx <= glyph_preview_cell_idx + 6'd1;
          end
        end

        S_CTRL: begin
          o_ctrl_wr_en <= 1'b1;

          case (ctrl_idx)
            CTRL_ADDR_CURSOR_FLAGS: begin
              o_ctrl_wr_addr <= 3'd0;
              o_ctrl_wr_data <= 16'h0003; // visible + blink enabled
            end

            CTRL_ADDR_CURSOR_BLINK_PERIOD: begin
              o_ctrl_wr_addr <= 3'd1;
              o_ctrl_wr_data <= INIT_CURSOR_BLINK_PERIOD;
            end

            CTRL_ADDR_ATTR_BLINK_PERIOD: begin
              o_ctrl_wr_addr <= 3'd2;
              o_ctrl_wr_data <= INIT_ATTR_BLINK_PERIOD;
            end

            CTRL_ADDR_CURSOR_SHAPE: begin
              o_ctrl_wr_addr <= 3'd3;
              o_ctrl_wr_data <= {10'd0, INIT_CURSOR_TEMPLATE, INIT_CURSOR_VERTICAL, INIT_CURSOR_MODE};
            end

            CTRL_ADDR_CURSOR_COL: begin
              o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_COL;
              o_ctrl_wr_data <= {9'd0, INIT_CURSOR_COL};
            end

            CTRL_ADDR_CURSOR_ROW: begin
              o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_ROW;
              o_ctrl_wr_data <= {11'd0, INIT_CURSOR_ROW};
            end
            default: begin
              o_ctrl_wr_addr <= 3'd0;
              o_ctrl_wr_data <= 16'd0;
            end
          endcase

          if (ctrl_idx == CTRL_ADDR_CURSOR_ROW) begin
            state  <= S_DONE;
            o_done <= 1'b1;
          end else begin
            ctrl_idx <= ctrl_idx + 3'd1;
          end
        end

        S_DONE: begin
          o_done <= 1'b1;

          if (glyph_preview_update_active) begin
            o_wr_en   <= 1'b1;
            o_wr_addr <= glyph_preview_addr(glyph_preview_cell_idx);
            o_wr_data <= {8'h07, glyph_preview_char(pending_glyph_preview_page, glyph_preview_cell_idx)};

            if (glyph_preview_cell_idx == 6'd63) begin
              glyph_preview_update_active <= 1'b0;
            end else begin
              glyph_preview_cell_idx <= glyph_preview_cell_idx + 6'd1;
            end
          end

          if (demo_update_active) begin
            o_ctrl_wr_en <= 1'b1;

            case (ctrl_idx)
              CTRL_ADDR_CURSOR_FLAGS: begin
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_FLAGS;
                o_ctrl_wr_data <=
                  (pending_demo_phase >= 4'd6) ? 16'h0001 : 16'h0003;
              end

              CTRL_ADDR_CURSOR_BLINK_PERIOD: begin
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_BLINK_PERIOD;
                o_ctrl_wr_data <= INIT_CURSOR_BLINK_PERIOD;
              end

              CTRL_ADDR_CURSOR_SHAPE: begin
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_SHAPE;
                case (pending_demo_phase)
                  4'd4: o_ctrl_wr_data <= {10'd0, 3'd6, 1'b0, 2'd0};
                  4'd5: o_ctrl_wr_data <= {10'd0, 3'd4, 1'b1, 2'd0};
                  4'd6: o_ctrl_wr_data <= {10'd0, 3'd7, 1'b1, 2'd0};
                  4'd7: o_ctrl_wr_data <= {10'd0, 3'd7, 1'b1, 2'd1};
                  4'd8: o_ctrl_wr_data <= {10'd0, 3'd7, 1'b1, 2'd2};
                  4'd9: o_ctrl_wr_data <= {10'd0, 3'd7, 1'b1, 2'd2};
                  default: o_ctrl_wr_data <= {10'd0, 3'd4, 1'b0, 2'd0};
                endcase
              end

              CTRL_ADDR_CURSOR_COL: begin
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_COL;
                o_ctrl_wr_data <= {9'd0, demo_phase_cursor_col(pending_demo_phase, demo_motion_step)};
              end

              CTRL_ADDR_CURSOR_ROW: begin
                o_ctrl_wr_addr <= CTRL_ADDR_CURSOR_ROW;
                o_ctrl_wr_data <= {11'd0, demo_phase_cursor_row(pending_demo_phase)};
              end

              default: begin
                o_ctrl_wr_addr <= 3'd0;
                o_ctrl_wr_data <= 16'd0;
              end
            endcase

            if (ctrl_idx == CTRL_ADDR_CURSOR_ROW) begin
              demo_update_active <= 1'b0;
            end else begin
              case (ctrl_idx)
                CTRL_ADDR_CURSOR_FLAGS: ctrl_idx <= CTRL_ADDR_CURSOR_BLINK_PERIOD;
                CTRL_ADDR_CURSOR_BLINK_PERIOD: ctrl_idx <= CTRL_ADDR_CURSOR_SHAPE;
                CTRL_ADDR_CURSOR_SHAPE: ctrl_idx <= CTRL_ADDR_CURSOR_COL;
                CTRL_ADDR_CURSOR_COL: ctrl_idx <= CTRL_ADDR_CURSOR_ROW;
                default: ctrl_idx <= CTRL_ADDR_CURSOR_ROW;
              endcase
            end
          end
        end

        default: begin
          state  <= S_DONE;
          o_done <= 1'b1;
        end
      endcase
    end
  end

endmodule
