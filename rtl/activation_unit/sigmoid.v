// ============================================================================
// Module Name: sigmoid
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Piecewise Linear Approximation (PLAN) of Sigmoid:
//              f(x) = 1 / (1 + exp(-x)) in Q16.16 signed fixed-point.
//              Uses shift-and-add hardware with zero multiplier usage.
//              Range of output: [0.0, 1.0] -> [32'h0000_0000, 32'h0001_0000].
// ============================================================================

`timescale 1ns / 1ps

module sigmoid #(
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire signed [DATA_WIDTH-1:0] data_in,
    output reg  signed [DATA_WIDTH-1:0] data_out,
    output reg                    valid_out
);

    // Q16.16 Constants
    localparam signed [31:0] Q_ONE       = 32'h0001_0000; // 1.0
    localparam signed [31:0] Q_HALF      = 32'h0000_8000; // 0.5
    localparam signed [31:0] Q_FIVE      = 32'h0005_0000; // 5.0
    localparam signed [31:0] Q_2_375     = 32'h0002_6000; // 2.375
    localparam signed [31:0] Q_0_625     = 32'h0000_A000; // 0.625
    localparam signed [31:0] Q_0_84375   = 32'h0000_D800; // 0.84375

    // Absolute value of data_in
    wire is_negative;
    assign is_negative = data_in[DATA_WIDTH-1];

    wire signed [DATA_WIDTH-1:0] abs_x;
    assign abs_x = is_negative ? (-data_in) : data_in;

    // Piecewise Linear Function for positive branch:
    // Region 0: |x| >= 5.0             -> y_pos = 1.0
    // Region 1: 2.375 <= |x| < 5.0     -> y_pos = 0.84375 + |x| * 0.03125 (|x| >>> 5)
    // Region 2: 1.0 <= |x| < 2.375     -> y_pos = 0.625 + |x| * 0.125     (|x| >>> 3)
    // Region 3: 0 <= |x| < 1.0         -> y_pos = 0.5 + |x| * 0.25        (|x| >>> 2)

    reg signed [DATA_WIDTH-1:0] y_pos;

    always @(*) begin
        if (abs_x >= Q_FIVE) begin
            y_pos = Q_ONE;
        end else if (abs_x >= Q_2_375) begin
            y_pos = Q_0_84375 + (abs_x >>> 5);
        end else if (abs_x >= Q_ONE) begin
            y_pos = Q_0_625 + (abs_x >>> 3);
        end else begin
            y_pos = Q_HALF + (abs_x >>> 2);
        end
    end

    // Apply symmetry: f(-x) = 1.0 - f(x)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= {DATA_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (valid_in) begin
            valid_out <= 1'b1;
            if (is_negative) begin
                data_out <= Q_ONE - y_pos;
            end else begin
                data_out <= y_pos;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
