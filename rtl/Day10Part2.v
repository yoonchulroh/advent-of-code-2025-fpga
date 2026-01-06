`timescale 1ns / 1ps

module Day10Part2 (
    input clk,
    input reset,
    input uart_input,
    output uart_output);

    parameter BAUD_RATE = 5_000_000;
    parameter CLK_FREQUENCY = 100_000_000;
    parameter MACHINE_COUNT = 10;
    parameter MAX_BUTTON_COUNT = 13;
    parameter BITS_PER_JOLTAGE = 9;
    parameter ANSWER_BIT_WIDTH = 24;
    parameter STACK_SIZE = 10;
    parameter LSU_COUNT = 4;
    parameter BUFFER_SIZE = 200;

    localparam CLKS_PER_BIT = CLK_FREQUENCY / BAUD_RATE;
    localparam MAX_BITS_TO_SEND = ANSWER_BIT_WIDTH;

    genvar i;
    integer j;

    // Output wires from line_fetcher
    wire new_line_given;
    wire [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] button_count;
    wire [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons;
    wire [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_machines;

    // Signals for multiple_byte_sender
    reg new_data_to_send;
    reg [MAX_BITS_TO_SEND - 1 : 0] data_to_send;
    reg [$clog2(MAX_BITS_TO_SEND + 1) - 1 : 0] number_of_bits_to_send;

    // Signals for LSUs
    reg [LSU_COUNT - 1 : 0] start_LSU;
    reg [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] button_count_for_LSU [LSU_COUNT - 1 : 0];
    reg [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons_for_LSU [LSU_COUNT - 1 : 0];
    reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_machines_for_LSU [LSU_COUNT - 1 : 0];
    wire LSU_available [LSU_COUNT - 1 : 0];
    wire LSU_result_ready [LSU_COUNT - 1 : 0];
    wire [ANSWER_BIT_WIDTH - 1 : 0] LSU_result [LSU_COUNT - 1 : 0];

    // Signals for line buffer
    reg push_element_to_buffer, pop_element_from_buffer;
    reg [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] button_count_to_buffer;
    reg [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons_to_buffer;
    reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_machines_to_buffer;
    wire buffer_not_empty;
    wire [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] top_button_count;
    wire [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] top_flattened_buttons;
    wire [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] top_flattened_machines;

    // Signals for choosing available LSU
    reg [1:0] delay_for_buffer;
    reg LSU_to_start_decided;

    // Signals for final answer
    reg [ANSWER_BIT_WIDTH - 1 : 0] latched_LSU_result [LSU_COUNT - 1 : 0];
    reg LSU_result_to_send_decided;
    reg [ANSWER_BIT_WIDTH - 1 : 0] total_button_press_count;

    line_fetcher #(
        .CLKS_PER_BIT(CLKS_PER_BIT),
        .MACHINE_COUNT(MACHINE_COUNT),
        .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT),
        .BITS_PER_JOLTAGE(BITS_PER_JOLTAGE)
    ) fetcher (
        .clk(clk),
        .uart_input(uart_input),
        .reset(reset),

        .new_line_given(new_line_given),
        .button_count(button_count),
        .flattened_buttons(flattened_buttons),
        .flattened_machines(flattened_machines)
    );

    multiple_byte_sender #(
        .CLKS_PER_BIT(CLKS_PER_BIT),
        .BUFFER_SIZE(BUFFER_SIZE),
        .MAX_BITS_TO_SEND(MAX_BITS_TO_SEND)
    ) sender (
        .clk(clk),
        .reset(reset),
        .new_data_to_send(new_data_to_send),
        .data(data_to_send),
        .number_of_bits_to_send(number_of_bits_to_send),

        .uart_output(uart_output)
    );

    generate
        for (i = 0; i < LSU_COUNT; i = i + 1) begin : loop_line_solving_unit
            line_solving_unit #(
                .MACHINE_COUNT(MACHINE_COUNT),
                .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT),
                .BITS_PER_JOLTAGE(BITS_PER_JOLTAGE),
                .ANSWER_BIT_WIDTH(ANSWER_BIT_WIDTH),
                .STACK_SIZE(STACK_SIZE)
            ) LSU (
                .clk(clk),
                .reset(reset),
                .start_LSU(start_LSU[i]),
                .button_count(button_count_for_LSU[i]),
                .flattened_buttons(flattened_buttons_for_LSU[i]),
                .flattened_machines(flattened_machines_for_LSU[i]),

                .available(LSU_available[i]),
                .result_ready(LSU_result_ready[i]),
                .result(LSU_result[i])
            );
        end  
    endgenerate

    line_buffer #(
        .BUFFER_SIZE(BUFFER_SIZE),
        .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT),
        .MACHINE_COUNT(MACHINE_COUNT),
        .BITS_PER_JOLTAGE(BITS_PER_JOLTAGE)
    ) line_buffer (
        .clk(clk),
        .reset(reset),
        .push_element(push_element_to_buffer),
        .pop_element(pop_element_from_buffer),
        .button_count(button_count_to_buffer),
        .flattened_buttons(flattened_buttons_to_buffer),
        .flattened_machines(flattened_machines_to_buffer),
        
        .buffer_not_empty(buffer_not_empty),
        .top_button_count(top_button_count),
        .top_flattened_buttons(top_flattened_buttons),
        .top_flattened_machines(top_flattened_machines)
    );

    always @(posedge clk) begin
        if (reset) begin
            push_element_to_buffer <= 0;
            pop_element_from_buffer <= 0;
            start_LSU <= 0;
            new_data_to_send <= 0;
            total_button_press_count <= 0;
            for (j = 0; j < LSU_COUNT; j = j + 1) latched_LSU_result[j] <= 0;
        end
        else begin
            push_element_to_buffer <= 0;
            pop_element_from_buffer <= 0;
            start_LSU <= 0;
            new_data_to_send <= 0;
            if (delay_for_buffer > 0) delay_for_buffer <= delay_for_buffer - 1;

            if (new_line_given) begin
                push_element_to_buffer <= 1;
                button_count_to_buffer <= button_count;
                flattened_buttons_to_buffer <= flattened_buttons;
                flattened_machines_to_buffer <= flattened_machines;
                delay_for_buffer <= 2'b11;
            end
            else if (buffer_not_empty && delay_for_buffer == 0) begin
                LSU_to_start_decided = 0;
                for (j = 0; j < LSU_COUNT; j = j + 1) begin
                    if (LSU_available[j] && latched_LSU_result[j] == 0 && ~LSU_to_start_decided) begin
                        start_LSU[j] <= 1;
                        pop_element_from_buffer <= 1;
                        delay_for_buffer <= 2'b11;
                        button_count_for_LSU[j] <= top_button_count;
                        flattened_buttons_for_LSU[j] <= top_flattened_buttons;
                        flattened_machines_for_LSU[j] <= top_flattened_machines;
                        LSU_to_start_decided = 1;
                    end
                end
            end

            LSU_result_to_send_decided = 0;
            for (j = 0; j < LSU_COUNT; j = j + 1) begin
                if (LSU_result_ready[j]) latched_LSU_result[j] <= LSU_result[j];

                if (latched_LSU_result[j] != 0 && ~LSU_result_to_send_decided) begin
                    new_data_to_send <= 1;
                    total_button_press_count <= total_button_press_count + LSU_result[j];
                    data_to_send <= total_button_press_count + LSU_result[j];
                    number_of_bits_to_send <= ANSWER_BIT_WIDTH;

                    LSU_result_to_send_decided = 1;
                    latched_LSU_result[j] <= 0;
                end
            end
        end
    end

endmodule