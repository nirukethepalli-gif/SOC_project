// ============================================================================
// Testbench:   tb_axi4_to_axilite_bridge
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Self-checking testbench for AXI4-to-AXI4-Lite Bridge.
//              Verifies:
//                1. Single-beat AXI4 Write and Read conversion.
//                2. Multi-beat AXI4 Burst Write (INCR mode) into individual Lite accesses.
//                3. Multi-beat AXI4 Burst Read (INCR mode) with RLAST assertion.
//                4. Valid/Ready handshaking and backpressure.
// ============================================================================

`timescale 1ns / 1ps

module tb_axi4_to_axilite_bridge;

    localparam CLK_PERIOD = 10;
    reg clk;
    reg rst_n;

    // Full AXI4 Master Interface Stimulus
    reg  [3:0]  s_axi_awid;
    reg  [31:0] s_axi_awaddr;
    reg  [7:0]  s_axi_awlen;
    reg  [2:0]  s_axi_awsize;
    reg  [1:0]  s_axi_awburst;
    reg  [2:0]  s_axi_awprot;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wlast;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    wire [3:0]  s_axi_bid;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    reg  [3:0]  s_axi_arid;
    reg  [31:0] s_axi_araddr;
    reg  [7:0]  s_axi_arlen;
    reg  [2:0]  s_axi_arsize;
    reg  [1:0]  s_axi_arburst;
    reg  [2:0]  s_axi_arprot;
    reg         s_axi_arvalid;
    wire        s_axi_arready;

    wire [3:0]  s_axi_rid;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rlast;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // AXI4-Lite Slave Loopback / Monitor
    wire [31:0] m_axil_awaddr;
    wire [2:0]  m_axil_awprot;
    wire        m_axil_awvalid;
    reg         m_axil_awready;

    wire [31:0] m_axil_wdata;
    wire [3:0]  m_axil_wstrb;
    wire        m_axil_wvalid;
    reg         m_axil_wready;

    reg  [1:0]  m_axil_bresp;
    reg         m_axil_bvalid;
    wire        m_axil_bready;

    wire [31:0] m_axil_araddr;
    wire [2:0]  m_axil_arprot;
    wire        m_axil_arvalid;
    reg         m_axil_arready;

    reg  [31:0] m_axil_rdata;
    reg  [1:0]  m_axil_rresp;
    reg         m_axil_rvalid;
    wire        m_axil_rready;

    integer error_count = 0;

    // Simulated Lite Memory
    reg [31:0] lite_mem [0:255];

    // DUT Instantiation
    axi4_to_axilite_bridge #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32),
        .ID_WIDTH(4)
    ) u_dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_awid     (s_axi_awid),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awprot   (s_axi_awprot),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bid      (s_axi_bid),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_arid     (s_axi_arid),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arprot   (s_axi_arprot),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rid      (s_axi_rid),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .m_axil_awaddr  (m_axil_awaddr),
        .m_axil_awprot  (m_axil_awprot),
        .m_axil_awvalid (m_axil_awvalid),
        .m_axil_awready (m_axil_awready),
        .m_axil_wdata   (m_axil_wdata),
        .m_axil_wstrb   (m_axil_wstrb),
        .m_axil_wvalid  (m_axil_wvalid),
        .m_axil_wready  (m_axil_wready),
        .m_axil_bresp   (m_axil_bresp),
        .m_axil_bvalid  (m_axil_bvalid),
        .m_axil_bready  (m_axil_bready),
        .m_axil_araddr  (m_axil_araddr),
        .m_axil_arprot  (m_axil_arprot),
        .m_axil_arvalid (m_axil_arvalid),
        .m_axil_arready (m_axil_arready),
        .m_axil_rdata   (m_axil_rdata),
        .m_axil_rresp   (m_axil_rresp),
        .m_axil_rvalid  (m_axil_rvalid),
        .m_axil_rready  (m_axil_rready)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Simulated AXI4-Lite Slave Behavior
    reg [31:0] captured_lite_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axil_awready <= 1'b0;
            m_axil_wready  <= 1'b0;
            m_axil_bvalid  <= 1'b0;
            m_axil_bresp   <= 2'b00;
            m_axil_arready <= 1'b0;
            m_axil_rvalid  <= 1'b0;
            m_axil_rdata   <= 32'd0;
            m_axil_rresp   <= 2'b00;
        end else begin
            // Lite Write Channel
            if (m_axil_awvalid && !m_axil_awready) begin
                m_axil_awready     <= 1'b1;
                captured_lite_addr <= m_axil_awaddr;
            end else if (m_axil_awready) begin
                m_axil_awready <= 1'b0;
            end

            if (m_axil_wvalid && !m_axil_wready) begin
                m_axil_wready <= 1'b1;
            end else if (m_axil_wready) begin
                lite_mem[captured_lite_addr[9:2]] <= m_axil_wdata;
                m_axil_wready <= 1'b0;
                m_axil_bvalid <= 1'b1;
            end

            if (m_axil_bvalid && m_axil_bready) begin
                m_axil_bvalid <= 1'b0;
            end

            // Lite Read Channel
            if (m_axil_arvalid && !m_axil_arready) begin
                m_axil_arready <= 1'b1;
            end else if (m_axil_arready) begin
                m_axil_arready <= 1'b0;
                m_axil_rvalid  <= 1'b1;
                m_axil_rdata   <= lite_mem[m_axil_araddr[9:2]];
            end

            if (m_axil_rvalid && m_axil_rready) begin
                m_axil_rvalid <= 1'b0;
            end
        end
    end

    initial begin
        $display("===============================================================");
        $display("   STARTING TESTBENCH: AXI4 TO AXI4-LITE BRIDGE                ");
        $display("===============================================================");

        clk = 0;
        rst_n = 0;
        s_axi_awid = 0; s_axi_awaddr = 0; s_axi_awlen = 0; s_axi_awsize = 3'b010;
        s_axi_awburst = 2'b01; s_axi_awprot = 0; s_axi_awvalid = 0;
        s_axi_wdata = 0; s_axi_wstrb = 4'hF; s_axi_wlast = 0; s_axi_wvalid = 0;
        s_axi_bready = 1;
        s_axi_arid = 0; s_axi_araddr = 0; s_axi_arlen = 0; s_axi_arsize = 3'b010;
        s_axi_arburst = 2'b01; s_axi_arprot = 0; s_axi_arvalid = 0;
        s_axi_rready = 1;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // ---------------------------------------------------------------------
        // TEST 1: Single Beat Write & Read (len = 0)
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 1] Single Write & Read Transfer ---");
        @(posedge clk);
        s_axi_awid    <= 4'd1;
        s_axi_awaddr  <= 32'h0003_0010;
        s_axi_awlen   <= 8'd0; // 1 beat
        s_axi_awvalid <= 1'b1;

        @(posedge clk);
        while (!s_axi_awready) @(posedge clk);
        s_axi_awvalid <= 1'b0;

        s_axi_wdata  <= 32'hCAFE_BABE;
        s_axi_wlast  <= 1'b1;
        s_axi_wvalid <= 1'b1;

        @(posedge clk);
        while (!s_axi_wready) @(posedge clk);
        s_axi_wvalid <= 1'b0;
        s_axi_wlast  <= 1'b0;

        while (!s_axi_bvalid) @(posedge clk);
        @(posedge clk);

        // Now Read Back
        s_axi_arid    <= 4'd1;
        s_axi_araddr  <= 32'h0003_0010;
        s_axi_arlen   <= 8'd0;
        s_axi_arvalid <= 1'b1;

        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        s_axi_arvalid <= 1'b0;

        while (!s_axi_rvalid) @(posedge clk);
        $display("[CHECK] Read data: 0x%08X | Expected: 0xCAFEBABE", s_axi_rdata);

        if (s_axi_rdata === 32'hCAFE_BABE && s_axi_rlast === 1'b1) begin
            $display("[PASS] Single AXI4 transfer correctly converted to AXI4-Lite!");
        end else begin
            $display("[FAIL] Read data mismatch!");
            error_count = error_count + 1;
        end

        // ---------------------------------------------------------------------
        // TEST 2: 2-Beat Burst Write & Burst Read (INCR mode)
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 2] 2-Beat Burst Conversion (INCR mode) ---");
        @(posedge clk);
        s_axi_awid    <= 4'd2;
        s_axi_awaddr  <= 32'h0003_0020;
        s_axi_awlen   <= 8'd1; // 2 beats
        s_axi_awvalid <= 1'b1;

        @(posedge clk);
        while (!s_axi_awready) @(posedge clk);
        s_axi_awvalid <= 1'b0;

        // Beat 0
        s_axi_wdata  <= 32'h1111_2222;
        s_axi_wlast  <= 1'b0;
        s_axi_wvalid <= 1'b1;
        @(posedge clk);
        while (!s_axi_wready) @(posedge clk);

        // Beat 1
        s_axi_wdata  <= 32'h3333_4444;
        s_axi_wlast  <= 1'b1;
        s_axi_wvalid <= 1'b1;
        @(posedge clk);
        while (!s_axi_wready) @(posedge clk);
        s_axi_wvalid <= 1'b0;
        s_axi_wlast  <= 1'b0;

        while (!s_axi_bvalid) @(posedge clk);
        $display("[PASS] Burst write response received!");

        // Read Back Burst
        s_axi_arid    <= 4'd2;
        s_axi_araddr  <= 32'h0003_0020;
        s_axi_arlen   <= 8'd1; // 2 beats
        s_axi_arvalid <= 1'b1;

        @(posedge clk);
        while (!s_axi_arready) @(posedge clk);
        s_axi_arvalid <= 1'b0;

        // Beat 0
        while (!s_axi_rvalid) @(posedge clk);
        $display("[CHECK] Burst Beat 0: 0x%08X (rlast=%b)", s_axi_rdata, s_axi_rlast);
        if (s_axi_rdata !== 32'h1111_2222 || s_axi_rlast !== 1'b0) error_count = error_count + 1;

        @(posedge clk);
        // Beat 1
        while (!s_axi_rvalid) @(posedge clk);
        $display("[CHECK] Burst Beat 1: 0x%08X (rlast=%b)", s_axi_rdata, s_axi_rlast);
        if (s_axi_rdata !== 32'h3333_4444 || s_axi_rlast !== 1'b1) error_count = error_count + 1;

        $display("===============================================================");
        if (error_count == 0)
            $display("   TEST RESULT: ALL BRIDGE TESTS PASSED!                       ");
        else
            $display("   TEST RESULT: %0d TESTS FAILED!                              ", error_count);
        $display("===============================================================");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
