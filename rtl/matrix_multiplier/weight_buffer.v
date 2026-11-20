// ============================================================================
// Module Name: weight_buffer
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Dual-port synchronous RAM buffer for holding weight matrix W.
//              Port A is used for loading weights (from DMA or AXI slave).
//              Port B is read sequentially by the Matrix Controller for MAC steps.
// ============================================================================

`timescale 1ns / 1ps

module weight_buffer #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,  // 2^10 = 1024 words capacity
    parameter DEPTH      = 1024
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Port A: Write interface (DMA / Bus write)
    input  wire                   wr_en_a,
    input  wire [ADDR_WIDTH-1:0]  addr_a,
    input  wire [DATA_WIDTH-1:0]  wr_data_a,
    output reg  [DATA_WIDTH-1:0]  rd_data_a,

    // Port B: Read interface (Matrix Multiplier Datapath)
    input  wire                   rd_en_b,
    input  wire [ADDR_WIDTH-1:0]  addr_b,
    output reg  [DATA_WIDTH-1:0]  rd_data_b
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Port A: Read/Write
    always @(posedge clk) begin
        if (wr_en_a) begin
            mem[addr_a] <= wr_data_a;
        end
        rd_data_a <= mem[addr_a];
    end

    // Port B: Read
    always @(posedge clk) begin
        if (rd_en_b) begin
            rd_data_b <= mem[addr_b];
        end
    end

endmodule
