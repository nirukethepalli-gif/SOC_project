// SPDX-License-Identifier: Apache-2.0
// Unit Testbench: tb_activation.sv
// Target Simulator: Synopsys VCS
// Verifies Custom IP 2: Activation Unit at base 0x8000_5000

`timescale 1ns/1ps

module tb_activation;

    localparam time CLK_PERIOD = 10ns;
    logic clk;
    logic rst_n;

    // AXI4-Lite Slave Ports
    logic [31:0] s_awaddr;
    logic [2:0]  s_awprot;
    logic        s_awvalid;
    logic        s_awready;
    logic [31:0] s_wdata;
    logic [3:0]  s_wstrb;
    logic        s_wvalid;
    logic        s_wready;
    logic [1:0]  s_bresp;
    logic        s_bvalid;
    logic        s_bready;
    logic [31:0] s_araddr;
    logic [2:0]  s_arprot;
    logic        s_arvalid;
    logic        s_arready;
    logic [31:0] s_rdata;
    logic [1:0]  s_rresp;
    logic        s_rvalid;
    logic        s_rready;

    // Streaming input
    logic [31:0] stream_in_data;
    logic        stream_in_valid;
    logic        stream_in_ready;

    // DMA readout
    logic        dma_out_rd_en;
    logic [7:0]  dma_out_rd_addr;
    logic [31:0] dma_out_rd_data;

    // Status
    logic        busy;
    logic        done;
    logic        irq;

    int error_count = 0;

    localparam signed [31:0] Q_ZERO = 32'h0000_0000;
    localparam signed [31:0] Q_HALF = 32'h0000_8000; // 0.5
    localparam signed [31:0] Q_ONE  = 32'h0001_0000; // 1.0
    localparam signed [31:0] Q_TWO  = 32'h0002_0000; // 2.0
    localparam signed [31:0] Q_NEG2 = -Q_TWO;        // -2.0

    activation_unit u_dut (
        .aclk            (clk),
        .aresetn         (rst_n),
        .s_awaddr        (s_awaddr),
        .s_awprot        (s_awprot),
        .s_awvalid       (s_awvalid),
        .s_awready       (s_awready),
        .s_wdata         (s_wdata),
        .s_wstrb         (s_wstrb),
        .s_wvalid        (s_wvalid),
        .s_wready        (s_wready),
        .s_bresp         (s_bresp),
        .s_bvalid        (s_bvalid),
        .s_bready        (s_bready),
        .s_araddr        (s_araddr),
        .s_arprot        (s_arprot),
        .s_arvalid       (s_arvalid),
        .s_arready       (s_arready),
        .s_rdata         (s_rdata),
        .s_rresp         (s_rresp),
        .s_rvalid        (s_rvalid),
        .s_rready        (s_rready),
        .stream_in_data  (stream_in_data),
        .stream_in_valid (stream_in_valid),
        .stream_in_ready (stream_in_ready),
        .dma_out_rd_en   (dma_out_rd_en),
        .dma_out_rd_addr (dma_out_rd_addr),
        .dma_out_rd_data (dma_out_rd_data),
        .busy            (busy),
        .done            (done),
        .irq             (irq)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        s_awaddr  <= addr;
        s_awprot  <= 3'b000;
        s_awvalid <= 1'b1;
        s_wdata   <= data;
        s_wstrb   <= 4'hF;
        s_wvalid  <= 1'b1;
        s_bready  <= 1'b1;
        @(posedge clk);
        while (!(s_awready && s_wready)) @(posedge clk);
        s_awvalid <= 1'b0;
        s_wvalid  <= 1'b0;
        while (!s_bvalid) @(posedge clk);
        @(posedge clk);
        s_bready  <= 1'b0;
    endtask

    task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        s_araddr  <= addr;
        s_arprot  <= 3'b000;
        s_arvalid <= 1'b1;
        s_rready  <= 1'b1;
        @(posedge clk);
        while (!s_arready) @(posedge clk);
        s_arvalid <= 1'b0;
        while (!s_rvalid) @(posedge clk);
        data = s_rdata;
        @(posedge clk);
        s_rready  <= 1'b0;
    endtask

    logic [31:0] rdata;
    logic signed [31:0] res0, res1, res2;

    initial begin
        $display("==========================================================");
        $display(" [RUN] tb_activation (VCS Synopsys Target)");
        $display("==========================================================");

        clk   = 0;
        rst_n = 0;
        s_awaddr = '0; s_awprot = '0; s_awvalid = 0;
        s_wdata = '0; s_wstrb = '0; s_wvalid = 0; s_bready = 0;
        s_araddr = '0; s_arprot = '0; s_arvalid = 0; s_rready = 0;
        stream_in_data = '0; stream_in_valid = 0;
        dma_out_rd_en = 0; dma_out_rd_addr = 0;

        #(CLK_PERIOD * 4);
        rst_n = 1;
        #(CLK_PERIOD * 4);

        // 1. Test ReLU (func_sel = 00)
        axi_write(32'h8000_5008, 32'd3); // vec_len = 3
        axi_write(32'h8000_5000, 32'h0000_0001); // start

        @(posedge clk);
        stream_in_data  <= Q_TWO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_data  <= Q_NEG2;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_data  <= Q_ZERO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_valid <= 1'b0;

        rdata = '0;
        while ((rdata & 32'h1) == 0) begin
            axi_read(32'h8000_5004, rdata);
            #(CLK_PERIOD);
        end

        axi_write(32'h8000_5014, 32'd0); axi_read(32'h8000_5024, res0);
        axi_write(32'h8000_5014, 32'd1); axi_read(32'h8000_5024, res1);
        axi_write(32'h8000_5014, 32'd2); axi_read(32'h8000_5024, res2);

        $display(" ReLU(+2.0) = 0x%08X (Expected: 0x%08X)", res0, Q_TWO);
        $display(" ReLU(-2.0) = 0x%08X (Expected: 0x00000000)", res1);
        $display(" ReLU( 0.0) = 0x%08X (Expected: 0x00000000)", res2);

        if (res0 !== Q_TWO || res1 !== Q_ZERO || res2 !== Q_ZERO) error_count++;

        // 2. Test Sigmoid (func_sel = 01 -> CTRL = 0x05)
        axi_write(32'h8000_5008, 32'd1);
        axi_write(32'h8000_5000, 32'h0000_0005);
        @(posedge clk);
        stream_in_data  <= Q_ZERO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_valid <= 1'b0;

        rdata = '0;
        while ((rdata & 32'h1) == 0) begin
            axi_read(32'h8000_5004, rdata);
            #(CLK_PERIOD);
        end

        axi_write(32'h8000_5014, 32'd0); axi_read(32'h8000_5024, res0);
        $display(" Sigmoid(0.0) = 0x%08X (Expected: 0x00008000, 0.5)", res0);
        if (res0 !== Q_HALF) error_count++;

        // 3. Test Tanh (func_sel = 10 -> CTRL = 0x09)
        axi_write(32'h8000_5008, 32'd1);
        axi_write(32'h8000_5000, 32'h0000_0009);
        @(posedge clk);
        stream_in_data  <= Q_ZERO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_valid <= 1'b0;

        rdata = '0;
        while ((rdata & 32'h1) == 0) begin
            axi_read(32'h8000_5004, rdata);
            #(CLK_PERIOD);
        end

        axi_write(32'h8000_5014, 32'd0); axi_read(32'h8000_5024, res0);
        $display(" Tanh(0.0) = 0x%08X (Expected: 0x00000000, 0.0)", res0);
        if (res0 !== Q_ZERO) error_count++;

        if (error_count == 0) begin
            $display("=== [TEST] tb_activation: PASS ===");
        end else begin
            $display("=== [TEST] tb_activation: FAIL (%0d errors) ===", error_count);
        end

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
