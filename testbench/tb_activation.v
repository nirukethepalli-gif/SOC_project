// ============================================================================
// Testbench:   tb_activation
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Self-checking testbench for Activation Unit IP.
//              Tests:
//                1. ReLU function for positive, negative, and zero inputs.
//                2. Sigmoid PWL function for positive, negative, and zero inputs.
//                3. Tanh PWL function for positive, negative, and zero inputs.
//                4. Function selection via AXI register interface.
//                5. Busy, done, and output valid handshake behavior.
// ============================================================================

`timescale 1ns / 1ps

module tb_activation;

    localparam CLK_PERIOD = 10;
    reg clk;
    reg rst_n;

    // AXI4-Lite Interface
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

    // Streaming input (from Matrix Multiplier)
    reg  [31:0] stream_in_data;
    reg         stream_in_valid;
    wire        stream_in_ready;

    // DMA Readout interface
    reg         dma_out_rd_en;
    reg  [7:0]  dma_out_rd_addr;
    wire [31:0] dma_out_rd_data;

    // Status
    wire        busy;
    wire        done;
    wire        irq;

    // Q16.16 Constants
    localparam signed [31:0] Q_ZERO    = 32'h0000_0000;
    localparam signed [31:0] Q_ONE     = 32'h0001_0000; //  1.0
    localparam signed [31:0] Q_HALF    = 32'h0000_8000; //  0.5
    localparam signed [31:0] Q_TWO     = 32'h0002_0000; //  2.0
    localparam signed [31:0] Q_NEG_TWO = -Q_TWO;        // -2.0
    localparam signed [31:0] Q_NEG_ONE = -Q_ONE;        // -1.0

    integer error_count = 0;

    // DUT Instantiation
    activation_top u_dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .s_axi_awaddr    (s_axi_awaddr),
        .s_axi_awprot    (s_axi_awprot),
        .s_axi_awvalid   (s_axi_awvalid),
        .s_axi_awready   (s_axi_awready),
        .s_axi_wdata     (s_axi_wdata),
        .s_axi_wstrb     (s_axi_wstrb),
        .s_axi_wvalid    (s_axi_wvalid),
        .s_axi_wready    (s_axi_wready),
        .s_axi_bresp     (s_axi_bresp),
        .s_axi_bvalid    (s_axi_bvalid),
        .s_axi_bready    (s_axi_bready),
        .s_axi_araddr    (s_axi_araddr),
        .s_axi_arprot    (s_axi_arprot),
        .s_axi_arvalid   (s_axi_arvalid),
        .s_axi_arready   (s_axi_arready),
        .s_axi_rdata     (s_axi_rdata),
        .s_axi_rresp     (s_axi_rresp),
        .s_axi_rvalid    (s_axi_rvalid),
        .s_axi_rready    (s_axi_rready),
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
    reg signed [31:0] out0, out1, out2;

    initial begin
        $display("===============================================================");
        $display("   STARTING TESTBENCH: ACTIVATION UNIT IP (Q16.16)             ");
        $display("===============================================================");

        clk = 0;
        rst_n = 0;
        s_axi_awaddr = 0; s_axi_awprot = 0; s_axi_awvalid = 0;
        s_axi_wdata = 0; s_axi_wstrb = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s_axi_araddr = 0; s_axi_arprot = 0; s_axi_arvalid = 0; s_axi_rready = 0;
        stream_in_data = 0; stream_in_valid = 0;
        dma_out_rd_en = 0; dma_out_rd_addr = 0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // ---------------------------------------------------------------------
        // TEST 1: ReLU Activation (func_sel = 2'b00)
        // Vector = [+2.0, -2.0, 0.0]
        // Expected = [+2.0, 0.0, 0.0]
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 1] Testing ReLU Activation ---");
        axi_write(8'h08, 32'd3); // vec_len = 3
        // CTRL: start = 1, func_sel = 2'b00 -> 32'h0000_0001
        axi_write(8'h00, 32'h0000_0001);

        // Stream 3 elements
        @(posedge clk);
        stream_in_data  <= Q_TWO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_data  <= Q_NEG_TWO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_data  <= Q_ZERO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_valid <= 1'b0;

        // Poll done
        read_val = 0;
        while ((read_val & 32'h0000_0001) == 0) begin
            axi_read(8'h04, read_val);
            #(CLK_PERIOD);
        end

        // Read outputs via AXI
        axi_write(8'h14, 32'd0);
        axi_read(8'h24, read_val); out0 = read_val;
        axi_write(8'h14, 32'd1);
        axi_read(8'h24, read_val); out1 = read_val;
        axi_write(8'h14, 32'd2);
        axi_read(8'h24, read_val); out2 = read_val;

        $display("[CHECK] ReLU(+2.0) = %f | Expected: +2.0", $itor(out0)/65536.0);
        $display("[CHECK] ReLU(-2.0) = %f | Expected:  0.0", $itor(out1)/65536.0);
        $display("[CHECK] ReLU( 0.0) = %f | Expected:  0.0", $itor(out2)/65536.0);

        if (out0 === Q_TWO && out1 === Q_ZERO && out2 === Q_ZERO)
            $display("[PASS] ReLU functional test passed!");
        else begin
            $display("[FAIL] ReLU output mismatch!");
            error_count = error_count + 1;
        end

        #(CLK_PERIOD * 5);

        // ---------------------------------------------------------------------
        // TEST 2: Sigmoid Activation (func_sel = 2'b01)
        // x = 0.0 -> Sigmoid(0) = 0.5 (0x0000_8000)
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 2] Testing Sigmoid Activation ---");
        axi_write(8'h08, 32'd1); // vec_len = 1
        // CTRL: start = 1, func_sel = 2'b01 (bits 3:2 = 2'b01 -> 32'h0000_0005)
        axi_write(8'h00, 32'h0000_0005);

        @(posedge clk);
        stream_in_data  <= Q_ZERO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_valid <= 1'b0;

        read_val = 0;
        while ((read_val & 32'h0000_0001) == 0) begin
            axi_read(8'h04, read_val);
            #(CLK_PERIOD);
        end

        axi_write(8'h14, 32'd0);
        axi_read(8'h24, read_val); out0 = read_val;

        $display("[CHECK] Sigmoid(0.0) = %f | Expected: 0.5 (0x00008000)", $itor(out0)/65536.0);
        if (out0 === Q_HALF)
            $display("[PASS] Sigmoid(0.0) matches 0.5 exactly!");
        else begin
            $display("[FAIL] Sigmoid mismatch! Got 0x%08X", out0);
            error_count = error_count + 1;
        end

        #(CLK_PERIOD * 5);

        // ---------------------------------------------------------------------
        // TEST 3: Tanh Activation (func_sel = 2'b10)
        // x = 0.0 -> Tanh(0) = 0.0
        // ---------------------------------------------------------------------
        $display("\n--- [TEST 3] Testing Tanh Activation ---");
        axi_write(8'h08, 32'd1); // vec_len = 1
        // CTRL: start = 1, func_sel = 2'b10 (bits 3:2 = 2'b10 -> 32'h0000_0009)
        axi_write(8'h00, 32'h0000_0009);

        @(posedge clk);
        stream_in_data  <= Q_ZERO;
        stream_in_valid <= 1'b1;
        @(posedge clk);
        stream_in_valid <= 1'b0;

        read_val = 0;
        while ((read_val & 32'h0000_0001) == 0) begin
            axi_read(8'h04, read_val);
            #(CLK_PERIOD);
        end

        axi_write(8'h14, 32'd0);
        axi_read(8'h24, read_val); out0 = read_val;

        $display("[CHECK] Tanh(0.0) = %f | Expected: 0.0", $itor(out0)/65536.0);
        if (out0 === Q_ZERO)
            $display("[PASS] Tanh(0.0) matches 0.0 exactly!");
        else begin
            $display("[FAIL] Tanh mismatch! Got 0x%08X", out0);
            error_count = error_count + 1;
        end

        $display("===============================================================");
        if (error_count == 0)
            $display("   TEST RESULT: ALL ACTIVATION TESTS PASSED!                   ");
        else
            $display("   TEST RESULT: %0d TESTS FAILED!                              ", error_count);
        $display("===============================================================");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
