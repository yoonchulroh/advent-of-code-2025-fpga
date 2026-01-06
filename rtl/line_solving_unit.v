`timescale 1ns / 1ps

module line_solving_unit #(
    parameter MACHINE_COUNT = 10,
    parameter MAX_BUTTON_COUNT = 13,
    parameter BITS_PER_JOLTAGE = 9,
    parameter ANSWER_BIT_WIDTH = 16,
    parameter STACK_SIZE = 20
) (
    input clk,
    input reset,
    input start_LSU, // should be a pulse
    input [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] button_count,
    input [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons,
    input [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_machines,
    output available,
    output reg result_ready, // pulses when result is available
    output reg [ANSWER_BIT_WIDTH - 1 : 0] result
);

    genvar i;

    localparam [2:0] IDLE = 3'b000,
                     BUILDING_PARITY_TABLE = 3'b001,
                     ITERATE_KNOWN_COMBINATIONS = 3'b010,
                     FINDING_NEW_TARGET = 3'b011,
                     FUNCTION_CALL = 3'b100,
                     FUNCTION_RETURN = 3'b101;

    // Universal states
    reg [2:0] state;
    reg [MAX_BUTTON_COUNT : 0] combination_upper_bound;
    reg [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] latched_flattened_buttons;

    // States for the current function call
    reg [MAX_BUTTON_COUNT : 0] combination;
    reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] current_target;
    reg [ANSWER_BIT_WIDTH - 1 : 0] current_min_button_press_count;
    reg [ANSWER_BIT_WIDTH - 1 : 0] button_press_count_for_current_call;

    // Signals for finding and calling on new target
    reg [MAX_BUTTON_COUNT : 0] hit_combination;
    wire [ANSWER_BIT_WIDTH - 1 : 0] one_count_in_hit_combination;
    wire combination_no_negative;
    wire [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_new_target;

    // Signals for the function call stack
    reg push_element, pop_element;
    reg [MAX_BUTTON_COUNT : 0] next_combination_to_stack;
    reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] target_to_stack;
    reg [ANSWER_BIT_WIDTH - 1 : 0] min_button_press_count_to_stack;
    reg [ANSWER_BIT_WIDTH - 1 : 0] button_press_count_for_call_to_stack;
    wire stack_empty;
    wire [MAX_BUTTON_COUNT : 0] top_next_combination;
    wire [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] top_target;
    wire [ANSWER_BIT_WIDTH - 1 : 0] top_min_button_press_count;
    wire [ANSWER_BIT_WIDTH - 1 : 0] top_button_press_count_for_call;

    // Signals for parity to combination table
    wire [MACHINE_COUNT - 1 : 0] current_target_parity, flattened_new_target_parity, top_target_parity;
    reg build_parity_table, find_first_combination_for_parity, find_next_combination_for_combination;
    reg [MAX_BUTTON_COUNT : 0] previous_combination;
    reg [MACHINE_COUNT - 1 : 0] parity_to_search;
    wire parity_table_complete, parity_table_request_ready, parity_list_created, next_combination_valid;
    wire [MAX_BUTTON_COUNT : 0] first_combination_for_parity, next_combination_for_combination;

    assign available = (state == IDLE) && (~start_LSU);

    onecount #(
        .WIDTH(MAX_BUTTON_COUNT),
        .ANSWER_BIT_WIDTH(ANSWER_BIT_WIDTH)
    ) ones_in_combination (
        .combination(hit_combination),

        .count(one_count_in_hit_combination)
    );

    combination_new_target_finder #(
        .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT),
        .MACHINE_COUNT(MACHINE_COUNT),
        .BITS_PER_JOLTAGE(BITS_PER_JOLTAGE)
    ) new_target (
        .clk(clk),
        .combination(hit_combination),
        .flattened_buttons(latched_flattened_buttons),
        .flattened_target(current_target),
        
        .combination_no_negative(combination_no_negative),
        .flattened_new_target(flattened_new_target)
    );

    stack #(
        .STACK_SIZE(STACK_SIZE),
        .MACHINE_COUNT(MACHINE_COUNT),
        .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT),
        .BITS_PER_JOLTAGE(BITS_PER_JOLTAGE),
        .ANSWER_BIT_WIDTH(ANSWER_BIT_WIDTH)
    ) function_call_stack (
        .clk(clk),
        .reset(reset),
        .push_element(push_element),
        .pop_element(pop_element),
        .next_combination(next_combination_to_stack),
        .target(target_to_stack),
        .min_button_press_count(min_button_press_count_to_stack),
        .button_press_count_for_call(button_press_count_for_call_to_stack),

        .stack_empty(stack_empty),
        .top_next_combination(top_next_combination),
        .top_target(top_target),
        .top_min_button_press_count(top_min_button_press_count),
        .top_button_press_count_for_call(top_button_press_count_for_call)
    );

    parity_finder #(
        .MACHINE_COUNT(MACHINE_COUNT),
        .BITS_PER_JOLTAGE(BITS_PER_JOLTAGE)
    ) parity_for_current_target (
        .flattened_target(current_target),

        .parity(current_target_parity)
    );

    parity_finder #(
        .MACHINE_COUNT(MACHINE_COUNT),
        .BITS_PER_JOLTAGE(BITS_PER_JOLTAGE)
    ) parity_for_flattened_new_target (
        .flattened_target(flattened_new_target),

        .parity(flattened_new_target_parity)
    );

    parity_finder #(
        .MACHINE_COUNT(MACHINE_COUNT),
        .BITS_PER_JOLTAGE(BITS_PER_JOLTAGE)
    ) parity_for_top_target (
        .flattened_target(top_target),

        .parity(top_target_parity)
    );

    parity_to_combination_table #(
        .MACHINE_COUNT(MACHINE_COUNT),
        .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT)
    ) parity_to_combination (
        .clk(clk),
        .reset(reset),
        .build_parity_table(build_parity_table),
        .find_first_combination_for_parity(find_first_combination_for_parity),
        .find_next_combination_for_combination(find_next_combination_for_combination),
        .flattened_buttons(latched_flattened_buttons),
        .combination_upper_bound(combination_upper_bound),
        .parity_to_search(parity_to_search),
        .previous_combination(previous_combination),

        .parity_table_complete(parity_table_complete),
        .request_ready(parity_table_request_ready),
        .parity_list_created(parity_list_created),
        .next_combination_valid(next_combination_valid),
        .first_combination_for_parity(first_combination_for_parity),
        .next_combination_for_combination(next_combination_for_combination)
    );
    
    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;

            // Signals that should be pulsed
            result_ready <= 0;
            push_element <= 0;
            pop_element <= 0;
            build_parity_table <= 0;
            find_first_combination_for_parity <= 0;
            find_next_combination_for_combination <= 0;
        end
        else begin
            // Signals that should be pulsed
            result_ready <= 0;
            push_element <= 0;
            pop_element <= 0;
            build_parity_table <= 0;
            find_first_combination_for_parity <= 0;
            find_next_combination_for_combination <= 0;

            case (state)
                IDLE: begin
                    if (start_LSU) begin
                        state <= BUILDING_PARITY_TABLE;
                        combination_upper_bound <= 0;
                        combination_upper_bound[button_count] <= 1;
                        latched_flattened_buttons <= flattened_buttons;

                        combination <= 0;
                        current_target <= flattened_machines;
                        current_min_button_press_count <= {ANSWER_BIT_WIDTH{1'b1}};
                        button_press_count_for_current_call <= 0;

                        build_parity_table <= 1;
                    end
                end
                BUILDING_PARITY_TABLE: begin
                    if (parity_table_complete) begin
                        state <= ITERATE_KNOWN_COMBINATIONS;
                        find_first_combination_for_parity <= 1;
                        parity_to_search <= current_target_parity;
                    end
                end
                ITERATE_KNOWN_COMBINATIONS: begin
                    if (combination == 0) begin
                        if (parity_table_request_ready) begin
                            if (parity_list_created) begin
                                state <= FINDING_NEW_TARGET;
                                hit_combination <= first_combination_for_parity;
                            end
                            else state <= FUNCTION_RETURN;
                        end
                    end
                    else begin
                        if (parity_table_request_ready) begin
                            if (next_combination_valid) begin
                                state <= FINDING_NEW_TARGET;
                                hit_combination <= next_combination_for_combination;
                            end
                            else state <= FUNCTION_RETURN;
                        end
                    end
                end
                FINDING_NEW_TARGET: state <= FUNCTION_CALL;
                FUNCTION_CALL: begin
                    state <= ITERATE_KNOWN_COMBINATIONS;
                    if (combination_no_negative && flattened_new_target != 0) begin
                        find_first_combination_for_parity <= 1;
                        parity_to_search <= flattened_new_target_parity;
                    end
                    else begin
                        find_next_combination_for_combination <= 1;
                        previous_combination <= hit_combination;
                        parity_to_search <= current_target_parity;
                    end

                    if (combination_no_negative) begin
                        if (flattened_new_target == 0) begin
                            combination <= hit_combination + 1;
                            if (current_min_button_press_count > one_count_in_hit_combination) current_min_button_press_count <= one_count_in_hit_combination;
                        end
                        else begin
                            push_element <= 1;
                            next_combination_to_stack <= hit_combination + 1;
                            target_to_stack <= current_target;
                            min_button_press_count_to_stack <= current_min_button_press_count;
                            button_press_count_for_call_to_stack <= button_press_count_for_current_call;

                            combination <= 0;
                            current_target <= flattened_new_target;
                            current_min_button_press_count <= {ANSWER_BIT_WIDTH{1'b1}};
                            button_press_count_for_current_call <= one_count_in_hit_combination;
                        end
                    end
                    else combination <= hit_combination + 1;
                end
                FUNCTION_RETURN: begin
                    if (stack_empty) begin
                        state <= IDLE;
                        result_ready <= 1;
                        result <= current_min_button_press_count;
                    end
                    else begin
                        state <= ITERATE_KNOWN_COMBINATIONS;
                        find_next_combination_for_combination <= 1;
                        previous_combination <= top_next_combination - 1;
                        parity_to_search <= top_target_parity;

                        pop_element <= 1;
                        combination <= top_next_combination;
                        current_target <= top_target;
                        if (current_min_button_press_count == {ANSWER_BIT_WIDTH{1'b1}}) current_min_button_press_count <= top_min_button_press_count;
                        else if (top_min_button_press_count > 2 * current_min_button_press_count + button_press_count_for_current_call) begin
                            current_min_button_press_count <= 2 * current_min_button_press_count + button_press_count_for_current_call;
                        end
                        else current_min_button_press_count <= top_min_button_press_count;
                        button_press_count_for_current_call <= top_button_press_count_for_call;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule