// SPDX-License-Identifier: Apache-2.0
// UVM Top Testbench for Custom IP 2: Activation Unit
// Target Simulator: Synopsys VCS (-full64 -sverilog -ntb_opts uvm)

`timescale 1ns/1ps

`include "uvm_macros.svh"

module tb_uvm_activation;
    import uvm_pkg::*;
    import axilite_pkg::*;
    import activation_env_pkg::*;
    import activation_test_pkg::*;

    logic clk;
    logic rst_n;

    initial clk = 1'b0;
    always #5ns clk = ~clk;

    initial begin
        rst_n = 1'b0;
        #25ns;
        rst_n = 1'b1;
    end

    axilite_if axil_if (.clk(clk), .rst_n(rst_n));

    wire [31:0] stream_in_data  = '0;
    wire        stream_in_valid = 1'b0;
    wire        stream_in_ready;
    wire        dma_act_rd_en   = 1'b0;
    wire [7:0]  dma_act_rd_addr = '0;
    wire [31:0] dma_act_rd_data;
    wire        busy, done, irq;

    // Instantiate Activation Unit DUT
    activation_unit dut (
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
        .stream_in_data   (stream_in_data),
        .stream_in_valid  (stream_in_valid),
        .stream_in_ready  (stream_in_ready),
        .dma_act_rd_en    (dma_act_rd_en),
        .dma_act_rd_addr  (dma_act_rd_addr),
        .dma_act_rd_data  (dma_act_rd_data),
        .busy             (busy),
        .done             (done),
        .irq              (irq)
    );

    initial begin
        uvm_config_db#(virtual axilite_if)::set(null, "*.axil_agent*", "vif", axil_if);
        run_test("activation_all_func_test");
    end

endmodule : tb_uvm_activation
