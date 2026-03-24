module top (
    input  wire clk,
    output reg  led
);

    reg [23:0] counter = 24'd0;

    always @(posedge clk) begin
        if (counter < 24'd13_499_999)
            counter <= counter + 1'b1;
        else
            counter <= 24'd0;
    end

    always @(posedge clk) begin
        if (counter == 24'd13_499_999)
            led <= ~led;
    end

endmodule
