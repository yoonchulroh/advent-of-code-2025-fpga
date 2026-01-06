`timescale 1ns / 1ps

module sender_buffer #(
    parameter BUFFER_SIZE = 178,
    parameter MAX_BITS_TO_SEND = 128
) (
    input clk,
    input reset,
    // push and pop should be mutually exclusive
    input push_element, // should be a pulse
    input pop_element, // should be a pulse
    input [MAX_BITS_TO_SEND - 1 : 0] data_to_send,
    input [$clog2(MAX_BITS_TO_SEND + 1) - 1 : 0] number_of_bits_to_send,

    // buffer outputs are valid two cycles after push/pop signals.
    // RAW hazard when reading right after push/pop
    output reg buffer_not_empty,
    output reg [MAX_BITS_TO_SEND - 1 : 0] top_data_to_send,
    output reg [$clog2(MAX_BITS_TO_SEND + 1) - 1 : 0] top_number_of_bits_to_send
);

    // buffer_start contains the first element, buffer_end is the next index after the last element.
    // buffer_element_end - buffer_element_start = buffer_element_count (except when full)
    reg [$clog2(BUFFER_SIZE) - 1 : 0] buffer_element_start, buffer_element_end; 
    reg [$clog2(BUFFER_SIZE + 1) - 1 : 0] buffer_element_count;

    reg [MAX_BITS_TO_SEND - 1 : 0] data_to_send_buffer [BUFFER_SIZE - 1 : 0];
    reg [$clog2(MAX_BITS_TO_SEND + 1) - 1 : 0] number_of_bits_to_send_buffer [BUFFER_SIZE - 1 : 0];

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

                data_to_send_buffer[buffer_element_end] <= data_to_send;
                number_of_bits_to_send_buffer[buffer_element_end] <= number_of_bits_to_send;
            end
            else if (pop_element && buffer_element_count > 0) begin
                if (buffer_element_start == BUFFER_SIZE - 1) buffer_element_start <= 0;
                else buffer_element_start <= buffer_element_start + 1;
                buffer_element_count <= buffer_element_count - 1;
            end
            else begin
                if (buffer_element_count == 0) buffer_not_empty <= 0;
                else begin
                    buffer_not_empty <= 1;
                    top_data_to_send <= data_to_send_buffer[buffer_element_start];
                    top_number_of_bits_to_send <= number_of_bits_to_send_buffer[buffer_element_start];
                end
            end
        end
    end

endmodule