module artix_serializer_10to1(
  input  wire       pixel_clk,
  input  wire       pixel_clk_5x,
  input  wire [9:0] parallel_in,
  input  wire       reset,
  output wire       serial_out,
  output wire       serial_out_n
);
  wire shift1;
  wire shift2;
  wire serial_int;
  reg  reset_sync;

  // The Artix-7 OSERDESE2 reset should be asserted asynchronously and released
  // on the divided clock domain.
  always @(posedge pixel_clk or posedge reset) begin
    if (reset) begin
      reset_sync <= 1'b1;
    end else begin
      reset_sync <= 1'b0;
    end
  end

  OSERDESE2 #(
    .DATA_RATE_OQ  ("DDR"),
    .DATA_RATE_TQ  ("SDR"),
    .DATA_WIDTH    (10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE   ("MASTER")
  ) oserdese2_master (
    .D1       (parallel_in[0]),
    .D2       (parallel_in[1]),
    .D3       (parallel_in[2]),
    .D4       (parallel_in[3]),
    .D5       (parallel_in[4]),
    .D6       (parallel_in[5]),
    .D7       (parallel_in[6]),
    .D8       (parallel_in[7]),
    .T1       (1'b0),
    .T2       (1'b0),
    .T3       (1'b0),
    .T4       (1'b0),
    .SHIFTIN1 (shift1),
    .SHIFTIN2 (shift2),
    .SHIFTOUT1(),
    .SHIFTOUT2(),
    .OCE      (1'b1),
    .CLK      (pixel_clk_5x),
    .CLKDIV   (pixel_clk),
    .OQ       (serial_int),
    .TQ       (),
    .OFB      (),
    .TFB      (),
    .TBYTEIN  (1'b0),
    .TBYTEOUT (),
    .TCE      (1'b0),
    .RST      (reset_sync)
  );

  OSERDESE2 #(
    .DATA_RATE_OQ  ("DDR"),
    .DATA_RATE_TQ  ("SDR"),
    .DATA_WIDTH    (10),
    .TRISTATE_WIDTH(1),
    .SERDES_MODE   ("SLAVE")
  ) oserdese2_slave (
    .D1       (1'b0),
    .D2       (1'b0),
    .D3       (parallel_in[8]),
    .D4       (parallel_in[9]),
    .D5       (1'b0),
    .D6       (1'b0),
    .D7       (1'b0),
    .D8       (1'b0),
    .T1       (1'b0),
    .T2       (1'b0),
    .T3       (1'b0),
    .T4       (1'b0),
    .SHIFTIN1 (1'b0),
    .SHIFTIN2 (1'b0),
    .SHIFTOUT1(shift1),
    .SHIFTOUT2(shift2),
    .OCE      (1'b1),
    .CLK      (pixel_clk_5x),
    .CLKDIV   (pixel_clk),
    .OQ       (),
    .TQ       (),
    .OFB      (),
    .TFB      (),
    .TBYTEIN  (1'b0),
    .TBYTEOUT (),
    .TCE      (1'b0),
    .RST      (reset_sync)
  );

  OBUFDS obufds (
    .I (serial_int),
    .O (serial_out),
    .OB(serial_out_n)
  );
endmodule
