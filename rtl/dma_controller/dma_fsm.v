// ============================================================================
// Module Name: dma_fsm
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Main Control State Machine for DMA Controller.
//              Sequences memory-to-accelerator and accelerator-to-memory
//              transactions, manages address stepping, and signals status.
// ============================================================================

`timescale 1ns / 1ps

module dma_fsm (
    input  wire        clk,
    input  wire        rst_n,

    // Register interface
    input  wire        ctrl_start,
    input  wire        ctrl_soft_reset,
    input  wire        direction,     // 0: Mem->Acc, 1: Acc->Mem
    input  wire [1:0]  acc_target,    // 00: In, 01: Weight, 10: Bias, 11: Act_Out
    output reg         status_busy,
    output reg         status_done,
    output reg         status_error,

    // Address Generator interface
    output reg         load_init,
    output reg         step_src,
    output reg         step_dst,
    input  wire        transfer_complete,
    input  wire        align_error,

    // Read Controller interface
    output reg         start_read,
    input  wire        read_busy,
    input  wire        read_done,
    input  wire        read_error,

    // Write Controller interface
    output reg         start_write,
    input  wire        write_busy,
    input  wire        write_done,
    input  wire        write_error,

    // Data Transfer Engine / Accelerator Staging interface
    output reg         stage_data_en,
    input  wire        stage_busy
);

    localparam [2:0] S_IDLE    = 3'b000,
                     S_INIT    = 3'b001,
                     S_READ    = 3'b010,
                     S_WRITE   = 3'b011,
                     S_STEP    = 3'b100,
                     S_DONE    = 3'b101,
                     S_ERROR   = 3'b110;

    reg [2:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            status_busy  <= 1'b0;
            status_done  <= 1'b0;
            status_error <= 1'b0;
        end else if (ctrl_soft_reset) begin
            state        <= S_IDLE;
            status_busy  <= 1'b0;
            status_done  <= 1'b0;
            status_error <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    status_done <= 1'b0;
                    if (ctrl_start) begin
                        status_busy  <= 1'b1;
                        status_error <= 1'b0;
                    end else begin
                        status_busy  <= 1'b0;
                    end
                end

                S_DONE: begin
                    status_busy <= 1'b0;
                    status_done <= 1'b1;
                end

                S_ERROR: begin
                    status_busy  <= 1'b0;
                    status_error <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        next_state    = state;
        load_init     = 1'b0;
        start_read    = 1'b0;
        start_write   = 1'b0;
        stage_data_en = 1'b0;
        step_src      = 1'b0;
        step_dst      = 1'b0;

        case (state)
            S_IDLE: begin
                if (ctrl_start) begin
                    load_init  = 1'b1;
                    next_state = S_INIT;
                end
            end

            S_INIT: begin
                if (align_error) begin
                    next_state = S_ERROR;
                end else if (transfer_complete) begin
                    next_state = S_DONE;
                end else if (direction == 1'b0) begin
                    // Memory -> Accelerator: Start by reading from memory
                    start_read = 1'b1;
                    next_state = S_READ;
                end else begin
                    // Accelerator -> Memory: Trigger staging then write
                    stage_data_en = 1'b1;
                    next_state    = S_WRITE;
                end
            end

            S_READ: begin
                if (read_error) begin
                    next_state = S_ERROR;
                end else if (read_done) begin
                    stage_data_en = 1'b1;
                    next_state    = S_STEP;
                end
            end

            S_WRITE: begin
                start_write = 1'b1;
                if (write_error) begin
                    next_state = S_ERROR;
                end else if (write_done) begin
                    next_state = S_STEP;
                end
            end

            S_STEP: begin
                step_src = 1'b1;
                step_dst = 1'b1;
                if (transfer_complete) begin
                    next_state = S_DONE;
                end else if (direction == 1'b0) begin
                    start_read = 1'b1;
                    next_state = S_READ;
                end else begin
                    stage_data_en = 1'b1;
                    next_state    = S_WRITE;
                end
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            S_ERROR: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule
