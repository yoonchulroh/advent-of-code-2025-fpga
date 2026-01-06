`timescale 1ns / 1ps

module line_buffer #(
    parameter BUFFER_SIZE = 178,
    parameter MAX_BUTTON_COUNT = 13,
    parameter MACHINE_COUNT = 10,
    parameter BITS_PER_JOLTAGE = 9
) (
    input clk,
    input reset,
    // push and pop should be mutually exclusive
    input push_element, // should be a pulse
    input pop_element, // should be a pulse
    input [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] button_count,
    input [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons,
    input [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_machines,

    // buffer outputs are valid two cycles after push/pop signals.
    // RAW hazard when reading right after push/pop
    output reg buffer_not_empty,
    output reg [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] top_button_count,
    output reg [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] top_flattened_buttons,
    output reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] top_flattened_machines
);

    // buffer_start contains the first element, buffer_end is the next index after the last element.
    // buffer_element_end - buffer_element_start = buffer_element_count (except when full)
    reg [$clog2(BUFFER_SIZE) - 1 : 0] buffer_element_start, buffer_element_end; 
    reg [$clog2(BUFFER_SIZE + 1) - 1 : 0] buffer_element_count;

    reg [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] button_count_buffer [BUFFER_SIZE - 1 : 0];
    reg [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons_buffer [BUFFER_SIZE - 1 : 0];
    reg [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_machines_buffer [BUFFER_SIZE - 1 : 0];

    always @(posedge clk) begin
        if (reset) begin
            buffer_element_start <= 0;
            buffer_element_end <= 0;
            buffer_element_count <= 0;
            buffer_not_empty <= 0;
        end
        else begin
            if (push_element && buffer_element_count < BUFFER_SIZE) begin
                if (buffer_element_end == BUFFER_SIZE - 1) buffer_element_end <= 0;
                else buffer_element_end <= buffer_element_end + 1;
                buffer_element_count <= buffer_element_count + 1;

                button_count_buffer[buffer_element_end] <= button_count;
                flattened_buttons_buffer[buffer_element_end] <= flattened_buttons;
                flattened_machines_buffer[buffer_element_end] <= flattened_machines;
            end
            else if (pop_element && buffer_element_count > 0) begin
                if (buffer_element_start == BUFFER_SIZE - 1) buffer_element_start <= 0;
                else buffer_element_start <= buffer_element_start + 1;
                buffer_element_count <= buffer_element_count - 1;
            end
            else begin
                if (buffer_element_count == 0) begin
                    buffer_not_empty <= 0;
                end
                else begin
                    buffer_not_empty <= 1;
                    top_button_count <= button_count_buffer[buffer_element_start];
                    top_flattened_buttons <= flattened_buttons_buffer[buffer_element_start];
                    top_flattened_machines <= flattened_machines_buffer[buffer_element_start];
                end
            end
        end
    end

endmodule