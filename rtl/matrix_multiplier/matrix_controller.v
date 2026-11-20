// ============================================================================
// Module Name: matrix_controller
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: FSM Controller sequencing Matrix-Vector multiplication:
//              Y = W * X + B.
//              Iterates through M rows and K dot-product accumulations.
//              Controls buffer read addresses, MAC clear/enable, bias addition,
//              output storage, and streaming to the Activation Unit.
// ============================================================================

`timescale 1ns / 1ps

module matrix_controller #(
    parameter DATA_WIDTH = 32,
    parameter IN_ADDR_W  = 8,
    parameter W_ADDR_W   = 10,
    parameter OUT_ADDR_W = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Control and configuration inputs
    input  wire                   start,
    input  wire                   soft_reset,
    input  wire [7:0]             dim_m,         // Number of output rows (1 to 256)
    input  wire [7:0]             dim_k,         // Number of input features (1 to 256)

    // Status outputs
    output reg                    busy,
    output reg                    done,

    // Input Buffer control (Vector X)
    output reg                    in_buf_rd_en,
    output reg  [IN_ADDR_W-1:0]   in_buf_rd_addr,

    // Weight Buffer control (Matrix W)
    output reg                    w_buf_rd_en,
    output reg  [W_ADDR_W-1:0]    w_buf_rd_addr,

    // Bias Adder control
    output reg                    bias_rd_en,
    output reg  [OUT_ADDR_W-1:0]  bias_rd_addr,
    output reg                    bias_add_en,

    // MAC Unit control
    output reg                    mac_en,
    output reg                    mac_clr_acc,

    // Output Buffer control (Vector Y)
    output reg                    out_buf_wr_en,
    output reg  [OUT_ADDR_W-1:0]  out_buf_wr_addr,

    // Direct streaming port to Activation Unit
    output reg  [DATA_WIDTH-1:0]  stream_out_data,
    output reg                    stream_out_valid,
    input  wire                   stream_out_ready,

    // Internal datapath feedback
    input  wire [DATA_WIDTH-1:0]  y_bias_result,
    input  wire                   y_bias_valid
);

    // FSM State Encoding
    localparam [2:0] S_IDLE         = 3'b000,
                     S_READ_MEM     = 3'b001,
                     S_MAC_EXEC     = 3'b010,
                     S_BIAS_WAIT    = 3'b011,
                     S_STORE_STREAM = 3'b100,
                     S_DONE         = 3'b101;

    reg [2:0] state, next_state;

    // Internal loop counters
    reg [7:0] row_m;       // Current row (0 to dim_m-1)
    reg [7:0] col_k;       // Current column (0 to dim_k-1)
    reg [W_ADDR_W-1:0] w_linear_addr; // Flat index in weight memory: m * K + k

    // Registered dimensions
    reg [7:0] reg_m;
    reg [7:0] reg_k;

    // Sequential state register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            row_m         <= 8'd0;
            col_k         <= 8'd0;
            w_linear_addr <= {W_ADDR_W{1'b0}};
            reg_m         <= 8'd0;
            reg_k         <= 8'd0;
            busy          <= 1'b0;
            done          <= 1'b0;
        end else if (soft_reset) begin
            state         <= S_IDLE;
            row_m         <= 8'd0;
            col_k         <= 8'd0;
            w_linear_addr <= {W_ADDR_W{1'b0}};
            busy          <= 1'b0;
            done          <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy          <= 1'b1;
                        reg_m         <= (dim_m == 8'd0) ? 8'd1 : dim_m;
                        reg_k         <= (dim_k == 8'd0) ? 8'd1 : dim_k;
                        row_m         <= 8'd0;
                        col_k         <= 8'd0;
                        w_linear_addr <= {W_ADDR_W{1'b0}};
                    end else begin
                        busy <= 1'b0;
                    end
                end

                S_READ_MEM: begin
                    // Addresses issued in combinatorial block; memory read takes 1 cycle
                end

                S_MAC_EXEC: begin
                    if (col_k == reg_k - 1'b1) begin
                        // Reached end of current row accumulation
                        col_k <= 8'd0;
                    end else begin
                        col_k         <= col_k + 1'b1;
                        w_linear_addr <= w_linear_addr + 1'b1;
                    end
                end

                S_BIAS_WAIT: begin
                    // Waiting for bias adder pipelined addition
                end

                S_STORE_STREAM: begin
                    if (stream_out_ready || !stream_out_valid) begin
                        if (row_m == reg_m - 1'b1) begin
                            // All rows complete
                        end else begin
                            row_m         <= row_m + 1'b1;
                            col_k         <= 8'd0;
                            w_linear_addr <= w_linear_addr + 1'b1;
                        end
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next-state logic and datapath control signals
    always @(*) begin
        next_state       = state;
        in_buf_rd_en     = 1'b0;
        in_buf_rd_addr   = col_k[IN_ADDR_W-1:0];
        w_buf_rd_en      = 1'b0;
        w_buf_rd_addr    = w_linear_addr;
        bias_rd_en       = 1'b0;
        bias_rd_addr     = row_m[OUT_ADDR_W-1:0];
        bias_add_en      = 1'b0;
        mac_en           = 1'b0;
        mac_clr_acc      = (col_k == 8'd0);
        out_buf_wr_en    = 1'b0;
        out_buf_wr_addr  = row_m[OUT_ADDR_W-1:0];

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_READ_MEM;
            end

            S_READ_MEM: begin
                in_buf_rd_en = 1'b1;
                w_buf_rd_en  = 1'b1;
                next_state   = S_MAC_EXEC;
            end

            S_MAC_EXEC: begin
                mac_en = 1'b1;
                if (col_k == reg_k - 1'b1) begin
                    // Completed dot-product for row_m
                    bias_rd_en  = 1'b1;
                    bias_add_en = 1'b1;
                    next_state  = S_BIAS_WAIT;
                end else begin
                    // Read next element
                    in_buf_rd_en = 1'b1;
                    w_buf_rd_en  = 1'b1;
                    next_state   = S_READ_MEM;
                end
            end

            S_BIAS_WAIT: begin
                if (y_bias_valid) begin
                    out_buf_wr_en = 1'b1;
                    next_state    = S_STORE_STREAM;
                end
            end

            S_STORE_STREAM: begin
                if (stream_out_ready || !stream_out_valid) begin
                    if (row_m == reg_m - 1'b1) begin
                        next_state = S_DONE;
                    end else begin
                        next_state = S_READ_MEM;
                    end
                end
            end

            S_DONE: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Streaming output register handshake
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stream_out_data  <= {DATA_WIDTH{1'b0}};
            stream_out_valid <= 1'b0;
        end else if (soft_reset) begin
            stream_out_data  <= {DATA_WIDTH{1'b0}};
            stream_out_valid <= 1'b0;
        end else if (state == S_BIAS_WAIT && y_bias_valid) begin
            stream_out_data  <= y_bias_result;
            stream_out_valid <= 1'b1;
        end else if (stream_out_valid && stream_out_ready) begin
            stream_out_valid <= 1'b0;
        end
    end

endmodule
