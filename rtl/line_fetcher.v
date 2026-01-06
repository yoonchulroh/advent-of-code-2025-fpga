`timescale 1ns / 1ps

module line_fetcher #(
    parameter CLKS_PER_BIT = 10416,
    parameter MACHINE_COUNT = 10,
    parameter MAX_BUTTON_COUNT = 13,
    parameter BITS_PER_JOLTAGE = 9
) (
    input clk,
    input uart_input,
    input reset,

    output reg new_line_given, // Is a pulse
    output reg [$clog2(MAX_BUTTON_COUNT + 1) - 1 : 0] button_count,
    output [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons,
    output [MACHINE_COUNT * BITS_PER_JOLTAGE - 1 : 0] flattened_machines
);

    localparam [1:0] IDLE = 2'b00,
                     RECEIVING_BUTTON_COUNT = 2'b01,
                     RECEIVING_BUTTONS = 2'b10,
                     RECEIVING_JOLTAGES = 2'b11;

    localparam BYTES_PER_BUTTON = (MACHINE_COUNT + 7) / 8;
    localparam BYTES_PER_JOLTAGE = (BITS_PER_JOLTAGE + 7) / 8;

    reg [1:0] state;

    // Signals for RECEIVING_BUTTONS
    reg [$clog2(MAX_BUTTON_COUNT > 1 ? MAX_BUTTON_COUNT : 2) - 1 : 0] button_index;
    reg [$clog2(BYTES_PER_BUTTON > 1 ? BYTES_PER_BUTTON : 2) - 1 : 0] button_byte_index;

    // Signals for RECEIVING_JOLTAGES
    reg [$clog2(MACHINE_COUNT > 1 ? MACHINE_COUNT : 2) - 1 : 0] joltage_index;
    reg [$clog2(BYTES_PER_JOLTAGE > 1 ? BYTES_PER_JOLTAGE : 2) - 1 : 0] joltage_byte_index;

    // Intermediate signals for output
    reg [MACHINE_COUNT - 1 : 0] buttons [MAX_BUTTON_COUNT - 1 : 0];
    reg [BITS_PER_JOLTAGE - 1 : 0] machines [MACHINE_COUNT - 1 : 0];

    wire new_byte;
    wire [7:0] byte_received;

    genvar i;
    integer j;

    generate
        for (i = 0; i < MAX_BUTTON_COUNT; i = i + 1) begin : loop_flatten_buttons
            assign flattened_buttons[i * MACHINE_COUNT +: MACHINE_COUNT] = buttons[i];
        end
        for (i = 0; i < MACHINE_COUNT; i = i + 1) begin : loop_flatten_machines
            assign flattened_machines[i * BITS_PER_JOLTAGE +: BITS_PER_JOLTAGE] = machines[i];
        end
    endgenerate

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) byte_receiver (
        .clk(clk),
        .uart_input(uart_input),
        .reset(reset),

        .byte_received(byte_received),
        .received(new_byte)
    );

    always @(posedge clk) begin
        if (reset) begin
            new_line_given <= 0;
            state <= IDLE;
        end
        else begin
            new_line_given <= 0;
            case (state)
                IDLE: begin
                    if (new_byte) begin
                        state <= RECEIVING_BUTTON_COUNT;
                        for (j = 0; j < MAX_BUTTON_COUNT; j = j + 1) buttons[j] <= 0;
                        for (j = 0; j < MACHINE_COUNT; j = j + 1) machines[j] <= 0;
                    end
                end
                RECEIVING_BUTTON_COUNT: begin
                    if (new_byte) begin
                        button_count <= byte_received;
                        button_index <= 0;
                        button_byte_index <= 0;
                        state <= RECEIVING_BUTTONS;
                    end
                end
                RECEIVING_BUTTONS: begin
                    if (new_byte) begin
                        buttons[button_index][button_byte_index * 8 +: 8] <= byte_received;
                        if (button_byte_index == BYTES_PER_BUTTON - 1) begin
                            button_byte_index <= 0;
                            if (button_index == button_count - 1) begin
                                state <= RECEIVING_JOLTAGES;
                                joltage_index <= 0;
                                joltage_byte_index <= 0;
                            end
                            else button_index <= button_index + 1;
                        end
                        else button_byte_index <= button_byte_index + 1;
                    end
                end
                RECEIVING_JOLTAGES: begin
                    if (new_byte) begin
                        machines[joltage_index][joltage_byte_index * 8 +: 8] <= byte_received;
                        if (joltage_byte_index == BYTES_PER_JOLTAGE - 1) begin
                            joltage_byte_index <= 0;
                            if (joltage_index == MACHINE_COUNT - 1) begin
                                state <= IDLE;
                                new_line_given <= 1;
                            end
                            else joltage_index <= joltage_index + 1;
                        end
                        else joltage_byte_index <= joltage_byte_index + 1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule