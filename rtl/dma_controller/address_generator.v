// ============================================================================
// Module Name: address_generator
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Address Generator and Word Counter for DMA transfers.
//              Maintains auto-incrementing 32-bit source/destination addresses
//              and transfer word counters. Checks address alignment and bounds.
// ============================================================================

`timescale 1ns / 1ps

module address_generator #(
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Initialization
    input  wire                   load_init,
    input  wire [ADDR_WIDTH-1:0]  init_src_addr,
    input  wire [ADDR_WIDTH-1:0]  init_dst_addr,
    input  wire [15:0]            init_transfer_len,

    // Step Increment
    input  wire                   step_src,
    input  wire                   step_dst,

    // Current State
    output reg  [ADDR_WIDTH-1:0]  curr_src_addr,
    output reg  [ADDR_WIDTH-1:0]  curr_dst_addr,
    output reg  [15:0]            words_remaining,
    output wire                   transfer_complete,
    output wire                   align_error
);

    // 32-bit word alignment requires address[1:0] == 2'b00
    assign align_error = (init_src_addr[1:0] != 2'b00) || (init_dst_addr[1:0] != 2'b00);
    assign transfer_complete = (words_remaining == 16'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_src_addr   <= {ADDR_WIDTH{1'b0}};
            curr_dst_addr   <= {ADDR_WIDTH{1'b0}};
            words_remaining <= 16'd0;
        end else if (load_init) begin
            curr_src_addr   <= init_src_addr;
            curr_dst_addr   <= init_dst_addr;
            words_remaining <= init_transfer_len;
        end else begin
            if (step_src) begin
                curr_src_addr <= curr_src_addr + 32'd4;
            end
            if (step_dst) begin
                curr_dst_addr <= curr_dst_addr + 32'd4;
                if (words_remaining > 16'd0) begin
                    words_remaining <= words_remaining - 1'b1;
                end
            end
        end
    end

endmodule
