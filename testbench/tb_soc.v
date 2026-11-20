// ============================================================================
// Testbench:   tb_soc
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Full End-to-End System-on-Chip Verification Testbench.
//              Verifies the complete inference acceleration flow:
//                1. Data Memory holds Input Vector X, Weight Matrix W, Bias B.
//                2. DMA stages X, W, and B from Data Memory to Matrix Multiplier.
//                3. Matrix Multiplier computes raw linear layer: Y = W * X + B.
//                4. Streamed results are processed element-wise by Activation Unit (ReLU).
//                5. DMA writes final activated output vector back to Data Memory.
//                6. Compares actual Data Memory contents against golden values.
// ============================================================================

`timescale 1ns / 1ps

module tb_soc;

    localparam CLK_PERIOD = 10;
    reg clk;
    reg rst_n;

    // External Top Pins
    wire       uart_tx;
    reg        uart_rx;
    wire [7:0] gpio_out;
    reg  [7:0] gpio_in;
    wire       acc_busy;
    wire       acc_done;

    // Fixed-Point Q16.16 Constants
    localparam signed [31:0] Q_ZERO      = 32'h0000_0000; //  0.0
    localparam signed [31:0] Q_ONE_HALF  = 32'h0000_8000; //  0.5
    localparam signed [31:0] Q_ONE       = 32'h0001_0000; //  1.0
    localparam signed [31:0] Q_ONE_PT_5  = 32'h0001_8000; //  1.5
    localparam signed [31:0] Q_TWO       = 32'h0002_0000; //  2.0
    localparam signed [31:0] Q_THREE     = 32'h0003_0000; //  3.0
    localparam signed [31:0] Q_SIX       = 32'h0006_0000; //  6.0
    localparam signed [31:0] Q_QUARTER   = 32'h0000_4000; //  0.25
    localparam signed [31:0] Q_NEG_1_PT5 = -Q_ONE_PT_5;   // -1.5
    localparam signed [31:0] Q_NEG_HALF  = -Q_ONE_HALF;   // -0.5

    // Expected Golden Inference Outputs
    // Y_raw[0] = 2.0*1.0 + (-1.5)*2.0 + 0.25 = -0.75 -> ReLU(-0.75) = 0.0
    // Y_raw[1] = 0.5*1.0 +  3.0 *2.0 + (-0.5) = +6.0  -> ReLU(+6.0)  = +6.0
    localparam signed [31:0] GOLDEN_Y0 = Q_ZERO;
    localparam signed [31:0] GOLDEN_Y1 = Q_SIX;

    integer error_count = 0;

    // Instantiate SoC Top
    soc_top u_soc (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .gpio_out (gpio_out),
        .gpio_in  (gpio_in),
        .acc_busy (acc_busy),
        .acc_done (acc_done)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    // Helper task to directly access Data Memory for test verification
    reg signed [31:0] readback_y0, readback_y1;

    initial begin
        $display("===============================================================");
        $display("   STARTING TESTBENCH: FULL SoC NEURAL NETWORK ACCELERATION   ");
        $display("===============================================================");

        clk     = 0;
        rst_n   = 0;
        uart_rx = 1;
        gpio_in = 8'hAA;

        // Reset Pulse
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 5);

        $display("[INFO] Initializing Data Memory with NN Weights and Inputs...");

        // ---------------------------------------------------------------------
        // Step 1: Preload Data Memory (0x0001_0000)
        // Offset 0x00: Input Vector X [1.0, 2.0]
        // Offset 0x20: Weight Matrix W [[2.0, -1.5], [0.5, 3.0]]
        // Offset 0x40: Bias Vector B [0.25, -0.5]
        // ---------------------------------------------------------------------
        u_soc.u_dmem.mem[0] = Q_ONE;       // X[0] = 1.0
        u_soc.u_dmem.mem[1] = Q_TWO;       // X[1] = 2.0

        u_soc.u_dmem.mem[8]  = Q_TWO;       // W[0][0] = 2.0
        u_soc.u_dmem.mem[9]  = Q_NEG_1_PT5; // W[0][1] = -1.5
        u_soc.u_dmem.mem[10] = Q_ONE_HALF;  // W[1][0] = 0.5
        u_soc.u_dmem.mem[11] = Q_THREE;     // W[1][1] = 3.0

        u_soc.u_dmem.mem[16] = Q_QUARTER;   // B[0] = 0.25
        u_soc.u_dmem.mem[17] = Q_NEG_HALF;  // B[1] = -0.5

        $display("[INFO] Data Memory Staged successfully.");

        // ---------------------------------------------------------------------
        // Step 2: DMA transfers from Data Memory to Matrix Multiplier
        // ---------------------------------------------------------------------
        $display("[INFO] Staging Input Vector X via DMA...");
        u_soc.u_dma_controller.u_regs.src_addr  = 32'h0001_0000;
        u_soc.u_dma_controller.u_regs.dst_addr  = 32'h0000_0000;
        u_soc.u_dma_controller.u_regs.burst_len = 16'd2;
        u_soc.u_dma_controller.u_regs.direction = 1'b0;      // Mem -> Acc
        u_soc.u_dma_controller.u_regs.acc_target= 2'b00;     // Input Buffer
        @(posedge clk);
        u_soc.u_dma_controller.u_regs.ctrl_start = 1'b1;
        @(posedge clk);
        u_soc.u_dma_controller.u_regs.ctrl_start = 1'b0;

        while (!u_soc.u_dma_controller.done) @(posedge clk);
        $display("[INFO] Input Vector X staged to Matrix Multiplier Input Buffer.");

        $display("[INFO] Staging Weight Matrix W via DMA...");
        u_soc.u_dma_controller.u_regs.src_addr  = 32'h0001_0020;
        u_soc.u_dma_controller.u_regs.dst_addr  = 32'h0000_0000;
        u_soc.u_dma_controller.u_regs.burst_len = 16'd4;
        u_soc.u_dma_controller.u_regs.direction = 1'b0;
        u_soc.u_dma_controller.u_regs.acc_target= 2'b01;     // Weight Buffer
        @(posedge clk);
        u_soc.u_dma_controller.u_regs.ctrl_start = 1'b1;
        @(posedge clk);
        u_soc.u_dma_controller.u_regs.ctrl_start = 1'b0;

        while (!u_soc.u_dma_controller.done) @(posedge clk);
        $display("[INFO] Weight Matrix W staged to Matrix Multiplier Weight Buffer.");

        $display("[INFO] Staging Bias Vector B via DMA...");
        u_soc.u_dma_controller.u_regs.src_addr  = 32'h0001_0040;
        u_soc.u_dma_controller.u_regs.dst_addr  = 32'h0000_0000;
        u_soc.u_dma_controller.u_regs.burst_len = 16'd2;
        u_soc.u_dma_controller.u_regs.direction = 1'b0;
        u_soc.u_dma_controller.u_regs.acc_target= 2'b10;     // Bias Buffer
        @(posedge clk);
        u_soc.u_dma_controller.u_regs.ctrl_start = 1'b1;
        @(posedge clk);
        u_soc.u_dma_controller.u_regs.ctrl_start = 1'b0;

        while (!u_soc.u_dma_controller.done) @(posedge clk);
        $display("[INFO] Bias Vector B staged to Matrix Multiplier Bias Buffer.");

        // ---------------------------------------------------------------------
        // Step 3: Configure Accelerators & Start Compute Pipeline
        // ---------------------------------------------------------------------
        $display("[INFO] Configuring Matrix Multiplier and Activation Unit...");
        u_soc.u_matrix_multiplier.u_axi_regs.dim_m = 8'd2;
        u_soc.u_matrix_multiplier.u_axi_regs.dim_k = 8'd2;
        u_soc.u_activation_unit.u_axi_regs.vec_len  = 16'd2;
        u_soc.u_activation_unit.u_axi_regs.func_sel = 2'b00; // ReLU

        // Arm Activation Unit
        @(posedge clk);
        u_soc.u_activation_unit.u_axi_regs.ctrl_start = 1'b1;
        @(posedge clk);
        u_soc.u_activation_unit.u_axi_regs.ctrl_start = 1'b0;

        // Trigger Matrix Multiplier
        @(posedge clk);
        u_soc.u_matrix_multiplier.u_axi_regs.ctrl_start = 1'b1;
        @(posedge clk);
        u_soc.u_matrix_multiplier.u_axi_regs.ctrl_start = 1'b0;

        // Wait for compute pipeline completion
        while (!u_soc.u_activation_unit.done) @(posedge clk);
        $display("[INFO] Matrix Multiplication and Activation Complete!");

        // ---------------------------------------------------------------------
        // Step 4: Write Activated Results back to Data Memory via DMA
        // ---------------------------------------------------------------------
        $display("[INFO] Writing activated results back to Data Memory (0x0001_0400)...");
        u_soc.u_dma_controller.u_regs.src_addr  = 32'h0000_0000;
        u_soc.u_dma_controller.u_regs.dst_addr  = 32'h0001_0400; // Word offset 256
        u_soc.u_dma_controller.u_regs.burst_len = 16'd2;
        u_soc.u_dma_controller.u_regs.direction = 1'b1;      // Acc -> Mem
        u_soc.u_dma_controller.u_regs.acc_target= 2'b11;     // Act Out
        @(posedge clk);
        u_soc.u_dma_controller.u_regs.ctrl_start = 1'b1;
        @(posedge clk);
        u_soc.u_dma_controller.u_regs.ctrl_start = 1'b0;

        while (!u_soc.u_dma_controller.done) @(posedge clk);
        $display("[INFO] DMA write-back to Data Memory finished!");

        // ---------------------------------------------------------------------
        // Step 5: Validate Final Results in Data Memory
        // ---------------------------------------------------------------------
        readback_y0 = u_soc.u_dmem.mem[256];
        readback_y1 = u_soc.u_dmem.mem[257];

        $display("\n======================= VERIFICATION RESULTS =======================");
        $display(" Y[0] Raw: -0.75 | After ReLU: %f (0x%08X) | Expected: %f",
                 $itor(readback_y0)/65536.0, readback_y0, $itor(GOLDEN_Y0)/65536.0);
        $display(" Y[1] Raw: +6.00 | After ReLU: %f (0x%08X) | Expected: %f",
                 $itor(readback_y1)/65536.0, readback_y1, $itor(GOLDEN_Y1)/65536.0);

        if (readback_y0 === GOLDEN_Y0) begin
            $display("[PASS] Neuron 0 output matches Golden Reference!");
        end else begin
            $display("[FAIL] Neuron 0 mismatch! Expected 0x%08X, got 0x%08X", GOLDEN_Y0, readback_y0);
            error_count = error_count + 1;
        end

        if (readback_y1 === GOLDEN_Y1) begin
            $display("[PASS] Neuron 1 output matches Golden Reference!");
        end else begin
            $display("[FAIL] Neuron 1 mismatch! Expected 0x%08X, got 0x%08X", GOLDEN_Y1, readback_y1);
            error_count = error_count + 1;
        end

        $display("====================================================================");
        if (error_count == 0) begin
            $display("   FULL SoC NEURAL NETWORK INFERENCE ACCELERATION: PASSED!          ");
        end else begin
            $display("   FULL SoC INFERENCE ACCELERATION: %0d TESTS FAILED!               ", error_count);
        end
        $display("====================================================================");

        #(CLK_PERIOD * 20);
        $finish;
    end

endmodule
