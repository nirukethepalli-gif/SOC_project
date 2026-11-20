// SPDX-License-Identifier: Apache-2.0
// Unit Testbench for axi4lite_interconnect per Section 14.1 of SoC Specification v2.0

`timescale 1ns/1ps

module tb_axi4lite_interconnect;

    localparam int NSLV = 9;

    logic aclk;
    logic aresetn;

    initial aclk = 0;
    always #10 aclk = ~aclk;

    // Master signals
    logic [31:0] m_awaddr;
    logic [2:0]  m_awprot;
    logic        m_awvalid;
    logic        m_awready;

    logic [31:0] m_wdata;
    logic [3:0]  m_wstrb;
    logic        m_wvalid;
    logic        m_wready;

    logic [1:0]  m_bresp;
    logic        m_bvalid;
    logic        m_bready;

    logic [31:0] m_araddr;
    logic [2:0]  m_arprot;
    logic        m_arvalid;
    logic        m_arready;

    logic [31:0] m_rdata;
    logic [1:0]  m_rresp;
    logic        m_rvalid;
    logic        m_rready;

    // Slave signals
    logic [NSLV-1:0][31:0] s_awaddr;
    logic [NSLV-1:0][2:0]  s_awprot;
    logic [NSLV-1:0]       s_awvalid;
    logic [NSLV-1:0]       s_awready;

    logic [NSLV-1:0][31:0] s_wdata;
    logic [NSLV-1:0][3:0]  s_wstrb;
    logic [NSLV-1:0]       s_wvalid;
    logic [NSLV-1:0]       s_wready;

    logic [NSLV-1:0][1:0]  s_bresp;
    logic [NSLV-1:0]       s_bvalid;
    logic [NSLV-1:0]       s_bready;

    logic [NSLV-1:0][31:0] s_araddr;
    logic [NSLV-1:0][2:0]  s_arprot;
    logic [NSLV-1:0]       s_arvalid;
    logic [NSLV-1:0]       s_arready;

    logic [NSLV-1:0][31:0] s_rdata;
    logic [NSLV-1:0][1:0]  s_rresp;
    logic [NSLV-1:0]       s_rvalid;
    logic [NSLV-1:0]       s_rready;

    // DUT
    axi4lite_interconnect #(.NSLV(NSLV)) dut (
        .aclk       (aclk),
        .aresetn    (aresetn),
        .m_awaddr   (m_awaddr),
        .m_awprot   (m_awprot),
        .m_awvalid  (m_awvalid),
        .m_awready  (m_awready),
        .m_wdata    (m_wdata),
        .m_wstrb    (m_wstrb),
        .m_wvalid   (m_wvalid),
        .m_wready   (m_wready),
        .m_bresp    (m_bresp),
        .m_bvalid   (m_bvalid),
        .m_bready   (m_bready),
        .m_araddr   (m_araddr),
        .m_arprot   (m_arprot),
        .m_arvalid  (m_arvalid),
        .m_arready  (m_arready),
        .m_rdata    (m_rdata),
        .m_rresp    (m_rresp),
        .m_rvalid   (m_rvalid),
        .m_rready   (m_rready),
        .s_awaddr   (s_awaddr),
        .s_awprot   (s_awprot),
        .s_awvalid  (s_awvalid),
        .s_awready  (s_awready),
        .s_wdata    (s_wdata),
        .s_wstrb    (s_wstrb),
        .s_wvalid   (s_wvalid),
        .s_wready   (s_wready),
        .s_bresp    (s_bresp),
        .s_bvalid   (s_bvalid),
        .s_bready   (s_bready),
        .s_araddr   (s_araddr),
        .s_arprot   (s_arprot),
        .s_arvalid  (s_arvalid),
        .s_arready  (s_arready),
        .s_rdata    (s_rdata),
        .s_rresp    (s_rresp),
        .s_rvalid   (s_rvalid),
        .s_rready   (s_rready)
    );

    // Master BFM
    axi4lite_master_bfm bfm (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .m_awaddr (m_awaddr),
        .m_awprot (m_awprot),
        .m_awvalid(m_awvalid),
        .m_awready(m_awready),
        .m_wdata  (m_wdata),
        .m_wstrb  (m_wstrb),
        .m_wvalid (m_wvalid),
        .m_wready (m_wready),
        .m_bresp  (m_bresp),
        .m_bvalid (m_bvalid),
        .m_bready (m_bready),
        .m_araddr (m_araddr),
        .m_arprot (m_arprot),
        .m_arvalid(m_arvalid),
        .m_arready(m_arready),
        .m_rdata  (m_rdata),
        .m_rresp  (m_rresp),
        .m_rvalid (m_rvalid),
        .m_rready (m_rready)
    );

    // Instantiate 8 slave BFMs for Slaves 0..7
    genvar gi;
    generate
        for (gi = 0; gi < 8; gi++) begin : gen_slaves
            axi4lite_slave_bfm #(.DEPTH_WORDS(256)) u_slv (
                .aclk       (aclk),
                .aresetn    (aresetn),
                .s_awaddr   (s_awaddr[gi]),
                .s_awprot   (s_awprot[gi]),
                .s_awvalid  (s_awvalid[gi]),
                .s_awready  (s_awready[gi]),
                .s_wdata    (s_wdata[gi]),
                .s_wstrb    (s_wstrb[gi]),
                .s_wvalid   (s_wvalid[gi]),
                .s_wready   (s_wready[gi]),
                .s_bresp    (s_bresp[gi]),
                .s_bvalid   (s_bvalid[gi]),
                .s_bready   (s_bready[gi]),
                .s_araddr   (s_araddr[gi]),
                .s_arprot   (s_arprot[gi]),
                .s_arvalid  (s_arvalid[gi]),
                .s_arready  (s_arready[gi]),
                .s_rdata    (s_rdata[gi]),
                .s_rresp    (s_rresp[gi]),
                .s_rvalid   (s_rvalid[gi]),
                .s_rready   (s_rready[gi]),
                .ready_delay(0),
                .force_bresp(2'b00),
                .force_rresp(2'b00)
            );
        end
    endgenerate

    // Slave 8 is the Error Slave
    axi4lite_err_slave u_err_slv (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_awaddr (s_awaddr[8]),
        .s_awprot (s_awprot[8]),
        .s_awvalid(s_awvalid[8]),
        .s_awready(s_awready[8]),
        .s_wdata  (s_wdata[8]),
        .s_wstrb  (s_wstrb[8]),
        .s_wvalid (s_wvalid[8]),
        .s_wready (s_wready[8]),
        .s_bresp  (s_bresp[8]),
        .s_bvalid (s_bvalid[8]),
        .s_bready (s_bready[8]),
        .s_araddr (s_araddr[8]),
        .s_arprot (s_arprot[8]),
        .s_arvalid(s_arvalid[8]),
        .s_arready(s_arready[8]),
        .s_rdata  (s_rdata[8]),
        .s_rresp  (s_rresp[8]),
        .s_rvalid (s_rvalid[8]),
        .s_rready (s_rready[8])
    );

    int test_errors = 0;

    // Address list for all 8 valid slaves
    logic [31:0] test_addrs [0:7] = '{
        32'h0000_0010, // IMEM
        32'h1000_0020, // DMEM
        32'h8000_0000, // UART
        32'h8000_1000, // TIMER
        32'h8000_2000, // GPIO
        32'h8000_3000, // I2C
        32'h8000_4000, // FIR
        32'h8000_5000  // PWM
    };

    initial begin
        logic [31:0] rdata;
        logic [1:0]  resp;

        aresetn = 1'b0;
        bfm.reset_master();
        repeat (5) @(posedge aclk);
        aresetn = 1'b1;
        repeat (5) @(posedge aclk);

        $display("=== [TEST] tb_axi4lite_interconnect START ===");

        // Test 1: Write and read to each of the 8 mapped slaves
        for (int i = 0; i < 8; i++) begin
            automatic logic [31:0] test_val = 32'hA000_0000 | i;
            bfm.write(test_addrs[i], test_val, 4'hF, resp, 0, 0);
            if (resp !== 2'b00) begin
                $display("FAILED: Write to slave %0d at %h returned resp %b", i, test_addrs[i], resp);
                test_errors++;
            end

            bfm.read(test_addrs[i], rdata, resp, 0);
            if (resp !== 2'b00 || rdata !== test_val) begin
                $display("FAILED: Read from slave %0d returned %h (resp %b), expected %h", i, rdata, resp, test_val);
                test_errors++;
            end
        end

        // Test 2: Unmapped address -> DECERR
        $display("[Test 2] Unmapped address decode error");
        bfm.write(32'h7000_0000, 32'hBAD0_0000, 4'hF, resp, 0, 0);
        if (resp !== 2'b11) begin
            $display("FAILED: Expected DECERR (2'b11) on write to unmapped, got %b", resp);
            test_errors++;
        end

        bfm.read(32'h7000_0000, rdata, resp, 0);
        if (resp !== 2'b11) begin
            $display("FAILED: Expected DECERR (2'b11) on read from unmapped, got %b", resp);
            test_errors++;
        end

        // Test 3: Unmapped peripheral address (e.g. 0x8000_6000) -> DECERR
        bfm.read(32'h8000_6000, rdata, resp, 0);
        if (resp !== 2'b11) begin
            $display("FAILED: Expected DECERR on read from 0x8000_6000, got %b", resp);
            test_errors++;
        end

        // Test 4: Independent concurrent read and write in flight
        $display("[Test 4] Concurrent read and write in flight");
        fork
            bfm.write(test_addrs[1], 32'h5555_AAAA, 4'hF, resp, 0, 0);
            bfm.read(test_addrs[0], rdata, resp, 0);
        join

        repeat (5) @(posedge aclk);
        if (test_errors == 0) begin
            $display("=== [TEST] tb_axi4lite_interconnect: PASS ===");
        end else begin
            $display("=== [TEST] tb_axi4lite_interconnect: FAIL with %0d errors ===", test_errors);
        end

        $finish;
    end

endmodule

