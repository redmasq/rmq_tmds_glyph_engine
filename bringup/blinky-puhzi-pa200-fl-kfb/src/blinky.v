module top (
  input  wire sys_clk_p,
  input  wire sys_clk_n,
  input  wire sys_rstn,
  output reg  [0:0] led
);

  wire clk;

  // The Puhzi board exposes a differential 200 MHz logic clock, so convert the
  // external pair into a single internal fabric clock first.
  IBUFDS #(
    .DIFF_TERM   ("FALSE"),
    .IBUF_LOW_PWR("TRUE"),
    .IOSTANDARD  ("DEFAULT")
  ) u_sys_clk_ibufds (
    .O (clk),
    .I (sys_clk_p),
    .IB(sys_clk_n)
  );

  // 200 MHz input clock -> 100,000,000 cycles is roughly 0.5 seconds.
  localparam [31:0] HALF_SECOND_CYCLES = 32'd100_000_000;

  reg [31:0] counter;

  always @(posedge clk) begin
    if (!sys_rstn) begin
      counter <= 32'd0;
      led     <= 1'b1;
    end else if (counter == (HALF_SECOND_CYCLES - 1)) begin
      counter <= 32'd0;
      led     <= ~led;
    end else begin
      counter <= counter + 32'd1;
    end
  end

endmodule
