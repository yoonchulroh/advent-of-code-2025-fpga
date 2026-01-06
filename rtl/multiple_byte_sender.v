`timescale 1ns / 1ps

module multiple_byte_sender #(
    parameter CLKS_PER_BIT = 10416,
    parameter BUFFER_SIZE = 178,
    parameter MAX_BITS_TO_SEND = 128
) (
    input clk,
    input reset,
    input new_data_to_send, // should be a pulse
    input [MAX_BITS_TO_SEND - 1 : 0] data, // sends the data in little endian format
    input [$clog2(MAX_BITS_TO_SEND + 1) - 1 : 0] number_of_bits_to_send,

    output uart_output);

    localparam IDLE = 0,
               SENDING_BYTES = 1;
    localparam MAX_BYTES_TO_SEND = (MAX_BITS_TO_SEND + 7) / 8;

    reg state;
    reg number_of_bytes_sent;
    reg [$clog2(MAX_BYTES_TO_SEND > 1 ? MAX_BYTES_TO_SEND : 2) - 1 : 0] byte_index;
    reg [MAX_BYTES_TO_SEND * 8 - 1 : 0] latched_data;
    reg [$clog2(MAX_BYTES_TO_SEND + 1) - 1 : 0] latched_number_of_bytes_to_send;

    reg uart_tx_start_transmission;
    reg [7:0] uart_tx_byte_to_send;
    wire uart_tx_busy;

    // Signals for sender buffer
    reg push_element_to_buffer, pop_element_from_buffer;
    reg [MAX_BITS_TO_SEND - 1 : 0] data_to_buffer;
    reg [$clog2(MAX_BITS_TO_SEND + 1) - 1 : 0] number_of_bits_to_send_to_buffer;
    wire buffer_not_empty;
    wire [MAX_BITS_TO_SEND - 1 : 0] top_data_to_send;
    wire [$clog2(MAX_BITS_TO_SEND + 1) - 1 : 0] top_number_of_bits_to_send;

    reg [1:0] delay_for_buffer;

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) byte_sender (
        .clk(clk),
        .reset(reset),
        .start_transmission(uart_tx_start_transmission),
        .byte_to_send(uart_tx_byte_to_send),

        .uart_output(uart_output),
        .busy(uart_tx_busy)
    );

    sender_buffer #(
        .BUFFER_SIZE(BUFFER_SIZE),
        .MAX_BITS_TO_SEND(MAX_BITS_TO_SEND)
    ) buffer (
        .clk(clk),
        .reset(reset),
        .push_element(push_element_to_buffer),
        .pop_element(pop_element_from_buffer),
        .data_to_send(data_to_buffer),
        .number_of_bits_to_send(number_of_bits_to_send_to_buffer),

        .buffer_not_empty(buffer_not_empty),
        .top_data_to_send(top_data_to_send),
        .top_number_of_bits_to_send(top_number_of_bits_to_send)
    );

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            uart_tx_start_transmission <= 0;
            push_element_to_buffer <= 0;
            pop_element_from_buffer <= 0;
        end
        else begin
            uart_tx_start_transmission <= 0;
            push_element_to_buffer <= 0;
            pop_element_from_buffer <= 0;
            if (delay_for_buffer > 0) delay_for_buffer <= delay_for_buffer - 1;

            if (new_data_to_send) begin
                push_element_to_buffer <= 1;
                data_to_buffer <= data;
                number_of_bits_to_send_to_buffer <= number_of_bits_to_send;
                delay_for_buffer <= 2'b11;
            end

            if (state == IDLE) begin
                if (buffer_not_empty && delay_for_buffer == 0 && ~new_data_to_send && top_number_of_bits_to_send != 0) begin
                    state <= SENDING_BYTES;
                    pop_element_from_buffer <= 1;
                    delay_for_buffer <= 2'b11;

                    number_of_bytes_sent <= 0;
                    byte_index <= 0;
                    latched_data <= top_data_to_send;
                    latched_number_of_bytes_to_send <= (top_number_of_bits_to_send + 7) / 8;
                end
            end
            if (state == SENDING_BYTES) begin
                if (~uart_tx_busy) begin
                    if (number_of_bytes_sent == 0) begin
                        number_of_bytes_sent <= 1;
                        uart_tx_start_transmission <= 1;
                        uart_tx_byte_to_send <= latched_number_of_bytes_to_send;
                    end
                    else begin
                        uart_tx_start_transmission <= 1;
                        uart_tx_byte_to_send <= latched_data[byte_index * 8 +: 8];
                        if (byte_index == latched_number_of_bytes_to_send - 1) state <= IDLE;
                        else byte_index <= byte_index + 1;
                    end
                end
            end
        end
    end

endmodule