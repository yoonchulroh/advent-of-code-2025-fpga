`timescale 1ns / 1ps

module parity_to_combination_table #(
    parameter MACHINE_COUNT = 10,
    parameter MAX_BUTTON_COUNT = 13
) (
    input clk,
    input reset,

    // following signals must be exclusive. 
    input build_parity_table, // should be a pulse
    // ignored when parity_table_complete is not asserted
    input find_first_combination_for_parity, // should be a pulse
    input find_next_combination_for_combination, // should be a pulse

    input [MACHINE_COUNT * MAX_BUTTON_COUNT - 1 : 0] flattened_buttons,
    input [MAX_BUTTON_COUNT : 0] combination_upper_bound,
    input [MACHINE_COUNT - 1 : 0] parity_to_search,
    input [MAX_BUTTON_COUNT : 0] previous_combination,

    output parity_table_complete,
    output reg request_ready, // pulses when a request for fetch is fulfilled
    output reg parity_list_created, // 1 when there is an element in the parity list
    output reg next_combination_valid, // 1 when there is next combination for the given previous combination
    output reg [MAX_BUTTON_COUNT : 0] first_combination_for_parity, // output for find_first_combination
    output reg [MAX_BUTTON_COUNT : 0] next_combination_for_combination // output for find_next_combination
    );

    localparam [1:0] IDLE = 2'b00,
                     INSERT_FIRST_STAGE = 2'b01,
                     INSERT_SECOND_STAGE = 2'b10;
    reg [1:0] state;

    // Should be inferred as BRAM
    reg [MAX_BUTTON_COUNT : 0] BRAM_head_combination_for_parity [(1 << MACHINE_COUNT) - 1 : 0];
    reg [MACHINE_COUNT - 1 : 0] BRAM_head_combination_for_parity_address;
    reg [MAX_BUTTON_COUNT : 0] BRAM_head_combination_for_parity_data_to_write;
    reg BRAM_head_combination_for_parity_read, BRAM_head_combination_for_parity_write;

    // Should be inferred as BRAM
    reg [MAX_BUTTON_COUNT : 0] BRAM_tail_combination_for_parity [(1 << MACHINE_COUNT) - 1 : 0];
    reg [MACHINE_COUNT - 1 : 0] BRAM_tail_combination_for_parity_address;
    reg [MAX_BUTTON_COUNT : 0] BRAM_tail_combination_for_parity_data_to_write;
    reg BRAM_tail_combination_for_parity_read, BRAM_tail_combination_for_parity_write;

    // Linked list order must be in the order of insertion. First inserted -> first out
    // First bit is valid bit -> MAX_BUTTON_COUNT + 1 + 1 bits per combination
    // Should be inferred as BRAM
    reg [MAX_BUTTON_COUNT + 1 : 0] BRAM_next_combination_for_combination [(1 << MAX_BUTTON_COUNT) - 1 : 0];
    reg [MAX_BUTTON_COUNT - 1 : 0] BRAM_next_combination_for_combination_address;
    reg [MAX_BUTTON_COUNT + 1 : 0] BRAM_next_combination_for_combination_data_to_write;
    reg BRAM_next_combination_for_combination_read, BRAM_next_combination_for_combination_write;

    // Not intended for BRAM
    reg [(1 << MACHINE_COUNT) - 1 : 0] parity_list_created_array;

    // Signals for building the parity table
    reg [MAX_BUTTON_COUNT : 0] current_combination;
    reg [MAX_BUTTON_COUNT - 1 : 0] tail_combination;
    reg latched_parity_list_created;
    wire [MACHINE_COUNT - 1 : 0] parity_for_combination;

    combination_xor_result_finder #(
        .MACHINE_COUNT(MACHINE_COUNT),
        .MAX_BUTTON_COUNT(MAX_BUTTON_COUNT)
    ) parity_for_combination_finder (
        .combination(current_combination),
        .flattened_buttons(flattened_buttons),
        
        .combination_xor_result(parity_for_combination)
    );

    assign parity_table_complete = (state == IDLE) && (~build_parity_table);

    always @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            parity_list_created_array <= 0;

            request_ready <= 0;
        end
        else begin
            request_ready <= 0;

            if (build_parity_table) begin
                state <= INSERT_FIRST_STAGE;
                current_combination <= 0;
                parity_list_created_array <= 0; 
            end
            else begin
                case (state)
                    IDLE: begin
                        if (find_first_combination_for_parity) begin
                            request_ready <= 1;
                            parity_list_created <= parity_list_created_array[parity_to_search];
                        end
                        else if (find_next_combination_for_combination) request_ready <= 1;
                    end
                    INSERT_FIRST_STAGE: begin
                        if (current_combination >= combination_upper_bound) state <= IDLE;
                        else begin
                            state <= INSERT_SECOND_STAGE;

                            latched_parity_list_created <= parity_list_created_array[parity_for_combination];
                            parity_list_created_array[parity_for_combination] <= 1;
                        end
                    end
                    INSERT_SECOND_STAGE: begin
                        state <= INSERT_FIRST_STAGE;
                        current_combination <= current_combination + 1;
                    end
                    default: state <= IDLE;
                endcase
            end
        end

        if (BRAM_head_combination_for_parity_read) first_combination_for_parity <= BRAM_head_combination_for_parity[BRAM_head_combination_for_parity_address];
        if (BRAM_head_combination_for_parity_write) BRAM_head_combination_for_parity[BRAM_head_combination_for_parity_address] <= BRAM_head_combination_for_parity_data_to_write;

        if (BRAM_tail_combination_for_parity_read) tail_combination <= BRAM_tail_combination_for_parity[BRAM_tail_combination_for_parity_address];
        if (BRAM_tail_combination_for_parity_write) BRAM_tail_combination_for_parity[BRAM_tail_combination_for_parity_address] <= BRAM_tail_combination_for_parity_data_to_write;

        if (BRAM_next_combination_for_combination_read) {next_combination_valid, next_combination_for_combination} <= BRAM_next_combination_for_combination[BRAM_next_combination_for_combination_address];
        if (BRAM_next_combination_for_combination_write) BRAM_next_combination_for_combination[BRAM_next_combination_for_combination_address] <= BRAM_next_combination_for_combination_data_to_write;
    end

    always @(*) begin
        BRAM_head_combination_for_parity_read = 0;
        BRAM_head_combination_for_parity_write = 0;
        BRAM_head_combination_for_parity_address = 0;
        BRAM_head_combination_for_parity_data_to_write = 0;

        BRAM_tail_combination_for_parity_read = 0;
        BRAM_tail_combination_for_parity_write = 0;
        BRAM_tail_combination_for_parity_address = 0;
        BRAM_tail_combination_for_parity_data_to_write = 0;

        BRAM_next_combination_for_combination_read = 0;
        BRAM_next_combination_for_combination_write = 0;
        BRAM_next_combination_for_combination_address = 0;
        BRAM_next_combination_for_combination_data_to_write = 0;

        if (build_parity_table) ;
        else begin
            case (state)
                IDLE: begin
                    if (find_first_combination_for_parity) begin
                        BRAM_head_combination_for_parity_read = 1;
                        BRAM_head_combination_for_parity_address = parity_to_search;
                    end
                    else if (find_next_combination_for_combination) begin
                        BRAM_next_combination_for_combination_read = 1;
                        BRAM_next_combination_for_combination_address = previous_combination;
                    end
                end
                INSERT_FIRST_STAGE: begin
                    if (current_combination >= combination_upper_bound) ;
                    else begin
                        BRAM_next_combination_for_combination_write = 1;
                        BRAM_next_combination_for_combination_address = current_combination;
                        BRAM_next_combination_for_combination_data_to_write = 0;

                        BRAM_tail_combination_for_parity_read = 1;
                        BRAM_tail_combination_for_parity_address = parity_for_combination; 
                    end
                end
                INSERT_SECOND_STAGE: begin
                    BRAM_tail_combination_for_parity_write = 1;
                    BRAM_tail_combination_for_parity_address = parity_for_combination;
                    BRAM_tail_combination_for_parity_data_to_write = current_combination;

                    if (latched_parity_list_created) begin
                        BRAM_next_combination_for_combination_write = 1;
                        BRAM_next_combination_for_combination_address = tail_combination;
                        BRAM_next_combination_for_combination_data_to_write = {1'b1, current_combination};
                    end
                    else begin
                        BRAM_head_combination_for_parity_write = 1;
                        BRAM_head_combination_for_parity_address = parity_for_combination;
                        BRAM_head_combination_for_parity_data_to_write = current_combination;
                    end
                end
                default: ;
            endcase
        end
    end

endmodule