module vga16_palette (
  input  wire [3:0]  index,
  output reg  [23:0] rgb
);

  always @* begin
    case (index)
      4'h0: rgb = 24'h000000; // black
      4'h1: rgb = 24'h0000AA; // blue
      4'h2: rgb = 24'h00AA00; // green
      4'h3: rgb = 24'h00AAAA; // cyan
      4'h4: rgb = 24'hAA0000; // red
      4'h5: rgb = 24'hAA00AA; // magenta
      4'h6: rgb = 24'hAA5500; // brown
      4'h7: rgb = 24'hAAAAAA; // light gray
      4'h8: rgb = 24'h555555; // dark gray
      4'h9: rgb = 24'h5555FF; // light blue
      4'hA: rgb = 24'h55FF55; // light green
      4'hB: rgb = 24'h55FFFF; // light cyan
      4'hC: rgb = 24'hFF5555; // light red
      4'hD: rgb = 24'hFF55FF; // light magenta
      4'hE: rgb = 24'hFFFF55; // yellow
      4'hF: rgb = 24'hFFFFFF; // white
      default: rgb = 24'h000000;
    endcase
  end

endmodule
