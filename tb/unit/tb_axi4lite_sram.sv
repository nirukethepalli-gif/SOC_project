// SPDX-License-Identifier: Apache-2.0
// Unit Testbench for axi4lite_sram per Section 14.1 of SoC Specification v2.0

`timescale 1ns/1ps

module tb_axi4lite_sram;

    logic aclk;
    logic aresetn;

    initial aclk = 0;
    always #10 aclk = ~aclk;

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

    // DUT
    axi4lite_sram #(.DEPTH_WORDS(1024)) dut (
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
        .s_rready (s_rready)
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

        aresetn = 1'b0;
        bfm.reset_master();
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        repeat (5) @(posedge aclk);

        $display("=== [TEST] tb_axi4lite_sram START ===");

        // Test 1: Full word write and readback
        $display("[Test 1] Word write and readback");
        bfm.write(32'h0000_0000, 32'h1234_5678, 4'hF, resp, 0, 0);
        bfm.read(32'h0000_0000, rdata, resp, 0);
        if (resp !== 2'b00 || rdata !== 32'h1234_5678) begin
            $display("FAILED: Word write expected 12345678, got %h (resp %b)", rdata, resp);
            test_errors++;
        end

        // Test 2: Byte writes (WSTRB = 4'b0001, 4'b0010, etc.)
        $display("[Test 2] Byte writes with WSTRB");
        bfm.write(32'h0000_0004, 32'h0000_00AA, 4'b0001, resp, 0, 0); // Byte 0
        bfm.write(32'h0000_0004, 32'h0000_BB00, 4'b0010, resp, 0, 0); // Byte 1
        bfm.write(32'h0000_0004, 32'h00CC_0000, 4'b0100, resp, 0, 0); // Byte 2
        bfm.write(32'h0000_0004, 32'hDD00_0000, 4'b1000, resp, 0, 0); // Byte 3

        bfm.read(32'h0000_0004, rdata, resp, 0);
        if (resp !== 2'b00 || rdata !== 32'hDDCC_BBAA) begin
            $display("FAILED: Byte writes expected DDCCBBAA, got %h", rdata);
            test_errors++;
        end

        // Test 3: Halfword write
        $display("[Test 3] Halfword writes");
        bfm.write(32'h0000_0008, 32'h0000_55AA, 4'b0011, resp, 0, 0);
        bfm.write(32'h0000_0008, 32'h66BB_0000, 4'b1100, resp, 0, 0);

        bfm.read(32'h0000_0008, rdata, resp, 0);
        if (resp !== 2'b00 || rdata !== 32'h66BB_55AA) begin
            $display("FAILED: Halfword writes expected 66BB55AA, got %h", rdata);
            test_errors++;
        end

        repeat (5) @(posedge aclk);
        if (test_errors == 0) begin
            $display("=== [TEST] tb_axi4lite_sram: PASS ===");
        end else begin
            $display("=== [TEST] tb_axi4lite_sram: FAIL with %0d errors ===", test_errors);
        end

        $finish;
    end

endmodule

