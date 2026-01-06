`timescale 1ns / 1ps

module combination_new_target_finder #(
    parameter MAX_BUTTON_COUNT = 13,
    parameter MACHINE_COUNT = 10,
    parameter BITS_PER_JOLTAGE = 9
) (
    input clk,
    input [MAX_BUTTON_COUNT - 1 : 0] combination,
    input [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons,
    input [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_target,
    output reg combination_no_negative,
    output reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_new_target);

    integer i, j;

    reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] next_flattened_new_target;
    reg [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] button_presses_for_machines [MACHINE_COUNT - 1 : 0];
    reg [MACHINE_COUNT - 1 : 0] combination_negative_for_machine;

    wire next_combination_no_negative;
    assign next_combination_no_negative = (combination_negative_for_machine == 0);

    always @(posedge clk) begin
        combination_no_negative <= next_combination_no_negative;
        flattened_new_target <= next_flattened_new_target;
    end

    always @(*) begin
        for (i = 0; i < MACHINE_COUNT; i = i + 1) begin
            button_presses_for_machines[i] = 0;
            for (j = 0; j < MAX_BUTTON_COUNT; j = j + 1) begin
                if (flattened_buttons[j * MACHINE_COUNT + i] == 1 && combination[j] == 1) begin
                    button_presses_for_machines[i] = button_presses_for_machines[i] + 1;
                end
            end

            next_flattened_new_target[i * BITS_PER_JOLTAGE +: BITS_PER_JOLTAGE]
            = (flattened_target[i * BITS_PER_JOLTAGE +: BITS_PER_JOLTAGE] - button_presses_for_machines[i]) >> 1;

            if (flattened_target[i * BITS_PER_JOLTAGE +: BITS_PER_JOLTAGE] < button_presses_for_machines[i]) begin
                combination_negative_for_machine[i] = 1;
            end
            else combination_negative_for_machine[i] = 0;
        end
    end

endmodule