`timescale 1ns / 1ps

module combination_xor_result_finder #(
    parameter MAX_BUTTON_COUNT = 13,
    parameter MACHINE_COUNT = 10
) (
    input [MAX_BUTTON_COUNT : 0] combination,
    input [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons,
    output reg [MACHINE_COUNT - 1 : 0] combination_xor_result);

    genvar i;
    integer j;

    generate
        for (i = 0; i < MACHINE_COUNT; i = i + 1) begin : loop_machines
            always @(*) begin
                combination_xor_result[i] = 0;
                for (j = 0; j < MAX_BUTTON_COUNT; j = j + 1) begin
                    if (flattened_buttons[j * MACHINE_COUNT + i] == 1 && combination[j] == 1) combination_xor_result[i] = ~combination_xor_result[i];
                end
            end
        end
    endgenerate

endmodule