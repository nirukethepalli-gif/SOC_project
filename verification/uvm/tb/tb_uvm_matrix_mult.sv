// SPDX-License-Identifier: Apache-2.0
// UVM Top Testbench for Custom IP 1: Matrix Multiplier
// Target Simulator: Synopsys VCS (-full64 -sverilog -ntb_opts uvm)

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_uvm_matrix_mult;
    import uvm_pkg::*;
    import axilite_pkg::*;
    import stream_pkg::*;
    import matrix_mult_env_pkg::*;
    import matrix_mult_test_pkg::*;

    logic clk;
    logic rst_n;

    // Clock generator (100 MHz)
    initial clk = 1'b0;
    always #5ns clk = ~clk;

    // Reset generator
    initial begin
        rst_n = 1'b0;
        #25ns;
        rst_n = 1'b1;
    end

    // Interfaces
    axilite_if axil_if (.clk(clk), .rst_n(rst_n));
    stream_if  stream_if (.clk(clk), .rst_n(rst_n));

    // Tie-offs for unused DMA loading ports
    wire        dma_in_wr_en   = 1'b0;
    wire [7:0]  dma_in_wr_addr = '0;
    wire [31:0] dma_in_wr_data = '0;
    wire        dma_w_wr_en    = 1'b0;
    wire [9:0]  dma_w_wr_addr  = '0;
    wire [31:0] dma_w_wr_data  = '0;
    wire        dma_bias_wr_en = 1'b0;
    wire [7:0]  dma_bias_wr_addr = '0;
    wire [31:0] dma_bias_wr_data = '0;
    wire        dma_out_rd_en  = 1'b0;
    wire [7:0]  dma_out_rd_addr = '0;
    wire [31:0] dma_out_rd_data;
    wire        busy, done, irq;

    // Instantiate Matrix Multiplier DUT
    matrix_multiplier dut (
        .aclk             (clk),
        .aresetn          (rst_n),
        .s_awaddr         (axil_if.awaddr),
        .s_awprot         (axil_if.awprot),
        .s_awvalid        (axil_if.awvalid),
        .s_awready        (axil_if.awready),
        .s_wdata          (axil_if.wdata),
        .s_wstrb          (axil_if.wstrb),
        .s_wvalid         (axil_if.wvalid),
        .s_wready         (axil_if.wready),
        .s_bresp          (axil_if.bresp),
        .s_bvalid         (axil_if.bvalid),
        .s_bready         (axil_if.bready),
        .s_araddr         (axil_if.araddr),
        .s_arprot         (axil_if.arprot),
        .s_arvalid        (axil_if.arvalid),
        .s_arready        (axil_if.arready),
        .s_rdata          (axil_if.rdata),
        .s_rresp          (axil_if.rresp),
        .s_rvalid         (axil_if.rvalid),
        .s_rready         (axil_if.rready),
        .dma_in_wr_en     (dma_in_wr_en),
        .dma_in_wr_addr   (dma_in_wr_addr),
        .dma_in_wr_data   (dma_in_wr_data),
        .dma_w_wr_en      (dma_w_wr_en),
        .dma_w_wr_addr    (dma_w_wr_addr),
        .dma_w_wr_data    (dma_w_wr_data),
        .dma_bias_wr_en   (dma_bias_wr_en),
        .dma_bias_wr_addr (dma_bias_wr_addr),
        .dma_bias_wr_data (dma_bias_wr_data),
        .dma_out_rd_en    (dma_out_rd_en),
        .dma_out_rd_addr  (dma_out_rd_addr),
        .dma_out_rd_data  (dma_out_rd_data),
        .stream_act_data  (stream_if.data),
        .stream_act_valid (stream_if.valid),
        .stream_act_ready (stream_if.ready),
        .busy             (busy),
        .done             (done),
        .irq              (irq)
    );

    // Initial block to set config_db and run test
    initial begin
        uvm_config_db#(virtual axilite_if)::set(null, "*.axil_agent*", "vif", axil_if);
        uvm_config_db#(virtual stream_if)::set(null, "*.stream_snk_agent*", "vif", stream_if);

        // Run default test if not provided via +UVM_TESTNAME
        run_test("matrix_mult_2x2_test");
    end

endmodule : tb_uvm_matrix_mult
