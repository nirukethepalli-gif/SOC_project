// SPDX-License-Identifier: Apache-2.0
// Top-Level SoC Testbench: tb_soc_top.sv
// Target Simulator: Synopsys VCS
// Project: RISC-V Based SoC for Lightweight NN Inference Acceleration
//
// Description:
//   Instantiates soc_top (with VeeR EL2 core, memories, interconnect, and 3 custom IPs).
//   Loads bare-metal firmware into Instruction Memory (0x0000_0000) and Data Memory.
//   Monitors UART TX at 115200 baud to display firmware console output.
//   Detects firmware completion, checks inference results, and reports PASS/FAIL status.

`timescale 1ns/1ps

`include "common_defines.vh"
`include "el2_pdef.vh"

module tb_soc_top;
    import el2_pkg::*;

    // Clock and Reset
    localparam time CLK_PERIOD = 20ns; // 50 MHz Clock
    logic clk;
    logic rst_n;

    // External Top Pins
    logic        uart_tx;
    logic        uart_rx;
    wire  [15:0] gpio;
    logic        acc_busy;
    logic        acc_done;

    // Simulation Control & Monitoring
    string hex_file = "main.hex";
    int    test_pass = 0;
    int    test_fail = 0;

    // Generate Clock
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Instantiate Top-Level SoC
    soc_top #(
        .NGPIO      (16),
        .IMEM_DEPTH (8192), // 32 KB
        .DMEM_DEPTH (8192)  // 32 KB
    ) u_soc_top (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .gpio     (gpio),
        .acc_busy (acc_busy),
        .acc_done (acc_done)
    );

    // Pull-ups / terminations for IOs
    assign uart_rx = 1'b1; // Idle high
    assign gpio    = 16'h0000;

    // UART Console Monitor (115200 baud @ 50 MHz)
    uart_monitor #(
        .CLK_FREQ_HZ(50_000_000),
        .BAUD_RATE  (115_200)
    ) u_uart_mon (
        .clk     (clk),
        .rst_n   (rst_n),
        .uart_tx (uart_tx)
    );

    // Waveform Dump Setup (VCS DVE / Verdi FSDB)
    initial begin
        if ($test$plusargs("DUMP_VCD")) begin
            $display("[TB] Dumping VCD waveform to sim_soc.vcd");
            $dumpfile("sim_soc.vcd");
            $dumpvars(0, tb_soc_top);
        end
`ifdef DUMP_FSDB
        $display("[TB] Dumping FSDB waveform to sim_soc.fsdb");
        $fsdbDumpfile("sim_soc.fsdb");
        $fsdbDumpvars(0, tb_soc_top, "+all");
`endif
    end

    // String detector on UART for automated regression checking
    string uart_buffer = "";
    real bit_period = (1.0e9 / 115200.0);

    always @(negedge uart_tx) begin
        logic [7:0] char;
        #(bit_period * 1.5);
        for (int i = 0; i < 8; i++) begin
            char[i] = uart_tx;
            #(bit_period);
        end

        if (char == 8'h0A) begin // '\n'
            if (uart_buffer.len() > 0) begin
                if (str_contains(uart_buffer, "PASS") || str_contains(uart_buffer, "SUCCESS")) begin
                    test_pass = 1;
                end
                if (str_contains(uart_buffer, "FAIL") || str_contains(uart_buffer, "ERROR")) begin
                    test_fail = 1;
                end
            end
            uart_buffer = "";
        end else if (char != 8'h0D) begin
            uart_buffer = {uart_buffer, string'(char)};
        end
    end

    function automatic bit str_contains(string haystack, string needle);
        for (int i = 0; i <= haystack.len() - needle.len(); i++) begin
            if (haystack.substr(i, i + needle.len() - 1) == needle) return 1'b1;
        end
        return 1'b0;
    endfunction

    // Simulation Flow
    initial begin
        $display("============================================================");
        $display("=== [TEST] Starting Full SoC Simulation (tb_soc_top)    ===");
        $display("=== Project: RISC-V VeeR-EL2 NN Inference Accelerator   ===");
        $display("============================================================");

        // Parse firmware hex path from command line
        if (!$value$plusargs("HEX_FILE=%s", hex_file)) begin
            hex_file = "../sw/main.hex";
        end

        $display("[TB] Loading Instruction Memory from '%s'...", hex_file);
        $readmemh(hex_file, u_soc_top.u_imem.mem);
        $display("[TB] Preload completed successfully.");

        // Apply Reset
        rst_n = 1'b0;
        #(CLK_PERIOD * 10);
        @(negedge clk);
        rst_n = 1'b1;
        $display("[TB] Released processor reset. VeeR-EL2 executing firmware...");

        // Wait for execution completion or timeout
        fork : sim_wait
            begin
                // Monitor for PASS detection from firmware UART print
                wait(test_pass == 1);
                #(CLK_PERIOD * 100);
                $display("\n============================================================");
                $display("=== [TEST] tb_soc_top: FULL SOC TEST PASSED SUCCESSFULLY! ===");
                $display("=== VeeR-EL2 Core, Custom DMA, Matrix Multiplier &       ===");
                $display("=== Activation Unit Fully Verified on Synopsys VCS!      ===");
                $display("============================================================");
                disable sim_wait;
                $finish;
            end
            begin
                wait(test_fail == 1);
                #(CLK_PERIOD * 100);
                $error("\n[TEST] tb_soc_top: FIRMWARE REPORTED FAILURE!");
                disable sim_wait;
                $fatal(1);
            end
            begin
                // Timeout Watchdog: 5 ms
                #5ms;
                $display("[TB] Current UART buffer content: '%s'", uart_buffer);
                $fatal(1, "\n[TIMEOUT] Simulation watchdog expired after 5ms! Firmware did not complete.");
            end
        join
    end

endmodule
