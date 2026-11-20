// ============================================================================
// Module Name: relu
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Rectified Linear Unit (ReLU) Activation: f(x) = max(0, x).
//              Signed Q16.16 fixed-point format.
// ============================================================================

`timescale 1ns / 1ps

module relu #(
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire signed [DATA_WIDTH-1:0] data_in,
    output reg  signed [DATA_WIDTH-1:0] data_out,
    output reg                    valid_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= {DATA_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else if (valid_in) begin
            valid_out <= 1'b1;
            if (data_in[DATA_WIDTH-1] == 1'b1) begin
                // Negative value -> clip to zero
                data_out <= {DATA_WIDTH{1'b0}};
            end else begin
                // Non-negative value -> pass through
                data_out <= data_in;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
