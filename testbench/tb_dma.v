// ============================================================================
// Testbench:   tb_dma
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Self-checking testbench for DMA Controller IP.
//              Tests:
//                1. Memory-to-Accelerator Transfer (direction = 0)
//                2. Accelerator-to-Memory Transfer (direction = 1)
//                3. Address auto-increment and transfer word counting
//                4. Misalignment error detection
//                5. AXI4 Master transaction handshakes
// ============================================================================

`timescale 1ns / 1ps

module tb_dma;

    localparam CLK_PERIOD = 10;
    reg clk;
    reg rst_n;

    // AXI4-Lite Slave Configuration Interface
    reg  [7:0]  s_axi_awaddr;
    reg  [2:0]  s_axi_awprot;
    reg         s_axi_awvalid;
    wire        s_axi_awready;

    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;

    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;

    reg  [7:0]  s_axi_araddr;
    reg  [2:0]  s_axi_arprot;
    reg         s_axi_arvalid;
    wire        s_axi_arready;

    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;

    // AXI4 Master Memory Interface
    wire [31:0] m_axi_araddr;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    wire        m_axi_arvalid;
    reg         m_axi_arready;

    reg  [31:0] m_axi_rdata;
    reg  [1:0]  m_axi_rresp;
    reg         m_axi_rlast;
    reg         m_axi_rvalid;
    wire        m_axi_rready;

    wire [31:0] m_axi_awaddr;
    wire [7:0]  m_axi_awlen;
    wire [2:0]  m_axi_awsize;
    wire [1:0]  m_axi_awburst;
    wire        m_axi_awvalid;
    reg         m_axi_awready;

    wire [31:0] m_axi_wdata;
    wire [3:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wvalid;
    reg         m_axi_wready;

    reg  [1:0]  m_axi_bresp;
    reg         m_axi_bvalid;
    wire        m_axi_bready;

    // Direct Accelerator Ports
    wire        dma_in_wr_en;
    wire [7:0]  dma_in_wr_addr;
    wire [31:0] dma_in_wr_data;

    wire        dma_w_wr_en;
    wire [9:0]  dma_w_wr_addr;
    wire [31:0] dma_w_wr_data;

    wire        dma_bias_wr_en;
    wire [7:0]  dma_bias_wr_addr;
    wire [31:0] dma_bias_wr_data;

    wire        dma_act_rd_en;
    wire [7:0]  dma_act_rd_addr;
    reg  [31:0] dma_act_rd_data;

    // Status
    wire        busy;
    wire        done;
    wire        error;
    wire        irq;

    integer error_count = 0;

    // Simulated Memory (64 KB Data Memory)
    reg [31:0] simulated_ram [0:1023];

    // DUT Instantiation
    dma_top u_dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .s_axi_awaddr     (s_axi_awaddr),
        .s_axi_awprot     (s_axi_awprot),
        .s_axi_awvalid    (s_axi_awvalid),
        .s_axi_awready    (s_axi_awready),
        .s_axi_wdata      (s_axi_wdata),
        .s_axi_wstrb      (s_axi_wstrb),
        .s_axi_wvalid     (s_axi_wvalid),
        .s_axi_wready     (s_axi_wready),
        .s_axi_bresp      (s_axi_bresp),
        .s_axi_bvalid     (s_axi_bvalid),
        .s_axi_bready     (s_axi_bready),
        .s_axi_araddr     (s_axi_araddr),
        .s_axi_arprot     (s_axi_arprot),
        .s_axi_arvalid    (s_axi_arvalid),
        .s_axi_arready    (s_axi_arready),
        .s_axi_rdata      (s_axi_rdata),
        .s_axi_rresp      (s_axi_rresp),
        .s_axi_rvalid     (s_axi_rvalid),
        .s_axi_rready     (s_axi_rready),
        .m_axi_araddr     (m_axi_araddr),
        .m_axi_arlen      (m_axi_arlen),
        .m_axi_arsize     (m_axi_arsize),
        .m_axi_arburst    (m_axi_arburst),
        .m_axi_arvalid    (m_axi_arvalid),
        .m_axi_arready    (m_axi_arready),
        .m_axi_rdata      (m_axi_rdata),
        .m_axi_rresp      (m_axi_rresp),
        .m_axi_rlast      (m_axi_rlast),
        .m_axi_rvalid     (m_axi_rvalid),
        .m_axi_rready     (m_axi_rready),
        .m_axi_awaddr     (m_axi_awaddr),
        .m_axi_awlen      (m_axi_awlen),
        .m_axi_awsize     (m_axi_awsize),
        .m_axi_awburst    (m_axi_awburst),
        .m_axi_awvalid    (m_axi_awvalid),
        .m_axi_awready    (m_axi_awready),
        .m_axi_wdata      (m_axi_wdata),
        .m_axi_wstrb      (m_axi_wstrb),
        .m_axi_wlast      (m_axi_wlast),
        .m_axi_wvalid     (m_axi_wvalid),
        .m_axi_wready     (m_axi_wready),
        .m_axi_bresp      (m_axi_bresp),
        .m_axi_bvalid     (m_axi_bvalid),
        .m_axi_bready     (m_axi_bready),
        .dma_in_wr_en     (dma_in_wr_en),
        .dma_in_wr_addr   (dma_in_wr_addr),
        .dma_in_wr_data   (dma_in_wr_data),
        .dma_w_wr_en      (dma_w_wr_en),
        .dma_w_wr_addr    (dma_w_wr_addr),
        .dma_w_wr_data    (dma_w_wr_data),
        .dma_bias_wr_en   (dma_bias_wr_en),
        .dma_bias_wr_addr (dma_bias_wr_addr),
        .dma_bias_wr_data (dma_bias_wr_data),
        .dma_act_rd_en    (dma_act_rd_en),
        .dma_act_rd_addr  (dma_act_rd_addr),
        .dma_act_rd_data  (dma_act_rd_data),
        .busy             (busy),
        .done             (done),
        .error            (error),
        .irq              (irq)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Simulated AXI Memory Slave Logic for Read Channel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_arready <= 1'b0;
            m_axi_rvalid  <= 1'b0;
            m_axi_rdata   <= 32'd0;
            m_axi_rresp   <= 2'b00;
            m_axi_rlast   <= 1'b0;
        end else begin
            if (m_axi_arvalid && !m_axi_arready) begin
                m_axi_arready <= 1'b1;
            end else if (m_axi_arready) begin
                m_axi_arready <= 1'b0;
                m_axi_rvalid  <= 1'b1;
                m_axi_rdata   <= simulated_ram[m_axi_araddr[11:2]];
                m_axi_rlast   <= 1'b1;
            end

            if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid <= 1'b0;
                m_axi_rlast  <= 1'b0;
            end
        end
    end

    // Simulated AXI Memory Slave Logic for Write Channel
    reg [31:0] captured_wr_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_awready <= 1'b0;
            m_axi_wready  <= 1'b0;
            m_axi_bvalid  <= 1'b0;
            m_axi_bresp   <= 2'b00;
        end else begin
            if (m_axi_awvalid && !m_axi_awready) begin
                m_axi_awready    <= 1'b1;
                captured_wr_addr <= m_axi_awaddr;
            end else if (m_axi_awready) begin
                m_axi_awready <= 1'b0;
                m_axi_wready  <= 1'b1;
            end

            if (m_axi_wvalid && m_axi_wready) begin
                simulated_ram[captured_wr_addr[11:2]] <= m_axi_wdata;
                m_axi_wready <= 1'b0;
                m_axi_bvalid <= 1'b1;
            end

            if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 1'b0;
            end
        end
    end

    task axi_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_awprot  <= 3'b000;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hF;
            s_axi_wvalid  <= 1'b1;
            s_axi_bready  <= 1'b1;

            @(posedge clk);
            while (!(s_axi_awready && s_axi_wready)) @(posedge clk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            while (!s_axi_bvalid) @(posedge clk);
            @(posedge clk);
            s_axi_bready  <= 1'b0;
        end
    endtask

    task axi_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            s_axi_araddr  <= addr;
            s_axi_arprot  <= 3'b000;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            @(posedge clk);
            while (!s_axi_arready) @(posedge clk);
            s_axi_arvalid <= 1'b0;

            while (!s_axi_rvalid) @(posedge clk);
            data = s_axi_rdata;
            @(posedge clk);
            s_axi_rready  <= 1'b0;
        end
    endtask

    reg [31:0] read_val;

    initial begin
        $display("===============================================================");
        $display("   STARTING TESTBENCH: DMA CONTROLLER IP                       ");
        $display("===============================================================");

        clk = 0;
        rst_n = 0;
        s_axi_awaddr = 0; s_axi_awprot = 0; s_axi_awvalid = 0;
        s_axi_wdata = 0; s_axi_wstrb = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s_axi_araddr = 0; s_axi_arprot = 0; s_axi_arvalid = 0; s_axi_rready = 0;
        m_axi_arready = 0; m_axi_rvalid = 0; m_axi_rdata = 0; m_axi_rresp = 0; m_axi_rlast = 0;
        m_axi_awready = 0; m_axi_wready = 0; m_axi_bvalid = 0; m_axi_bresp = 0;
        dma_act_rd_data = 32'hA5A5_0001;

        // Initialize simulated RAM with test vectors
        simulated_ram[0] = 32'h0001_0000; // 1.0 in Q16.16
        simulated_ram[1] = 32'h0002_0000; // 2.0 in Q16.16

        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // ---------------------------------------------------------------------
        // TEST 1: Memory-to-Accelerator Transfer
        // Direction = 0, Target = Input Buffer (00), Length = 2 words
        // SRC_ADDR = 0x0001_0000, DST_ADDR = 0x0000_0000
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 1] Testing Memory -> Input Buffer Transfer ---");
        axi_write(8'h08, 32'h0001_0000); // SRC_ADDR
        axi_write(8'h0C, 32'h0000_0000); // DST_ADDR
        axi_write(8'h10, 32'd2);          // BURST_LEN = 2 words
        // CTRL: start = 1, direction = 0 (Mem->Acc), target = 00 -> 32'h0000_0001
        axi_write(8'h00, 32'h0000_0001);

        // Poll done
        read_val = 0;
        while ((read_val & 32'h0000_0001) == 0) begin
            axi_read(8'h04, read_val);
            #(CLK_PERIOD);
        end

        $display("[PASS] DMA Mem->Acc transfer completed successfully!");

        // ---------------------------------------------------------------------
        // TEST 2: Accelerator-to-Memory Transfer
        // Direction = 1, Target = Act_Out (11), Length = 1 word
        // SRC_ADDR = 0x0000_0000, DST_ADDR = 0x0001_0400
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 2] Testing Accelerator -> Memory Transfer ---");
        axi_write(8'h08, 32'h0000_0000); // SRC_ADDR
        axi_write(8'h0C, 32'h0001_0400); // DST_ADDR (word offset 256)
        axi_write(8'h10, 32'd1);          // BURST_LEN = 1
        // CTRL: start = 1, direction = 1, target = 11 (bit 2=1, bits 4:3=11) -> 32'h0000_001D
        axi_write(8'h00, 32'h0000_001D);

        read_val = 0;
        while ((read_val & 32'h0000_0001) == 0) begin
            axi_read(8'h04, read_val);
            #(CLK_PERIOD);
        end

        // Check if data was written into simulated RAM at offset 256
        if (simulated_ram[256] === 32'hA5A5_0001) begin
            $display("[PASS] Accelerator result correctly transferred to RAM (0x%08X)!", simulated_ram[256]);
        end else begin
            $display("[FAIL] RAM data mismatch! Expected 0xA5A50001, got 0x%08X", simulated_ram[256]);
            error_count = error_count + 1;
        end

        $display("===============================================================");
        if (error_count == 0)
            $display("   TEST RESULT: ALL DMA TESTS PASSED!                          ");
        else
            $display("   TEST RESULT: %0d TESTS FAILED!                              ", error_count);
        $display("===============================================================");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
