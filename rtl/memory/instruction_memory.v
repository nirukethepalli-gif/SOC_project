// ============================================================================
// Module Name: instruction_memory
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: 64 KB Instruction Memory (0x0000_0000 - 0x0000_FFFF).
//              Provides single-cycle instruction fetch interface for the
//              RISC-V processor core, with optional initial firmware loading.
// ============================================================================

`timescale 1ns / 1ps

module instruction_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,  // 64 KB = 16384 words (14-bit word address)
    parameter DEPTH      = 16384
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Instruction Fetch Port (from RISC-V Core)
    input  wire [ADDR_WIDTH-1:0]  imem_addr,
    output reg  [DATA_WIDTH-1:0]  imem_data
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    wire [13:0] word_addr = imem_addr[15:2];

    always @(posedge clk) begin
        imem_data <= mem[word_addr];
    end

    // Default initialization (can be loaded with $readmemh in simulation)
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 32'h0000_0013; // NOP (addi x0, x0, 0)
        end
    end

endmodule
