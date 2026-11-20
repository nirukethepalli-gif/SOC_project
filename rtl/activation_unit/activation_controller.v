// ============================================================================
// Module Name: activation_controller
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: FSM Controller for Activation Unit IP.
//              Manages vector length counting, input ready/valid handshaking,
//              output buffer writing, and completion signaling.
// ============================================================================

`timescale 1ns / 1ps

module activation_controller #(
    parameter ADDR_WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Control and configuration inputs
    input  wire                   start,
    input  wire                   soft_reset,
    input  wire [15:0]            vec_len,

    // Status outputs
    output reg                    busy,
    output reg                    done,

    // Handshake with upstream (Matrix Multiplier)
    input  wire                   in_valid,
    output reg                    in_ready,

    // Handshake with internal activation functions
    output reg                    act_en,

    // Handshake with downstream / output buffer
    input  wire                   act_valid_in,
    output reg                    out_buf_wr_en,
    output reg  [ADDR_WIDTH-1:0]  out_buf_wr_addr
);

    localparam [1:0] S_IDLE    = 2'b00,
                     S_PROCESS = 2'b01,
                     S_DRAIN   = 2'b10,
                     S_DONE    = 2'b11;

    reg [1:0] state, next_state;
    reg [15:0] in_count;
    reg [15:0] out_count;
    reg [15:0] reg_vec_len;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            in_count        <= 16'd0;
            out_count       <= 16'd0;
            reg_vec_len     <= 16'd0;
            busy            <= 1'b0;
            done            <= 1'b0;
            out_buf_wr_addr <= {ADDR_WIDTH{1'b0}};
        end else if (soft_reset) begin
            state           <= S_IDLE;
            in_count        <= 16'd0;
            out_count       <= 16'd0;
            busy            <= 1'b0;
            done            <= 1'b0;
            out_buf_wr_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy        <= 1'b1;
                        reg_vec_len <= (vec_len == 16'd0) ? 16'd1 : vec_len;
                        in_count    <= 16'd0;
                        out_count   <= 16'd0;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                S_PROCESS: begin
                    if (in_valid && in_ready) begin
                        in_count <= in_count + 1'b1;
                    end

                    if (act_valid_in) begin
                        out_count       <= out_count + 1'b1;
                        out_buf_wr_addr <= out_count[ADDR_WIDTH-1:0];
                    end
                end

                S_DRAIN: begin
                    if (act_valid_in) begin
                        out_count       <= out_count + 1'b1;
                        out_buf_wr_addr <= out_count[ADDR_WIDTH-1:0];
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        next_state    = state;
        in_ready      = 1'b0;
        act_en        = 1'b0;
        out_buf_wr_en = 1'b0;

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_PROCESS;
            end

            S_PROCESS: begin
                in_ready = (in_count < reg_vec_len);
                act_en   = in_valid && in_ready;
                out_buf_wr_en = act_valid_in;

                if (in_count == reg_vec_len) begin
                    if (out_count == reg_vec_len)
                        next_state = S_DONE;
                    else
                        next_state = S_DRAIN;
                end
            end

            S_DRAIN: begin
                out_buf_wr_en = act_valid_in;
                if (out_count == reg_vec_len)
                    next_state = S_DONE;
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

endmodule
