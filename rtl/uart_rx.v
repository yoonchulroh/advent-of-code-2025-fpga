`timescale 1ns / 1ps
module uart_rx #(
        parameter CLKS_PER_BIT = 10416
) (
    input clk,
    input uart_input,
    input reset,
    output reg [7:0] byte_received,
    output reg received);

    localparam [1:0] IDLE = 2'b00,
                     START_BIT = 2'b01,
                     DATA_BITS = 2'b10,
                     CLEANUP = 2'b11;

    reg uart_input_sync1, uart_input_sync2;

    reg [1:0] state, next_state;

    reg [15:0] clock_count, next_clock_count;

    reg [2:0] bit_index, next_bit_index;

    reg next_received;

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            clock_count <= 0;
            bit_index <= 0;
            received <= 0;
        end
        else begin
            uart_input_sync1 <= uart_input;
            uart_input_sync2 <= uart_input_sync1;

            state <= next_state;
            clock_count <= next_clock_count;
            bit_index <= next_bit_index;
            received <= next_received;

            if (state == DATA_BITS && clock_count == CLKS_PER_BIT - 1) byte_received[bit_index] <= uart_input_sync2;
        end
    end

    always @(*) begin
        if (clock_count < CLKS_PER_BIT - 1) next_clock_count = clock_count + 1;
        else next_clock_count = 0;

        if (state == DATA_BITS) begin
            if (clock_count < CLKS_PER_BIT - 1) next_bit_index = bit_index;
            else next_bit_index = bit_index + 1;
        end
        else next_bit_index = 0;

        case (state)
            IDLE: begin
                next_state = (uart_input_sync2 == 0) ? START_BIT : IDLE;
                next_clock_count = 0;
            end
            START_BIT: begin
                if (clock_count == CLKS_PER_BIT / 2) begin
                    next_state = (uart_input_sync2 == 0) ? DATA_BITS : IDLE;
                    next_clock_count = 0;
                end
                else next_state = START_BIT;
            end
            DATA_BITS: begin
                if (clock_count < CLKS_PER_BIT - 1) next_state = DATA_BITS;
                else next_state = (bit_index < 7) ? DATA_BITS : CLEANUP;
            end
            CLEANUP: begin
                if (clock_count < CLKS_PER_BIT - 1) next_state = CLEANUP;
                else next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase

        if (state == CLEANUP && clock_count == CLKS_PER_BIT - 1) next_received = 1;
        else next_received = 0;
    end
endmodule
