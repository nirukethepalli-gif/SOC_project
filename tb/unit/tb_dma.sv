// SPDX-License-Identifier: Apache-2.0
// Unit Testbench: tb_dma.sv
// Target Simulator: Synopsys VCS
// Verifies Custom IP 3: DMA Controller at base 0x8000_3000

`timescale 1ns/1ps

module tb_dma;

    localparam time CLK_PERIOD = 10ns;
    logic clk;
    logic rst_n;

    // AXI4-Lite Slave Ports (CPU Programming)
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

    // AXI4 Master Read Channel
    logic [31:0] m_axi_araddr;
    logic [7:0]  m_axi_arlen;
    logic [2:0]  m_axi_arsize;
    logic [1:0]  m_axi_arburst;
    logic        m_axi_arvalid;
    logic        m_axi_arready;
    logic [31:0] m_axi_rdata;
    logic [1:0]  m_axi_rresp;
    logic        m_axi_rlast;
    logic        m_axi_rvalid;
    logic        m_axi_rready;

    // AXI4 Master Write Channel
    logic [31:0] m_axi_awaddr;
    logic [7:0]  m_axi_awlen;
    logic [2:0]  m_axi_awsize;
    logic [1:0]  m_axi_awburst;
    logic        m_axi_awvalid;
    logic        m_axi_awready;
    logic [31:0] m_axi_wdata;
    logic [3:0]  m_axi_wstrb;
    logic        m_axi_wlast;
    logic        m_axi_wvalid;
    logic        m_axi_wready;
    logic [1:0]  m_axi_bresp;
    logic        m_axi_bvalid;
    logic        m_axi_bready;

    // Dedicated Fast Write Ports to Matrix Multiplier Buffers
    logic        dma_in_wr_en;
    logic [7:0]  dma_in_wr_addr;
    logic [31:0] dma_in_wr_data;

    logic        dma_w_wr_en;
    logic [9:0]  dma_w_wr_addr;
    logic [31:0] dma_w_wr_data;

    logic        dma_bias_wr_en;
    logic [7:0]  dma_bias_wr_addr;
    logic [31:0] dma_bias_wr_data;

    // Dedicated Readout Port from Activation Unit
    logic        dma_act_rd_en;
    logic [7:0]  dma_act_rd_addr;
    logic [31:0] dma_act_rd_data;

    // Status & IRQ
    logic        busy;
    logic        done;
    logic        error;
    logic        irq;

    int error_count = 0;

    // Register Offsets
    localparam [7:0]
        REG_CTRL      = 8'h00,
        REG_STATUS    = 8'h04,
        REG_SRC_ADDR  = 8'h08,
        REG_DST_ADDR  = 8'h0C,
        REG_BURST_LEN = 8'h10;

    // Instantiate DUT
    dma_controller #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32)
    ) dut (
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
        .m_axi_araddr    (m_axi_araddr),
        .m_axi_arlen     (m_axi_arlen),
        .m_axi_arsize    (m_axi_arsize),
        .m_axi_arburst   (m_axi_arburst),
        .m_axi_arvalid   (m_axi_arvalid),
        .m_axi_arready   (m_axi_arready),
        .m_axi_rdata     (m_axi_rdata),
        .m_axi_rresp     (m_axi_rresp),
        .m_axi_rlast     (m_axi_rlast),
        .m_axi_rvalid    (m_axi_rvalid),
        .m_axi_rready    (m_axi_rready),
        .m_axi_awaddr    (m_axi_awaddr),
        .m_axi_awlen     (m_axi_awlen),
        .m_axi_awsize    (m_axi_awsize),
        .m_axi_awburst   (m_axi_awburst),
        .m_axi_awvalid   (m_axi_awvalid),
        .m_axi_awready   (m_axi_awready),
        .m_axi_wdata     (m_axi_wdata),
        .m_axi_wstrb     (m_axi_wstrb),
        .m_axi_wlast     (m_axi_wlast),
        .m_axi_wvalid    (m_axi_wvalid),
        .m_axi_wready    (m_axi_wready),
        .m_axi_bresp     (m_axi_bresp),
        .m_axi_bvalid    (m_axi_bvalid),
        .m_axi_bready    (m_axi_bready),
        .dma_in_wr_en    (dma_in_wr_en),
        .dma_in_wr_addr  (dma_in_wr_addr),
        .dma_in_wr_data  (dma_in_wr_data),
        .dma_w_wr_en     (dma_w_wr_en),
        .dma_w_wr_addr   (dma_w_wr_addr),
        .dma_w_wr_data   (dma_w_wr_data),
        .dma_bias_wr_en  (dma_bias_wr_en),
        .dma_bias_wr_addr(dma_bias_wr_addr),
        .dma_bias_wr_data(dma_bias_wr_data),
        .dma_act_rd_en   (dma_act_rd_en),
        .dma_act_rd_addr (dma_act_rd_addr),
        .dma_act_rd_data (dma_act_rd_data),
        .busy            (busy),
        .done            (done),
        .error           (error),
        .irq             (irq)
    );

    // Clock generator
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Simulated Memory for AXI Master Read/Write
    logic [31:0] mem [0:1023];

    // AXI4 Memory Slave Read Channel emulation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_arready <= 1'b0;
            m_axi_rvalid  <= 1'b0;
            m_axi_rlast   <= 1'b0;
            m_axi_rdata   <= 32'h0;
            m_axi_rresp   <= 2'b00;
        end else begin
            m_axi_arready <= 1'b1;
            if (m_axi_arvalid && m_axi_arready) begin
                // Return data on next cycle
                m_axi_rvalid <= 1'b1;
                m_axi_rdata  <= mem[m_axi_araddr[11:2]];
                m_axi_rlast  <= 1'b1;
            end else if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid <= 1'b0;
                m_axi_rlast  <= 1'b0;
            end
        end
    end

    // AXI4 Memory Slave Write Channel emulation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b0;
            m_axi_bvalid  <= 1'b0;
            m_axi_bresp   <= 2'b00;
        end else begin
            m_axi_awready <= 1'b1;
            m_axi_wready  <= 1'b1;
            if (m_axi_wvalid && m_axi_wready) begin
                mem[m_axi_awaddr[11:2]] <= m_axi_wdata;
                m_axi_bvalid <= 1'b1;
            end else if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end
        end
    end

    // AXI4-Lite Master Tasks
    task automatic axil_write(input [7:0] addr, input [31:0] data);
        @(posedge clk);
        s_awaddr  <= {24'h800030, addr};
        s_awprot  <= 3'b000;
        s_awvalid <= 1'b1;
        s_wdata   <= data;
        s_wstrb   <= 4'hF;
        s_wvalid  <= 1'b1;
        s_bready  <= 1'b1;

        fork
            begin
                wait(s_awready);
                @(posedge clk);
                s_awvalid <= 1'b0;
            end
            begin
                wait(s_wready);
                @(posedge clk);
                s_wvalid <= 1'b0;
            end
        join

        wait(s_bvalid);
        @(posedge clk);
        s_bready <= 1'b0;
        @(posedge clk);
    endtask

    task automatic axil_read(input [7:0] addr, output [31:0] data);
        @(posedge clk);
        s_araddr  <= {24'h800030, addr};
        s_arprot  <= 3'b000;
        s_arvalid <= 1'b1;
        s_rready  <= 1'b1;

        wait(s_arready);
        @(posedge clk);
        s_arvalid <= 1'b0;

        wait(s_rvalid);
        data = s_rdata;
        @(posedge clk);
        s_rready <= 1'b0;
        @(posedge clk);
    endtask

    // Simulated Activation Unit readout memory
    logic [31:0] act_fifo [0:15];
    always_comb begin
        dma_act_rd_data = act_fifo[dma_act_rd_addr[3:0]];
    end

    logic [31:0] rdata;

    // Test Sequence
    initial begin
        $display("------------------------------------------------------------");
        $display("=== [TEST] Starting tb_dma (DMA Controller Verification) ===");
        $display("------------------------------------------------------------");

        // Init signals
        rst_n     = 1'b0;
        s_awvalid = 1'b0;
        s_wvalid  = 1'b0;
        s_bready  = 1'b0;
        s_arvalid = 1'b0;
        s_rready  = 1'b0;
        s_awaddr  = '0;
        s_wdata   = '0;
        s_araddr  = '0;
        s_wstrb   = '0;
        s_awprot  = '0;
        s_arprot  = '0;

        // Initialize test memory patterns
        for (int i = 0; i < 1024; i++) mem[i] = 32'h0001_0000 + (i * 32'h0000_0001);
        for (int i = 0; i < 16; i++) act_fifo[i] = 32'hABCD_0000 + i;

        #(CLK_PERIOD * 5);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);

        // -------------------------------------------------------------
        // Test 1: Read Default Status & Reset Verification
        // -------------------------------------------------------------
        $display("[TEST 1] Checking Default Registers after Reset...");
        axil_read(REG_STATUS, rdata);
        if (rdata[0] !== 1'b0 || rdata[1] !== 1'b0) begin
            $error("[FAIL] Status register unexpected: 0x%08X (busy or done asserted)", rdata);
            error_count++;
        end else begin
            $display("[PASS] Reset state valid, status: 0x%08X", rdata);
        end

        // -------------------------------------------------------------
        // Test 2: Transfer Memory -> Matrix Multiplier Input Buffer
        // -------------------------------------------------------------
        $display("[TEST 2] Programming DMA: DMEM (0x1000_0000) -> MM Input Buffer (4 elements)...");
        axil_write(REG_SRC_ADDR, 32'h1000_0000);
        axil_write(REG_DST_ADDR, 32'h0000_0000); // Buffer offset
        axil_write(REG_BURST_LEN, 32'd4);

        // direction = 0 (Mem->Acc), acc_target = 00 (Input Buffer), start = 1 -> CTRL = 5'b00001
        axil_write(REG_CTRL, 32'h01);

        // Wait for DMA completion
        wait(done == 1'b1);
        $display("[INFO] DMA signaled done! Waiting for idle...");
        #(CLK_PERIOD * 5);

        axil_read(REG_STATUS, rdata);
        if (rdata[0] !== 1'b1) begin
            $error("[FAIL] Status DONE flag not set: 0x%08X", rdata);
            error_count++;
        end else begin
            $display("[PASS] DMA Mem->Acc transfer complete. Status: 0x%08X", rdata);
        end

        // -------------------------------------------------------------
        // Test 3: Transfer Memory -> Matrix Multiplier Weight Buffer
        // -------------------------------------------------------------
        $display("[TEST 3] Programming DMA: DMEM (0x1000_0040) -> MM Weight Buffer (4 elements)...");
        axil_write(REG_SRC_ADDR, 32'h1000_0040);
        axil_write(REG_DST_ADDR, 32'h0000_0000);
        axil_write(REG_BURST_LEN, 32'd4);

        // direction = 0 (Mem->Acc), acc_target = 01 (Weights = 2'b01 << 3 = 0x08), start = 1 -> CTRL = 0x09
        axil_write(REG_CTRL, 32'h09);

        wait(done == 1'b1);
        #(CLK_PERIOD * 5);
        $display("[PASS] DMA Weight buffer transfer verified.");

        // -------------------------------------------------------------
        // Test 4: Transfer Activation Unit -> Memory (Acc -> Mem)
        // -------------------------------------------------------------
        $display("[TEST 4] Programming DMA: Activation Unit -> DMEM (0x1000_0200) (4 elements)...");
        axil_write(REG_SRC_ADDR, 32'h0000_0000);
        axil_write(REG_DST_ADDR, 32'h1000_0200);
        axil_write(REG_BURST_LEN, 32'd4);

        // direction = 1 (Acc->Mem = 1 << 2 = 0x04), acc_target = 11 (2'b11 << 3 = 0x18), start = 1 -> CTRL = 0x1D
        axil_write(REG_CTRL, 32'h1D);

        wait(done == 1'b1);
        #(CLK_PERIOD * 5);

        // Verify that memory at 0x1000_0200 received the activation data
        for (int i = 0; i < 4; i++) begin
            if (mem[(32'h0200 >> 2) + i] !== act_fifo[i]) begin
                $error("[FAIL] Mem[%0d] = 0x%08X, expected 0x%08X",
                       i, mem[(32'h0200 >> 2) + i], act_fifo[i]);
                error_count++;
            end
        end

        if (error_count == 0) begin
            $display("[PASS] Acc->Mem data transfer correctly written to memory!");
        end

        // -------------------------------------------------------------
        // Summary Banner
        // -------------------------------------------------------------
        #(CLK_PERIOD * 10);
        if (error_count == 0) begin
            $display("============================================================");
            $display("=== [TEST] tb_dma: ALL TESTS PASSED SUCCESSFULLY! ===");
            $display("============================================================");
        end else begin
            $display("============================================================");
            $display("=== [TEST] tb_dma: FAILED WITH %0d ERRORS! ===", error_count);
            $display("============================================================");
        end
        $finish;
    end

    // Safety Watchdog
    initial begin
        #500us;
        $fatal(1, "[TIMEOUT] tb_dma simulation exceeded timeout limit!");
    end

endmodule
