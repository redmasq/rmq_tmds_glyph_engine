module cp437_font_rom (
  input  wire       clk,
  input  wire [7:0] char_code,
  input  wire [3:0] row,
  output wire [7:0] bits
);

  wire [11:0] addr = {char_code, row};

  Gowin_pROM u_rom (
    .dout (bits),
    .ad   (addr),
    .clk  (clk),
    .ce   (1'b1),
    .oce  (1'b1),
    .reset(1'b0)
  );

endmodule
