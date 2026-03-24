module text_cell_bram #(
  parameter DEPTH = 2000,
  parameter AW    = 11
)(
  input  wire          clk,

  input  wire          rd_en,
  input  wire [AW-1:0] rd_addr,
  output reg  [15:0]   rd_data,

  input  wire          wr_en,
  input  wire [AW-1:0] wr_addr,
  input  wire [15:0]   wr_data
);

  reg [15:0] mem [0:DEPTH-1];

  always @(posedge clk) begin
    if (rd_en)
      rd_data <= mem[rd_addr];

    if (wr_en)
      mem[wr_addr] <= wr_data;
  end

endmodule
