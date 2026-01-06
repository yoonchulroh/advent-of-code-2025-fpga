`timescale 1ns / 1ps

module parity_finder #(
    parameter MACHINE_COUNT = 10,
    parameter BITS_PER_JOLTAGE = 9
) (
    input [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_target,
    output reg [MACHINE_COUNT - 1 : 0] parity);

    integer i;

    always @(*) begin
        for (i = 0; i < MACHINE_COUNT; i = i + 1) begin
            if (flattened_target[i * BITS_PER_JOLTAGE] == 1) parity[i] = 1;
            else parity[i] = 0;
        end
    end

endmodule