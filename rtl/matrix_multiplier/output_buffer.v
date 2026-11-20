// ============================================================================
// Module Name: output_buffer
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Dual-port buffer storing computed output vector Y.
//              Written by the bias adder upon row completion.
//              Read by Activation Unit or DMA / CPU reading results.
// ============================================================================

`timescale 1ns / 1ps

module output_buffer #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter DEPTH      = 256
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Port A: Internal datapath write
    input  wire                   wr_en,
    input  wire [ADDR_WIDTH-1:0]  wr_addr,
    input  wire [DATA_WIDTH-1:0]  wr_data,

    // Port B: Readout interface (to Activation Unit / Bus read)
    input  wire                   rd_en,
    input  wire [ADDR_WIDTH-1:0]  rd_addr,
    output reg  [DATA_WIDTH-1:0]  rd_data
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    always @(posedge clk) begin
        if (rd_en) begin
            rd_data <= mem[rd_addr];
        end
    end

endmodule
