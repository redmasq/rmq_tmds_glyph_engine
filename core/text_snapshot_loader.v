module text_snapshot_loader (
  input  wire        i_clk,
  input  wire        i_reset,
  input  wire        i_enable,
  input  wire        i_init_done,
  input  wire        i_frame_start,
  input  wire        i_vblank,
  input  wire        i_vback_porch,

  output reg         o_wr_en,
  output reg  [10:0] o_wr_addr,
  output reg  [15:0] o_wr_data,
  output reg         o_busy
);

  always @(posedge i_clk) begin
    if (i_reset) begin
      o_wr_en   <= 1'b0;
      o_wr_addr <= 11'd0;
      o_wr_data <= 16'h0720;
      o_busy    <= 1'b0;
    end else begin
      o_wr_en <= 1'b0;

      // Placeholder for future SDRAM-backed snapshot copy.
      // Intended flow:
      // - wait for i_init_done
      // - on frame boundary, arm a copy if dirty/new snapshot pending
      // - perform SDRAM burst reads during i_vblank / i_vback_porch
      // - write packed {attr,char} cells into BRAM through this port
      // - deassert o_busy when the full snapshot is committed
      if (!i_enable) begin
        o_busy <= 1'b0;
      end
    end
  end

endmodule