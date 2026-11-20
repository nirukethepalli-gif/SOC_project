// ============================================================================
// Module Name: dma_transfer_engine
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Data Transfer Engine and Inter-Channel Routing for DMA.
//              Routes memory read data to Matrix Multiplier buffers (X, W, B)
//              and routes Activation Unit results into DMA write data path.
// ============================================================================

`timescale 1ns / 1ps

module dma_transfer_engine #(
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Configuration
    input  wire                   direction,     // 0: Mem->Acc, 1: Acc->Mem
    input  wire [1:0]             acc_target,    // 00: In, 01: Weight, 10: Bias, 11: Act_Out
    input  wire [31:0]            curr_dst_addr, // Byte address used to compute target offset
    input  wire [31:0]            curr_src_addr,

    // From DMA Read Controller
    input  wire [DATA_WIDTH-1:0]  mem_rd_data,
    input  wire                   mem_rd_valid,

    // To DMA Write Controller
    output reg  [DATA_WIDTH-1:0]  mem_wr_data,
    output reg                    mem_wr_valid,
    input  wire                   mem_wr_rd_en,

    // Direct interface to Matrix Multiplier Buffers
    output reg                    dma_in_wr_en,
    output reg  [7:0]             dma_in_wr_addr,
    output reg  [DATA_WIDTH-1:0]  dma_in_wr_data,

    output reg                    dma_w_wr_en,
    output reg  [9:0]             dma_w_wr_addr,
    output reg  [DATA_WIDTH-1:0]  dma_w_wr_data,

    output reg                    dma_bias_wr_en,
    output reg  [7:0]             dma_bias_wr_addr,
    output reg  [DATA_WIDTH-1:0]  dma_bias_wr_data,

    // Direct interface from Activation Unit Output Buffer
    output reg                    dma_act_rd_en,
    output reg  [7:0]             dma_act_rd_addr,
    input  wire [DATA_WIDTH-1:0]  dma_act_rd_data
);

    // Compute word indices from byte addresses (addr >> 2)
    wire [7:0] in_bias_idx  = curr_dst_addr[9:2];
    wire [9:0] weight_idx   = curr_dst_addr[11:2];
    wire [7:0] act_src_idx  = curr_src_addr[9:2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_in_wr_en     <= 1'b0;
            dma_in_wr_addr   <= 8'd0;
            dma_in_wr_data   <= {DATA_WIDTH{1'b0}};
            dma_w_wr_en      <= 1'b0;
            dma_w_wr_addr    <= 10'd0;
            dma_w_wr_data    <= {DATA_WIDTH{1'b0}};
            dma_bias_wr_en   <= 1'b0;
            dma_bias_wr_addr <= 8'd0;
            dma_bias_wr_data <= {DATA_WIDTH{1'b0}};
            dma_act_rd_en    <= 1'b0;
            dma_act_rd_addr  <= 8'd0;
            mem_wr_data      <= {DATA_WIDTH{1'b0}};
            mem_wr_valid     <= 1'b0;
        end else begin
            // Default single-cycle pulses
            dma_in_wr_en   <= 1'b0;
            dma_w_wr_en    <= 1'b0;
            dma_bias_wr_en <= 1'b0;

            if (direction == 1'b0) begin
                // Memory -> Accelerator transfer
                if (mem_rd_valid) begin
                    case (acc_target)
                        2'b00: begin // Input Buffer
                            dma_in_wr_en   <= 1'b1;
                            dma_in_wr_addr <= in_bias_idx;
                            dma_in_wr_data <= mem_rd_data;
                        end
                        2'b01: begin // Weight Buffer
                            dma_w_wr_en   <= 1'b1;
                            dma_w_wr_addr <= weight_idx;
                            dma_w_wr_data <= mem_rd_data;
                        end
                        2'b10: begin // Bias Buffer
                            dma_bias_wr_en   <= 1'b1;
                            dma_bias_wr_addr <= in_bias_idx;
                            dma_bias_wr_data <= mem_rd_data;
                        end
                        default: ;
                    endcase
                end
            end else begin
                // Accelerator -> Memory transfer
                dma_act_rd_en   <= 1'b1;
                dma_act_rd_addr <= act_src_idx;
                mem_wr_data     <= dma_act_rd_data;
                mem_wr_valid    <= 1'b1;
            end
        end
    end

endmodule
