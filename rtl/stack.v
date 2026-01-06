`timescale 1ns / 1ps

module stack #(
    parameter STACK_SIZE = 20,
    parameter MACHINE_COUNT = 10,
    parameter MAX_BUTTON_COUNT = 13,
    parameter BITS_PER_JOLTAGE = 9,
    parameter ANSWER_BIT_WIDTH = 16
) (
    input clk,
    input reset,
    // push and pop should be mutually exclusive
    input push_element, // should be a pulse
    input pop_element, // should be a pulse
    input [MAX_BUTTON_COUNT : 0] next_combination,
    input [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] target,
    input [ANSWER_BIT_WIDTH - 1 : 0] min_button_press_count,
    input [ANSWER_BIT_WIDTH - 1 : 0] button_press_count_for_call,

    // stack outputs are valid one cycle after push/pop signals
    output reg stack_empty,
    output reg [MAX_BUTTON_COUNT : 0] top_next_combination,
    output reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] top_target,
    output reg [ANSWER_BIT_WIDTH - 1 : 0] top_min_button_press_count,
    output reg [ANSWER_BIT_WIDTH - 1 : 0] top_button_press_count_for_call
);

    reg [$clog2(STACK_SIZE + 1) - 1 : 0] stack_element_count;

    reg [MAX_BUTTON_COUNT : 0] next_combination_stack [STACK_SIZE - 1 : 0];
    reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] target_stack [STACK_SIZE - 1 : 0];
    reg [ANSWER_BIT_WIDTH - 1 : 0] min_button_press_count_stack [STACK_SIZE - 1 : 0];
    reg [ANSWER_BIT_WIDTH - 1 : 0] button_press_count_for_call_stack [STACK_SIZE - 1 : 0];

    always @(posedge clk) begin
        if (reset) begin
            stack_element_count <= 0;
        end
        else begin
            if (push_element && stack_element_count < STACK_SIZE) begin
                stack_element_count <= stack_element_count + 1;
                next_combination_stack[stack_element_count] <= next_combination;
                target_stack[stack_element_count] <= target;
                min_button_press_count_stack[stack_element_count] <= min_button_press_count;
                button_press_count_for_call_stack[stack_element_count] <= button_press_count_for_call;

                stack_empty <= 0;
                top_next_combination <= next_combination;
                top_target <= target;
                top_min_button_press_count <= min_button_press_count;
                top_button_press_count_for_call <= button_press_count_for_call;
            end
            else if (pop_element && stack_element_count > 0) begin
                stack_element_count <= stack_element_count - 1;

                if (stack_element_count == 1) begin
                    stack_empty <= 1;
                    top_next_combination <= 0;
                    top_target <= 0;
                    top_min_button_press_count <= 0;
                    top_button_press_count_for_call <= 0;
                end
                else begin
                    stack_empty <= 0;
                    top_next_combination <= next_combination_stack[stack_element_count - 2];
                    top_target <= target_stack[stack_element_count - 2];
                    top_min_button_press_count <= min_button_press_count_stack[stack_element_count - 2];
                    top_button_press_count_for_call <= button_press_count_for_call_stack[stack_element_count - 2];
                end 
            end
            else begin
                if (stack_element_count == 0) begin
                    stack_empty <= 1;
                    top_next_combination <= 0;
                    top_target <= 0;
                    top_min_button_press_count <= 0;
                    top_button_press_count_for_call <= 0;
                end
                else begin
                    stack_empty <= 0;
                    top_next_combination <= next_combination_stack[stack_element_count - 1];
                    top_target <= target_stack[stack_element_count - 1];
                    top_min_button_press_count <= min_button_press_count_stack[stack_element_count - 1];
                    top_button_press_count_for_call <= button_press_count_for_call_stack[stack_element_count - 1];
                end
            end
        end
    end

endmodule