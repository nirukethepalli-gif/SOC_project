// SPDX-License-Identifier: Apache-2.0
// Unit Testbench for UART per Section 14.1 of SoC Specification v2.0

`timescale 1ns/1ps

module tb_uart;

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

    logic uart_tx;
    logic uart_rx;
    logic irq;

    // DUT
    uart #(.FIFO_DEPTH(16)) dut (
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
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .irq      (irq)
    );

    // Loopback TX directly to RX
    assign uart_rx = uart_tx;

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

        aresetn = 1'b0;
        bfm.reset_master();
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        repeat (5) @(posedge aclk);

        $display("=== [TEST] tb_uart START ===");

        // Set fast baud divisor for fast simulation (BAUDDIV = 16 clocks per bit)
        bfm.write(32'h8000_0008, 32'd16, 4'hF, resp, 0, 0);

        // Check reset STATUS: TX_EMPTY (bit 1) and RX_EMPTY (bit 2) should be 1 -> 0x6
        bfm.read(32'h8000_0004, rdata, resp, 0);
        if (rdata[2:0] !== 3'b110) begin
            $display("FAILED: Expected STATUS=0x6, got %h", rdata);
            test_errors++;
        end

        // Transmit character 'A' (0x41)
        $display("[Test 1] Send byte 0x41 through loopback");
        bfm.write(32'h8000_0000, 32'h41, 4'hF, resp, 0, 0);

        // Wait for loopback reception (RX_EMPTY goes low)
        do begin
            repeat (10) @(posedge aclk);
            bfm.read(32'h8000_0004, rdata, resp, 0);
        end while ((rdata & 32'h4) != 0); // While RX_EMPTY is 1

        // Read received byte
        bfm.read(32'h8000_0000, rdata, resp, 0);
        if (rdata[7:0] !== 8'h41) begin
            $display("FAILED: Expected received 0x41, got %h", rdata[7:0]);
            test_errors++;
        end

        // Check backpressured read does not double pop
        $display("[Test 2] Send 0x42 and verify single pop under backpressure");
        bfm.write(32'h8000_0000, 32'h42, 4'hF, resp, 0, 0);
        do begin
            repeat (10) @(posedge aclk);
            bfm.read(32'h8000_0004, rdata, resp, 0);
        end while ((rdata & 32'h4) != 0);

        // Read with 5 cycle delay on RREADY
        bfm.read(32'h8000_0000, rdata, resp, 5);
        if (rdata[7:0] !== 8'h42) begin
            $display("FAILED: Expected 0x42, got %h", rdata[7:0]);
            test_errors++;
        end

        // RX FIFO must now be empty
        bfm.read(32'h8000_0004, rdata, resp, 0);
        if ((rdata & 32'h4) == 0) begin
            $display("FAILED: RX FIFO should be empty after pop");
            test_errors++;
        end

        repeat (5) @(posedge aclk);
        if (test_errors == 0) begin
            $display("=== [TEST] tb_uart: PASS ===");
        end else begin
            $display("=== [TEST] tb_uart: FAIL with %0d errors ===", test_errors);
        end

        $finish;
    end

endmodule

