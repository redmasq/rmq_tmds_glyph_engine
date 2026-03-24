module cp437_font_rom (
  input  wire       clk,
  input  wire [7:0] char_code,
  input  wire [3:0] row,
  output wire [7:0] bits
);

  wire [11:0] addr = {char_code, row};

`ifdef USE_INFERRED_FONT_ROM
  // Non-Gowin builds can infer a small synchronous ROM directly from the
  // shared font hex file instead of relying on a vendor-specific pROM macro.
  reg [7:0] rom [0:4095];
  reg [7:0] bits_r;

`ifdef CP437_FONT_MEM_FILE
  localparam FONT_MEM_FILE = `CP437_FONT_MEM_FILE;
`else
  localparam FONT_MEM_FILE = "resources/cp437_8x16.mem";
`endif

  initial begin
    $readmemh(FONT_MEM_FILE, rom);
  end

  always @(posedge clk) begin
    bits_r <= rom[addr];
  end

  assign bits = bits_r;
`elsif USE_ARTIX_GENERATED_FONT_ROM
  // Artix builds can compile a generated, block-ROM-friendly wrapper from the
  // shared font source ahead of synthesis, avoiding both vendor IP tooling and
  // runtime $readmemh path handling.
  artix_cp437_font_rom u_rom (
    .clk      (clk),
    .char_code(char_code),
    .row      (row),
    .bits     (bits)
  );
`else
  Gowin_pROM_cp437_8x16 u_rom (
    .dout (bits),
    .ad   (addr),
    .clk  (clk),
    .ce   (1'b1),
    .oce  (1'b1),
    .reset(1'b0)
  );
`endif

endmodule
