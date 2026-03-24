module top (
    input  wire clk,
    output wire led
);

    reg [24:0] counter = 25'd0;
    reg led_r = 1'b0;

    always @(posedge clk) begin
        if (counter == 25'd13_499_999) begin
            counter <= 25'd0;
            led_r <= ~led_r;
        end else begin
            counter <= counter + 25'd1;
        end
    end

    assign led = led_r;

endmodule
