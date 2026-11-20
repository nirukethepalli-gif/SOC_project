// ============================================================================
// Module Name: tanh
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Piecewise Linear Approximation (PLAN) of Hyperbolic Tangent:
//              f(x) = tanh(x) in Q16.16 signed fixed-point format.
//              Uses shift-and-add logic with zero multiplier cost.
//              Output range: [-1.0, +1.0] -> [-32'h0001_0000, +32'h0001_0000].
// ============================================================================

`timescale 1ns / 1ps

module tanh #(
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
    localparam signed [31:0] Q_THREE     = 32'h0003_0000; // 3.0
    localparam signed [31:0] Q_1_5       = 32'h0001_8000; // 1.5
    localparam signed [31:0] Q_HALF      = 32'h0000_8000; // 0.5
    localparam signed [31:0] Q_QUARTER   = 32'h0000_4000; // 0.25
    localparam signed [31:0] Q_0_8125    = 32'h0000_D000; // 0.8125

    wire is_negative;
    assign is_negative = data_in[DATA_WIDTH-1];

    wire signed [DATA_WIDTH-1:0] abs_x;
    assign abs_x = is_negative ? (-data_in) : data_in;

    // Piecewise Linear Function for positive branch:
    // Region 0: |x| >= 3.0         -> y_pos = 1.0
    // Region 1: 1.5 <= |x| < 3.0   -> y_pos = 0.8125 + |x| * 0.125 (|x| >>> 3)
    // Region 2: 0.5 <= |x| < 1.5   -> y_pos = 0.25   + |x| * 0.5   (|x| >>> 1)
    // Region 3: 0   <= |x| < 0.5   -> y_pos = |x|

    reg signed [DATA_WIDTH-1:0] y_pos;

    always @(*) begin
        if (abs_x >= Q_THREE) begin
            y_pos = Q_ONE;
        end else if (abs_x >= Q_1_5) begin
            y_pos = Q_0_8125 + (abs_x >>> 3);
        end else if (abs_x >= Q_HALF) begin
            y_pos = Q_QUARTER + (abs_x >>> 1);
        end else begin
            y_pos = abs_x;
        end
    end

    // Apply odd symmetry: f(-x) = -f(x)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= {DATA_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (valid_in) begin
            valid_out <= 1'b1;
            if (is_negative) begin
                data_out <= -y_pos;
            end else begin
                data_out <= y_pos;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
