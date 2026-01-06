`timescale 1ns / 1ps

module onecount #(
    parameter WIDTH = 13,
    parameter ANSWER_BIT_WIDTH = 16
) (
    input [WIDTH : 0] combination,
    output reg [ANSWER_BIT_WIDTH - 1 : 0] count
);

    integer i;
    always @(*) begin
        count = 0;
        for (i = 0; i < WIDTH; i = i + 1) begin
            count = count + combination[i];
        end
    end

endmodule