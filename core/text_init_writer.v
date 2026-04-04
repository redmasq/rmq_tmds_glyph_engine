module text_init_writer (
  input  wire        i_clk,
  input  wire        i_reset,
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

  localparam [1:0] CTRL_ADDR_CURSOR_FLAGS        = 2'd0;
  localparam [1:0] CTRL_ADDR_CURSOR_BLINK_PERIOD = 2'd1;
  localparam [1:0] CTRL_ADDR_ATTR_BLINK_PERIOD   = 2'd2;
  localparam [1:0] CTRL_ADDR_CURSOR_SHAPE        = 2'd3;

  localparam [15:0] INIT_CURSOR_BLINK_PERIOD = 16'd32;
  localparam [15:0] INIT_ATTR_BLINK_PERIOD   = 16'd64;
  localparam [1:0]  INIT_CURSOR_MODE         = 2'd0;
  localparam [2:0]  INIT_CURSOR_TEMPLATE     = 3'd4;

  localparam S_CLEAR = 2'd0;
  localparam S_LINE  = 2'd1;
  localparam S_CTRL  = 2'd2;
  localparam S_DONE  = 2'd3;

  reg [1:0]  state;
  reg [10:0] clear_addr;
  reg [3:0]  line_idx;
  reg [6:0]  col_idx;
  reg [1:0]  ctrl_idx;

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

  localparam [10:0] TEXT_COLS_ADDR = TEXT_COLS;

  wire [10:0] line_base_addr =
    (line_row(line_idx) * TEXT_COLS_ADDR) + {4'd0, line_start_col(line_idx)} + {4'd0, col_idx};

  always @(posedge i_clk) begin
    if (i_reset) begin
      state      <= S_CLEAR;
      clear_addr <= 11'd0;
      line_idx   <= 2'd0;
      col_idx    <= 7'd0;
      ctrl_idx   <= 2'd0;
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

      case (state)
        S_CLEAR: begin
          o_wr_en   <= 1'b1;
          o_wr_addr <= clear_addr;
          o_wr_data <= {8'h07, 8'h20};

          if (clear_addr == (CELL_COUNT - 1)) begin
            state      <= S_LINE;
            clear_addr <= 11'd0;
            line_idx   <= 2'd0;
            col_idx    <= 7'd0;
            ctrl_idx   <= 2'd0;
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
              state    <= S_CTRL;
              ctrl_idx <= 2'd0;
            end else begin
              line_idx <= line_idx + 4'd1;
            end
          end else begin
            col_idx <= col_idx + 7'd1;
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
              // Seed a horizontal cursor at roughly 50% cell height. Later
              // tickets own the visible render semantics of this shape field.
              o_ctrl_wr_data <= {9'd0, INIT_CURSOR_TEMPLATE, 2'd0, INIT_CURSOR_MODE};
            end
          endcase

          if (ctrl_idx == CTRL_ADDR_CURSOR_SHAPE) begin
            state  <= S_DONE;
            o_done <= 1'b1;
          end else begin
            ctrl_idx <= ctrl_idx + 2'd1;
          end
        end

        S_DONE: begin
          o_done <= 1'b1;
        end

        default: begin
          state  <= S_DONE;
          o_done <= 1'b1;
        end
      endcase
    end
  end

endmodule
