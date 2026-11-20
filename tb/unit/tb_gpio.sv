// SPDX-License-Identifier: Apache-2.0
// Unit Testbench for GPIO per Section 14.1 of SoC Specification v2.0

`timescale 1ns/1ps

module tb_gpio;

    logic aclk;
    logic aresetn;

    initial aclk = 0;
    always #10 aclk = ~aclk;

    // AXI4-Lite signals
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

    logic [15:0] gpio_in;
    logic [15:0] gpio_out;
    logic [15:0] gpio_oe;
    logic        irq;

    // DUT
    gpio #(.NGPIO(16)) dut (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_awaddr (s_awaddr),
        .s_awprot (s_awprot),
        .s_awvalid(s_awvalid),
        .s_awready(s_awready),
        .s_wdata  (s_wdata),
        .s_wstrb  (s_wstrb),
        .s_wvalid (s_wvalid),
        .s_wready (s_wready),
        .s_bresp  (s_bresp),
        .s_bvalid (s_bvalid),
        .s_bready (s_bready),
        .s_araddr (s_araddr),
        .s_arprot (s_arprot),
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_rdata  (s_rdata),
        .s_rresp  (s_rresp),
        .s_rvalid (s_rvalid),
        .s_rready (s_rready),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_oe  (gpio_oe),
        .irq      (irq)
    );

    // BFM
    axi4lite_master_bfm bfm (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .m_awaddr (s_awaddr),
        .m_awprot (s_awprot),
        .m_awvalid(s_awvalid),
        .m_awready(s_awready),
        .m_wdata  (s_wdata),
        .m_wstrb  (s_wstrb),
        .m_wvalid (s_wvalid),
        .m_wready (s_wready),
        .m_bresp  (s_bresp),
        .m_bvalid (s_bvalid),
        .m_bready (s_bready),
        .m_araddr (s_araddr),
        .m_arprot (s_arprot),
        .m_arvalid(s_arvalid),
        .m_arready(s_arready),
        .m_rdata  (s_rdata),
        .m_rresp  (s_rresp),
        .m_rvalid (s_rvalid),
        .m_rready (s_rready)
    );

    int test_errors = 0;

    initial begin
        logic [31:0] rdata;
        logic [1:0]  resp;

        gpio_in = '0;
        aresetn = 1'b0;
        bfm.reset_master();
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        repeat (5) @(posedge aclk);

        $display("=== [TEST] tb_gpio START ===");

        // Test 1: Direction and output driving
        $display("[Test 1] Set DIR to output and drive pins");
        bfm.write(32'h8000_2008, 32'h00FF, 4'hF, resp, 0, 0); // DIR: lower 8 output
        bfm.write(32'h8000_2000, 32'h00A5, 4'hF, resp, 0, 0); // DATA_OUT: 0xA5
        repeat (2) @(posedge aclk);
        if (gpio_oe !== 16'h00FF || gpio_out !== 16'h00A5) begin
            $display("FAILED: Expected gpio_oe=0x00FF, gpio_out=0x00A5, got oe=%h out=%h", gpio_oe, gpio_out);
            test_errors++;
        end

        // Test 2: Input synchronization
        $display("[Test 2] Synchronize input pins");
        gpio_in = 16'hF000;
        repeat (4) @(posedge aclk);
        bfm.read(32'h8000_2004, rdata, resp, 0); // DATA_IN
        if (rdata[15:0] !== 16'hF000) begin
            $display("FAILED: Expected DATA_IN=0xF000, got %h", rdata[15:0]);
            test_errors++;
        end

        // Test 3: Edge-triggered interrupt
        $display("[Test 3] Rising edge interrupt on pin 8");
        bfm.write(32'h8000_200C, 32'h0100, 4'hF, resp, 0, 0); // IRQ_MASK: bit 8
        bfm.write(32'h8000_2010, 32'h0100, 4'hF, resp, 0, 0); // IRQ_EDGE: bit 8 is edge
        repeat (2) @(posedge aclk);
        gpio_in[8] = 1'b1; // Rising edge
        repeat (4) @(posedge aclk);
        if (irq !== 1'b1) begin
            $display("FAILED: Expected IRQ asserted on rising edge");
            test_errors++;
        end

        // Clear interrupt (W1C)
        bfm.write(32'h8000_2014, 32'h0100, 4'hF, resp, 0, 0);
        repeat (2) @(posedge aclk);
        if (irq !== 1'b0) begin
            $display("FAILED: Expected IRQ deasserted after W1C clear");
            test_errors++;
        end

        repeat (5) @(posedge aclk);
        if (test_errors == 0) begin
            $display("=== [TEST] tb_gpio: PASS ===");
        end else begin
            $display("=== [TEST] tb_gpio: FAIL with %0d errors ===", test_errors);
        end

        $finish;
    end

endmodule

