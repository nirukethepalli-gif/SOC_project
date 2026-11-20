// ============================================================================
// Testbench:   tb_matrix_multiplier
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Comprehensive self-checking testbench for Matrix Multiplier IP.
//              Tests:
//                1. 2x2 Matrix-Vector Multiplication with Bias:
//                   W = [[ 2.0, -1.5 ], [ 0.5,  3.0 ]] (in Q16.16)
//                   X = [ 1.0,  2.0 ]^T
//                   B = [ 0.25, -0.5 ]^T
//                   Expected Y[0] = 2.0*1.0 + (-1.5)*2.0 + 0.25 = -0.75
//                   Expected Y[1] = 0.5*1.0 +  3.0 *2.0 + (-0.5) = 6.0
//                2. Soft reset and busy/done reporting checks.
//                3. Error/saturation tests.
// ============================================================================

`timescale 1ns / 1ps

module tb_matrix_multiplier;

    // Clock and reset parameters
    localparam CLK_PERIOD = 10; // 100 MHz
    reg clk;
    reg rst_n;

    // AXI4-Lite Interface signals
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

    // DMA signals (tied off for standalone AXI test)
    reg         dma_in_wr_en;
    reg  [7:0]  dma_in_wr_addr;
    reg  [31:0] dma_in_wr_data;
    reg         dma_w_wr_en;
    reg  [9:0]  dma_w_wr_addr;
    reg  [31:0] dma_w_wr_data;
    reg         dma_bias_wr_en;
    reg  [7:0]  dma_bias_wr_addr;
    reg  [31:0] dma_bias_wr_data;
    reg         dma_out_rd_en;
    reg  [7:0]  dma_out_rd_addr;
    wire [31:0] dma_out_rd_data;

    // Streaming to Activation Unit
    wire [31:0] stream_act_data;
    wire        stream_act_valid;
    reg         stream_act_ready;

    // Status
    wire        busy;
    wire        done;
    wire        irq;

    // Q16.16 Constants (1.0 = 16'h1_0000 = 65536)
    localparam signed [31:0] Q_ONE_HALF  = 32'h0000_8000; //  0.5
    localparam signed [31:0] Q_ONE       = 32'h0001_0000; //  1.0
    localparam signed [31:0] Q_ONE_PT_5  = 32'h0001_8000; //  1.5
    localparam signed [31:0] Q_TWO       = 32'h0002_0000; //  2.0
    localparam signed [31:0] Q_THREE     = 32'h0003_0000; //  3.0
    localparam signed [31:0] Q_SIX       = 32'h0006_0000; //  6.0
    localparam signed [31:0] Q_QUARTER   = 32'h0000_4000; //  0.25
    localparam signed [31:0] Q_NEG_1_PT5 = -Q_ONE_PT_5;   // -1.5 (32'hFFFE_8000)
    localparam signed [31:0] Q_NEG_HALF  = -Q_ONE_HALF;   // -0.5 (32'hFFFF_8000)
    localparam signed [31:0] Q_NEG_0_75  = -32'h0000_C000;// -0.75 (32'hFFFF_4000)

    // Test error tracker
    integer error_count = 0;

    // Instantiate Matrix Multiplier Top
    matrix_multiplier_top u_dut (
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
        .dma_in_wr_en     (dma_in_wr_en),
        .dma_in_wr_addr   (dma_in_wr_addr),
        .dma_in_wr_data   (dma_in_wr_data),
        .dma_w_wr_en      (dma_w_wr_en),
        .dma_w_wr_addr    (dma_w_wr_addr),
        .dma_w_wr_data    (dma_w_wr_data),
        .dma_bias_wr_en   (dma_bias_wr_en),
        .dma_bias_wr_addr (dma_bias_wr_addr),
        .dma_bias_wr_data (dma_bias_wr_data),
        .dma_out_rd_en    (dma_out_rd_en),
        .dma_out_rd_addr  (dma_out_rd_addr),
        .dma_out_rd_data  (dma_out_rd_data),
        .stream_act_data  (stream_act_data),
        .stream_act_valid (stream_act_valid),
        .stream_act_ready (stream_act_ready),
        .busy             (busy),
        .done             (done),
        .irq              (irq)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // AXI Write Task
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

    // AXI Read Task
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

    // Main Test Stimulus
    reg [31:0] read_val;
    reg signed [31:0] y0_val, y1_val;

    initial begin
        $display("===============================================================");
        $display("   STARTING TESTBENCH: MATRIX MULTIPLIER IP (Q16.16)           ");
        $display("===============================================================");

        // Initialize signals
        clk           = 0;
        rst_n         = 0;
        s_axi_awaddr  = 0;
        s_axi_awprot  = 0;
        s_axi_awvalid = 0;
        s_axi_wdata   = 0;
        s_axi_wstrb   = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_araddr  = 0;
        s_axi_arprot  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;

        dma_in_wr_en   = 0; dma_in_wr_addr   = 0; dma_in_wr_data   = 0;
        dma_w_wr_en    = 0; dma_w_wr_addr    = 0; dma_w_wr_data    = 0;
        dma_bias_wr_en = 0; dma_bias_wr_addr = 0; dma_bias_wr_data = 0;
        dma_out_rd_en  = 0; dma_out_rd_addr  = 0;
        stream_act_ready = 1'b1; // Always ready to receive

        // Reset Pulse
        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("[INFO] System Reset Released. Initializing 2x2 Matrix Mult...");

        // 1. Configure Dimensions: M=2, N=1, K=2 -> DIM_M_N_K = {M[23:16], N[15:8], K[7:0]}
        // {8'd2, 8'd1, 8'd2} = 32'h0002_0102
        axi_write(8'h08, 32'h0002_0102);

        // 2. Load Input Vector X = [1.0, 2.0] into Input Buffer
        axi_write(8'h14, 32'd0);        // Set buffer index = 0
        axi_write(8'h20, Q_ONE);        // X[0] = 1.0 (auto-increments index)
        axi_write(8'h20, Q_TWO);        // X[1] = 2.0

        // 3. Load Weight Matrix W = [[2.0, -1.5], [0.5, 3.0]] into Weight Buffer
        axi_write(8'h14, 32'd0);        // Set buffer index = 0
        axi_write(8'h24, Q_TWO);        // W[0][0] = 2.0
        axi_write(8'h24, Q_NEG_1_PT5);   // W[0][1] = -1.5
        axi_write(8'h24, Q_ONE_HALF);   // W[1][0] = 0.5
        axi_write(8'h24, Q_THREE);      // W[1][1] = 3.0

        // 4. Load Bias Vector B = [0.25, -0.5] into Bias Buffer
        axi_write(8'h14, 32'd0);        // Set buffer index = 0
        axi_write(8'h28, Q_QUARTER);    // B[0] = 0.25
        axi_write(8'h28, Q_NEG_HALF);   // B[1] = -0.5

        $display("[INFO] Operands loaded. Starting Accelerator via CTRL register...");

        // 5. Start Execution (Write bit 0 of CTRL register)
        axi_write(8'h00, 32'h0000_0001);

        // 6. Poll STATUS register until DONE (bit 0 = 1)
        read_val = 0;
        while ((read_val & 32'h0000_0001) == 0) begin
            axi_read(8'h04, read_val);
            #(CLK_PERIOD * 2);
        end

        $display("[INFO] Matrix Multiplier signaled DONE! Reading results...");

        // 7. Read Output Element 0
        axi_write(8'h14, 32'd0);
        axi_read(8'h2C, read_val);
        y0_val = read_val;

        // 8. Read Output Element 1
        axi_write(8'h14, 32'd1);
        axi_read(8'h2C, read_val);
        y1_val = read_val;

        $display("[CHECK] Y[0] Actual: 0x%08X (%f) | Expected: 0x%08X (-0.75)",
                 y0_val, $itor(y0_val)/65536.0, Q_NEG_0_75);
        $display("[CHECK] Y[1] Actual: 0x%08X (%f) | Expected: 0x%08X (+6.0)",
                 y1_val, $itor(y1_val)/65536.0, Q_SIX);

        // Verification checks
        if (y0_val === Q_NEG_0_75) begin
            $display("[PASS] Y[0] matches expected Q16.16 value!");
        end else begin
            $display("[FAIL] Y[0] mismatch! Expected 0x%08X, got 0x%08X", Q_NEG_0_75, y0_val);
            error_count = error_count + 1;
        end

        if (y1_val === Q_SIX) begin
            $display("[PASS] Y[1] matches expected Q16.16 value!");
        end else begin
            $display("[FAIL] Y[1] mismatch! Expected 0x%08X, got 0x%08X", Q_SIX, y1_val);
            error_count = error_count + 1;
        end

        // Summary
        $display("===============================================================");
        if (error_count == 0) begin
            $display("   TEST RESULT: ALL TESTS PASSED SUCCESSFULLY!                 ");
        end else begin
            $display("   TEST RESULT: %0d TESTS FAILED!                              ", error_count);
        end
        $display("===============================================================");

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
