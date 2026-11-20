// ============================================================================
// Module Name: bias_adder
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Adds signed Q16.16 bias B[m] to accumulated dot-product Y_raw[m].
//              Includes an internal bias storage RAM and signed saturation logic.
// ============================================================================

`timescale 1ns / 1ps

module bias_adder #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter DEPTH      = 256
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // Bias memory write port (DMA / register write)
    input  wire                          bias_wr_en,
    input  wire [ADDR_WIDTH-1:0]         bias_wr_addr,
    input  wire [DATA_WIDTH-1:0]         bias_wr_data,

    // Datapath operation interface
    input  wire                          add_en,        // Trigger addition
    input  wire [ADDR_WIDTH-1:0]         bias_rd_addr,   // Bias row index m
    input  wire signed [DATA_WIDTH-1:0]  dot_prod_in,    // Accumulated dot-product from MAC
    output reg  signed [DATA_WIDTH-1:0]  y_out,          // Y = dot_prod + bias (Q16.16)
    output reg                           y_valid,        // Valid output flag
    output reg                           overflow        // Saturation/overflow flag
);

    // Bias RAM
    reg [DATA_WIDTH-1:0] bias_mem [0:DEPTH-1];
    reg signed [DATA_WIDTH-1:0] bias_val;

    always @(posedge clk) begin
        if (bias_wr_en) begin
            bias_mem[bias_wr_addr] <= bias_wr_data;
        end
        bias_val <= $signed(bias_mem[bias_rd_addr]);
    end

    // Signed addition with 33-bit extension to check overflow
    wire signed [DATA_WIDTH:0] sum_extended;
    assign sum_extended = {dot_prod_in[DATA_WIDTH-1], dot_prod_in} + {bias_val[DATA_WIDTH-1], bias_val};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_out    <= {DATA_WIDTH{1'b0}};
            y_valid  <= 1'b0;
            overflow <= 1'b0;
        end else if (add_en) begin
            y_valid <= 1'b1;

            // Overflow checks for 32-bit signed addition:
            // Pos + Pos = Neg -> overflow to MAX_POS
            // Neg + Neg = Pos -> overflow to MIN_NEG
            if ((dot_prod_in[DATA_WIDTH-1] == 1'b0) && (bias_val[DATA_WIDTH-1] == 1'b0) && (sum_extended[DATA_WIDTH-1] == 1'b1)) begin
                y_out    <= 32'h7FFF_FFFF; // Saturated positive
                overflow <= 1'b1;
            end else if ((dot_prod_in[DATA_WIDTH-1] == 1'b1) && (bias_val[DATA_WIDTH-1] == 1'b1) && (sum_extended[DATA_WIDTH-1] == 1'b0)) begin
                y_out    <= 32'h8000_0000; // Saturated negative
                overflow <= 1'b1;
            end else begin
                y_out    <= sum_extended[DATA_WIDTH-1:0];
                overflow <= 1'b0;
            end
        end else begin
            y_valid <= 1'b0;
        end
    end

endmodule
