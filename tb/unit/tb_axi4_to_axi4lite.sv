// SPDX-License-Identifier: Apache-2.0
// Unit Testbench for axi4_to_axi4lite Bridge per Section 14.1 of SoC Specification v2.0

`timescale 1ns/1ps

module tb_axi4_to_axi4lite;

    localparam int ID_WIDTH = 4;

    logic aclk;
    logic aresetn;

    initial aclk = 0;
    always #10 aclk = ~aclk;

    // Full AXI4 signals
    logic [ID_WIDTH-1:0] s_axi_awid;
    logic [31:0]         s_axi_awaddr;
    logic [7:0]          s_axi_awlen;
    logic [2:0]          s_axi_awsize;
    logic [1:0]          s_axi_awburst;
    logic [2:0]          s_axi_awprot;
    logic                s_axi_awvalid;
    logic                s_axi_awready;

    logic [63:0]         s_axi_wdata;
    logic [7:0]          s_axi_wstrb;
    logic                s_axi_wlast;
    logic                s_axi_wvalid;
    logic                s_axi_wready;

    logic [ID_WIDTH-1:0] s_axi_bid;
    logic [1:0]          s_axi_bresp;
    logic                s_axi_bvalid;
    logic                s_axi_bready;

    logic [ID_WIDTH-1:0] s_axi_arid;
    logic [31:0]         s_axi_araddr;
    logic [7:0]          s_axi_arlen;
    logic [2:0]          s_axi_arsize;
    logic [1:0]          s_axi_arburst;
    logic [2:0]          s_axi_arprot;
    logic                s_axi_arvalid;
    logic                s_axi_arready;

    logic [ID_WIDTH-1:0] s_axi_rid;
    logic [63:0]         s_axi_rdata;
    logic [1:0]          s_axi_rresp;
    logic                s_axi_rlast;
    logic                s_axi_rvalid;
    logic                s_axi_rready;

    // AXI4-Lite signals
    logic [31:0]         m_axil_awaddr;
    logic [2:0]          m_axil_awprot;
    logic                m_axil_awvalid;
    logic                m_axil_awready;

    logic [31:0]         m_axil_wdata;
    logic [3:0]          m_axil_wstrb;
    logic                m_axil_wvalid;
    logic                m_axil_wready;

    logic [1:0]          m_axil_bresp;
    logic                m_axil_bvalid;
    logic                m_axil_bready;

    logic [31:0]         m_axil_araddr;
    logic [2:0]          m_axil_arprot;
    logic                m_axil_arvalid;
    logic                m_axil_arready;

    logic [31:0]         m_axil_rdata;
    logic [1:0]          m_axil_rresp;
    logic                m_axil_rvalid;
    logic                m_axil_rready;

    // DUT
    axi4_to_axi4lite #(.ID_WIDTH(ID_WIDTH)) dut (
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axi_awid    (s_axi_awid),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awlen   (s_axi_awlen),
        .s_axi_awsize  (s_axi_awsize),
        .s_axi_awburst (s_axi_awburst),
        .s_axi_awprot  (s_axi_awprot),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wlast   (s_axi_wlast),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bid     (s_axi_bid),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_arid    (s_axi_arid),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arlen   (s_axi_arlen),
        .s_axi_arsize  (s_axi_arsize),
        .s_axi_arburst (s_axi_arburst),
        .s_axi_arprot  (s_axi_arprot),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rid     (s_axi_rid),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rlast   (s_axi_rlast),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .m_axil_awaddr (m_axil_awaddr),
        .m_axil_awprot (m_axil_awprot),
        .m_axil_awvalid(m_axil_awvalid),
        .m_axil_awready(m_axil_awready),
        .m_axil_wdata  (m_axil_wdata),
        .m_axil_wstrb  (m_axil_wstrb),
        .m_axil_wvalid (m_axil_wvalid),
        .m_axil_wready (m_axil_wready),
        .m_axil_bresp  (m_axil_bresp),
        .m_axil_bvalid (m_axil_bvalid),
        .m_axil_bready (m_axil_bready),
        .m_axil_araddr (m_axil_araddr),
        .m_axil_arprot (m_axil_arprot),
        .m_axil_arvalid(m_axil_arvalid),
        .m_axil_arready(m_axil_arready),
        .m_axil_rdata  (m_axil_rdata),
        .m_axil_rresp  (m_axil_rresp),
        .m_axil_rvalid (m_axil_rvalid),
        .m_axil_rready (m_axil_rready)
    );

    // Lite Slave BFM to respond to downstream requests
    axi4lite_slave_bfm #(.DEPTH_WORDS(1024)) u_slave (
        .aclk       (aclk),
        .aresetn    (aresetn),
        .s_awaddr   (m_axil_awaddr),
        .s_awprot   (m_axil_awprot),
        .s_awvalid  (m_axil_awvalid),
        .s_awready  (m_axil_awready),
        .s_wdata    (m_axil_wdata),
        .s_wstrb    (m_axil_wstrb),
        .s_wvalid   (m_axil_wvalid),
        .s_wready   (m_axil_wready),
        .s_bresp    (m_axil_bresp),
        .s_bvalid   (m_axil_bvalid),
        .s_bready   (m_axil_bready),
        .s_araddr   (m_axil_araddr),
        .s_arprot   (m_axil_arprot),
        .s_arvalid  (m_axil_arvalid),
        .s_arready  (m_axil_arready),
        .s_rdata    (m_axil_rdata),
        .s_rresp    (m_axil_rresp),
        .s_rvalid   (m_axil_rvalid),
        .s_rready   (m_axil_rready),
        .ready_delay(0),
        .force_bresp(2'b00),
        .force_rresp(2'b00)
    );

    int test_errors = 0;

    // Master tasks to drive full AXI4
    task automatic axi4_write_single(
        input logic [ID_WIDTH-1:0] id,
        input logic [31:0]         addr,
        input logic [63:0]         data,
        input logic [7:0]          strb
    );
        @(posedge aclk);
        s_axi_awid    <= id;
        s_axi_awaddr  <= addr;
        s_axi_awlen   <= 8'h0;
        s_axi_awsize  <= 3'd3; // 8 bytes
        s_axi_awburst <= 2'b01; // INCR
        s_axi_awprot  <= 3'b000;
        s_axi_awvalid <= 1'b1;
        while (!s_axi_awready) @(posedge aclk);
        @(posedge aclk);
        s_axi_awvalid <= 1'b0;

        s_axi_wdata  <= data;
        s_axi_wstrb  <= strb;
        s_axi_wlast  <= 1'b1;
        s_axi_wvalid <= 1'b1;
        while (!s_axi_wready) @(posedge aclk);
        @(posedge aclk);
        s_axi_wvalid <= 1'b0;

        s_axi_bready <= 1'b1;
        while (!s_axi_bvalid) @(posedge aclk);
        if (s_axi_bid !== id || s_axi_bresp !== 2'b00) begin
            $display("FAILED: axi4_write_single id=%h resp=%b", s_axi_bid, s_axi_bresp);
            test_errors++;
        end
        @(posedge aclk);
        s_axi_bready <= 1'b0;
    endtask

    task automatic axi4_read_burst(
        input logic [ID_WIDTH-1:0] id,
        input logic [31:0]         addr,
        input logic [7:0]          len,
        input logic [2:0]          size
    );
        @(posedge aclk);
        s_axi_arid    <= id;
        s_axi_araddr  <= addr;
        s_axi_arlen   <= len;
        s_axi_arsize  <= size;
        s_axi_arburst <= 2'b01;
        s_axi_arprot  <= 3'b000;
        s_axi_arvalid <= 1'b1;
        while (!s_axi_arready) @(posedge aclk);
        @(posedge aclk);
        s_axi_arvalid <= 1'b0;

        for (int i = 0; i <= len; i++) begin
            s_axi_rready <= 1'b1;
            while (!s_axi_rvalid) @(posedge aclk);
            if (s_axi_rid !== id) begin
                $display("FAILED: Read beat %0d ID mismatch (%h vs %h)", i, s_axi_rid, id);
                test_errors++;
            end
            if (i == len && !s_axi_rlast) begin
                $display("FAILED: Expected RLAST on final beat %0d", i);
                test_errors++;
            end
            @(posedge aclk);
        end
        s_axi_rready <= 1'b0;
    endtask

    initial begin
        s_axi_awvalid = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;

        aresetn = 1'b0;
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        repeat (5) @(posedge aclk);

        $display("=== [TEST] tb_axi4_to_axi4lite START ===");

        // Test 1: Write low lane only (WSTRB = 8'h0F)
        $display("[Test 1] 32-bit store low lane");
        axi4_write_single(4'h1, 32'h0000_0000, 64'h0000_0000_1111_2222, 8'h0F);

        // Test 2: Write high lane only (WSTRB = 8'hF0)
        $display("[Test 2] 32-bit store high lane");
        axi4_write_single(4'h2, 32'h0000_0000, 64'h3333_4444_0000_0000, 8'hF0);

        // Test 3: Write both lanes (WSTRB = 8'hFF)
        $display("[Test 3] 64-bit store both lanes");
        axi4_write_single(4'h3, 32'h0000_0008, 64'h7777_8888_5555_6666, 8'hFF);

        // Test 4: Single 64-bit read (ARLEN = 0, ARSIZE = 3)
        $display("[Test 4] Single 64-bit read");
        axi4_read_burst(4'h4, 32'h0000_0008, 8'h0, 3'd3);

        // Test 5: Burst read with ARLEN = 1 (2 beats)
        $display("[Test 5] Burst read ARLEN=1");
        axi4_read_burst(4'h5, 32'h0000_0000, 8'h1, 3'd3);

        // Test 6: Burst read with ARLEN = 3 (4 beats)
        $display("[Test 6] Burst read ARLEN=3");
        axi4_read_burst(4'h6, 32'h0000_0000, 8'h3, 3'd3);

        repeat (5) @(posedge aclk);
        if (test_errors == 0) begin
            $display("=== [TEST] tb_axi4_to_axi4lite: PASS ===");
        end else begin
            $display("=== [TEST] tb_axi4_to_axi4lite: FAIL with %0d errors ===", test_errors);
        end

        $finish;
    end

endmodule

