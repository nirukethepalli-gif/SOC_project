// SPDX-License-Identifier: Apache-2.0
// Unit Testbench for Timer per Section 14.1 of SoC Specification v2.0

`timescale 1ns/1ps

module tb_timer;

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

    logic timer_int;
    logic irq;

    // DUT
    timer dut (
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
        .timer_int(timer_int),
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
        logic [31:0] rdata, hi1, lo, hi2;
        logic [1:0]  resp;

        aresetn = 1'b0;
        bfm.reset_master();
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        repeat (5) @(posedge aclk);

        $display("=== [TEST] tb_timer START ===");

        // Configure PRESCALE = 1 (increment every 2 clock cycles)
        bfm.write(32'h8000_1014, 32'd1, 4'hF, resp, 0, 0);

        // Check increment
        repeat (20) @(posedge aclk);
        bfm.read(32'h8000_1000, rdata, resp, 0);
        $display("mtime_lo after 20 clocks: %d", rdata);
        if (rdata == 0) begin
            $display("FAILED: mtime failed to increment");
            test_errors++;
        end

        // Test timer_int assert
        $display("[Test 1] Setting compare register to trigger timer_int");
        // Safe 64-bit write sequence per Section 8.5
        bfm.write(32'h8000_1008, 32'hFFFF_FFFF, 4'hF, resp, 0, 0); // MTIMECMP_LO = 0xFFFFFFFF
        bfm.write(32'h8000_100C, 32'h0000_0000, 4'hF, resp, 0, 0); // MTIMECMP_HI = 0
        bfm.write(32'h8000_1008, 32'd25, 4'hF, resp, 0, 0);        // MTIMECMP_LO = 25

        // Wait until mtime >= 25
        repeat (40) @(posedge aclk);
        if (timer_int !== 1'b1) begin
            $display("FAILED: Expected timer_int asserted when mtime >= mtimecmp");
            test_errors++;
        end

        // Test timer_int deassert on write of new mtimecmp
        $display("[Test 2] Deassert timer_int by updating mtimecmp");
        bfm.write(32'h8000_1008, 32'hFFFF_FFFF, 4'hF, resp, 0, 0);
        bfm.write(32'h8000_100C, 32'h0000_0001, 4'hF, resp, 0, 0);
        @(posedge aclk);
        if (timer_int !== 1'b0) begin
            $display("FAILED: timer_int should deassert after mtimecmp increased");
            test_errors++;
        end

        // Test 3: Safe 64-bit atomic read retry loop
        $display("[Test 3] Test 64-bit atomic read retry convergence");
        do begin
            bfm.read(32'h8000_1004, hi1, resp, 0);
            bfm.read(32'h8000_1000, lo,  resp, 0);
            bfm.read(32'h8000_1004, hi2, resp, 0);
        end while (hi1 !== hi2);
        $display("Safely read 64-bit mtime: 0x%08X_%08X", hi1, lo);

        repeat (5) @(posedge aclk);
        if (test_errors == 0) begin
            $display("=== [TEST] tb_timer: PASS ===");
        end else begin
            $display("=== [TEST] tb_timer: FAIL with %0d errors ===", test_errors);
        end

        $finish;
    end

endmodule

