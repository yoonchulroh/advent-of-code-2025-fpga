`timescale 1ns / 1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 10416
) (
    input clk,
    input reset,
    input start_transmission,
    input [7:0] byte_to_send,
    output reg uart_output,
    output busy);

    localparam IDLE = 2'b00,
               START_BIT = 2'b01,
               DATA_BITS = 2'b10,
               STOP_BIT = 2'b11;

    reg [1:0] state;
    reg [15:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] latched_byte_to_send;

    reg [1:0] next_state;
    reg [15:0] next_clock_count;
    reg [2:0] next_bit_index;

    assign busy = (state != IDLE) || (start_transmission);

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            clock_count <= 0;
            bit_index <= 0;
            uart_output <= 1'b1;
        end
        else begin
            state <= next_state;
            clock_count <= next_clock_count;
            bit_index <= next_bit_index;

            case (state)
                IDLE: begin
                    uart_output <= 1'b1;
                    latched_byte_to_send <= byte_to_send;
                end
                START_BIT: uart_output <= 1'b0;
                DATA_BITS: uart_output <= latched_byte_to_send[bit_index];
                STOP_BIT: uart_output <= 1'b1;
                default: uart_output <= 1'b1;
            endcase
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
                if (start_transmission) begin
                    next_state = START_BIT;
                    next_clock_count = 0;
                end
                else next_state = IDLE;
            end
            START_BIT: begin
                if (clock_count < CLKS_PER_BIT - 1) next_state = START_BIT;
                else next_state = DATA_BITS;
            end
            DATA_BITS: begin
                if (clock_count < CLKS_PER_BIT - 1) next_state = DATA_BITS;
                else begin
                    if (bit_index < 7) next_state = DATA_BITS;
                    else next_state = STOP_BIT;
                end
            end
            STOP_BIT: begin
                if (clock_count < CLKS_PER_BIT - 1) next_state = STOP_BIT;
                else next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule