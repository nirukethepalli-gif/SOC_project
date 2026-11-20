// SPDX-License-Identifier: Apache-2.0
// UVM Top Testbench for Custom IP 3: DMA Controller
// Target Simulator: Synopsys VCS (-full64 -sverilog -ntb_opts uvm)

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_uvm_dma;
    import uvm_pkg::*;
    import axilite_pkg::*;
    import axi_mem_slave_pkg::*;
    import dma_env_pkg::*;
    import dma_test_pkg::*;

    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #5ns clk = ~clk;

    initial begin
        rst_n = 1'b0;
        #25ns;
        rst_n = 1'b1;
    end

    axilite_if       axil_if (.clk(clk), .rst_n(rst_n));
    axi_mem_slave_if mem_if  (.clk(clk), .rst_n(rst_n));

    // Fast accelerator buffer ports
    wire        dma_in_wr_en;
    wire [7:0]  dma_in_wr_addr;
    wire [31:0] dma_in_wr_data;
    wire        dma_w_wr_en;
    wire [9:0]  dma_w_wr_addr;
    wire [31:0] dma_w_wr_data;
    wire        dma_bias_wr_en;
    wire [7:0]  dma_bias_wr_addr;
    wire [31:0] dma_bias_wr_data;
    wire        dma_act_rd_en;
    wire [7:0]  dma_act_rd_addr;
    wire [31:0] dma_act_rd_data = 32'hBEEF_0000 + dma_act_rd_addr;

    wire busy, done, error, irq;

    // Instantiate DMA Controller DUT
    dma_controller dut (
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
        .m_axi_araddr     (mem_if.araddr),
        .m_axi_arlen      (mem_if.arlen),
        .m_axi_arsize     (mem_if.arsize),
        .m_axi_arburst    (mem_if.arburst),
        .m_axi_arvalid    (mem_if.arvalid),
        .m_axi_arready    (mem_if.arready),
        .m_axi_rdata      (mem_if.rdata),
        .m_axi_rresp      (mem_if.rresp),
        .m_axi_rlast      (mem_if.rlast),
        .m_axi_rvalid     (mem_if.rvalid),
        .m_axi_rready     (mem_if.rready),
        .m_axi_awaddr     (mem_if.awaddr),
        .m_axi_awlen      (mem_if.awlen),
        .m_axi_awsize     (mem_if.awsize),
        .m_axi_awburst    (mem_if.awburst),
        .m_axi_awvalid    (mem_if.awvalid),
        .m_axi_awready    (mem_if.awready),
        .m_axi_wdata      (mem_if.wdata),
        .m_axi_wstrb      (mem_if.wstrb),
        .m_axi_wlast      (mem_if.wlast),
        .m_axi_wvalid     (mem_if.wvalid),
        .m_axi_wready     (mem_if.wready),
        .m_axi_bresp      (mem_if.bresp),
        .m_axi_bvalid     (mem_if.bvalid),
        .m_axi_bready     (mem_if.bready),
        .dma_in_wr_en     (dma_in_wr_en),
        .dma_in_wr_addr   (dma_in_wr_addr),
        .dma_in_wr_data   (dma_in_wr_data),
        .dma_w_wr_en      (dma_w_wr_en),
        .dma_w_wr_addr    (dma_w_wr_addr),
        .dma_w_wr_data    (dma_w_wr_data),
        .dma_bias_wr_en   (dma_bias_wr_en),
        .dma_bias_wr_addr (dma_bias_wr_addr),
        .dma_bias_wr_data (dma_bias_wr_data),
        .dma_act_rd_en    (dma_act_rd_en),
        .dma_act_rd_addr  (dma_act_rd_addr),
        .dma_act_rd_data  (dma_act_rd_data),
        .busy             (busy),
        .done             (done),
        .error            (error),
        .irq              (irq)
    );

    initial begin
        uvm_config_db#(virtual axilite_if)::set(null, "*.axil_agent*", "vif", axil_if);
        uvm_config_db#(virtual axi_mem_slave_if)::set(null, "*.mem_agent*", "vif", mem_if);
        run_test("dma_transfer_test");
    end

endmodule : tb_uvm_dma
