// ============================================================================
// Module Name: mac_unit
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Multiply-Accumulate (MAC) Unit using signed Q16.16 fixed-point
//              arithmetic. Supports synchronous clear, product scaling,
//              rounding, and saturation.
// ============================================================================

`timescale 1ns / 1ps

module mac_unit #(
    parameter DATA_WIDTH = 32,
    parameter FRAC_BITS  = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   clr_acc,     // Clears accumulator for new row/dot-product
    input  wire                   en,          // Clock enable for MAC step
    input  wire signed [DATA_WIDTH-1:0] a_in,  // Input operand (e.g., input feature X)
    input  wire signed [DATA_WIDTH-1:0] b_in,  // Input operand (e.g., weight W)
    output reg  signed [DATA_WIDTH-1:0] acc_out, // Current accumulated result (Q16.16)
    output reg                    valid_out,   // Valid indicator
    output reg                    overflow     // Overflow flag
);

    // Full precision 64-bit signed product (Q32.32)
    wire signed [63:0] product_raw;
    assign product_raw = a_in * b_in;

    // Rounded product shifted back to Q16.16 format
    // Add rounding bit at (FRAC_BITS - 1) before shifting
    wire signed [63:0] product_rounded;
    assign product_rounded = product_raw + (64'sh1 <<< (FRAC_BITS - 1));

    // Extracted scaled product
    wire signed [DATA_WIDTH-1:0] product_scaled;
    assign product_scaled = product_rounded[FRAC_BITS + DATA_WIDTH - 1 : FRAC_BITS];

    // Check for multiplication overflow outside signed 32-bit representable range
    wire mult_overflow;
    assign mult_overflow = (product_rounded[63:FRAC_BITS + DATA_WIDTH - 1] != { (64-(FRAC_BITS+DATA_WIDTH-1)){product_rounded[63]} });

    // Internal 48-bit accumulator to prevent intermediate overflow during accumulation
    reg signed [47:0] acc_reg;
    wire signed [47:0] next_acc;
    wire signed [47:0] operand_to_add;

    assign operand_to_add = {{16{product_scaled[DATA_WIDTH-1]}}, product_scaled};
    assign next_acc = (clr_acc) ? operand_to_add : (acc_reg + operand_to_add);

    // Saturation logic for final 32-bit Q16.16 output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg   <= 48'sd0;
            acc_out   <= {DATA_WIDTH{1'b0}};
            valid_out <= 1'b0;
            overflow  <= 1'b0;
        end else if (en) begin
            acc_reg   <= next_acc;
            valid_out <= 1'b1;

            // Saturated output detection
            if (next_acc > 48'sh0000_7FFF_FFFF) begin
                acc_out  <= 32'h7FFF_FFFF; // Maximum positive Q16.16 (+32767.9999)
                overflow <= 1'b1;
            end else if (next_acc < -48'sh0000_8000_0000) begin
                acc_out  <= 32'h8000_0000; // Minimum negative Q16.16 (-32768.0000)
                overflow <= 1'b1;
            end else begin
                acc_out  <= next_acc[DATA_WIDTH-1:0];
                overflow <= mult_overflow;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
