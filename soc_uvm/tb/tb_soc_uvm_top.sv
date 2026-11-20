// SPDX-License-Identifier: Apache-2.0
// Top-Level SoC UVM Testbench: tb_soc_uvm_top.sv
// Target Simulator: Synopsys VCS
// Project: RISC-V Based SoC for Lightweight NN Inference Acceleration

`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

`include "common_defines.vh"
`include "el2_pdef.vh"

import uart_vip_pkg::*;
import gpio_vip_pkg::*;
import timer_vip_pkg::*;
import matrix_multiplier_vip_pkg::*;
import activation_vip_pkg::*;
import dma_vip_pkg::*;

`include "soc_config.sv"
`include "soc_virtual_sequencer.sv"
`include "soc_virtual_sequence.sv"
`include "soc_env.sv"
`include "soc_test.sv"
`include "matrix_mult_test.sv"
`include "activation_test.sv"
`include "dma_test.sv"
`include "uart_connectivity_test.sv"
`include "timer_test.sv"
`include "gpio_test.sv"

module tb_soc_uvm_top;
    import el2_pkg::*;

    // Clock and Reset Generation
    localparam time CLK_PERIOD = 20ns; // 50 MHz
    logic clk;
    logic rst_n;

    // External Top Pins
    logic        uart_tx;
    logic        uart_rx;
    wire  [15:0] gpio;
    logic        acc_busy;
    logic        acc_done;

    // Clock Generator
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // VIP Interfaces
    uart_vip_if              uart_vif();
    gpio_vip_if              gpio_vif();
    timer_vip_if             timer_vif();
    matrix_multiplier_vip_if mm_vif();
    activation_vip_if        act_vif();
    dma_vip_if               dma_vif();

    // Assign Clock & Reset to VIPs
    assign uart_vif.clk   = clk;
    assign uart_vif.rst_n = rst_n;
    assign gpio_vif.clk   = clk;
    assign gpio_vif.rst_n = rst_n;
    assign timer_vif.clk  = clk;
    assign timer_vif.rst_n= rst_n;
    assign mm_vif.clk     = clk;
    assign mm_vif.rst_n   = rst_n;
    assign act_vif.clk    = clk;
    assign act_vif.rst_n  = rst_n;
    assign dma_vif.clk    = clk;
    assign dma_vif.rst_n  = rst_n;

    // Connect top-level pins to VIP interfaces
    assign uart_vif.uart_tx = uart_tx;
    assign uart_rx          = uart_vif.uart_rx;
    assign gpio             = gpio_vif.drv_en ? gpio_vif.drv_val : 16'h0000;
    assign gpio_vif.gpio_in = gpio;

    // Probe accelerator status signals
    assign mm_vif.busy  = acc_busy;
    assign mm_vif.done  = acc_done;
    assign act_vif.busy = acc_busy;
    assign act_vif.done = acc_done;

    // Instantiate Top-Level SoC
    soc_top #(
        .NGPIO      (16),
        .IMEM_DEPTH (8192),
        .DMEM_DEPTH (8192)
    ) u_soc_top (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .gpio     (gpio),
        .acc_busy (acc_busy),
        .acc_done (acc_done)
    );

    // Initial Reset Sequence & UVM Launch
    initial begin
        rst_n = 1'b0;

        // Register VIP interfaces in UVM DB
        uvm_config_db#(virtual uart_vip_if)::set(null, "*uart_agnt*", "vif", uart_vif);
        uvm_config_db#(virtual gpio_vip_if)::set(null, "*gpio_agnt*", "vif", gpio_vif);
        uvm_config_db#(virtual timer_vip_if)::set(null, "*timer_agnt*", "vif", timer_vif);
        uvm_config_db#(virtual matrix_multiplier_vip_if)::set(null, "*mm_agnt*", "vif", mm_vif);
        uvm_config_db#(virtual activation_vip_if)::set(null, "*act_agnt*", "vif", act_vif);
        uvm_config_db#(virtual dma_vip_if)::set(null, "*dma_agnt*", "vif", dma_vif);

        // Preload firmware memory image
        #1;
        if ($test$plusargs("LOAD_HEX")) begin
            $display("[UVM_TOP] Loading firmware from main.hex");
            $readmemh("main.hex", u_soc_top.u_imem.mem);
        end

        // Release reset
        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
        $display("[UVM_TOP] System reset released. Starting UVM test phases...");

        // Launch UVM
        run_test();
    end

    // Waveform Dump Setup (VCS DVE / Verdi FSDB)
    initial begin
        if ($test$plusargs("DUMP_FSDB")) begin
            $display("[UVM_TOP] Dumping FSDB waveform to sim_soc_uvm.fsdb");
            $fsdbDumpfile("sim_soc_uvm.fsdb");
            $fsdbDumpvars(0, tb_soc_uvm_top);
        end else if ($test$plusargs("DUMP_VCD")) begin
            $display("[UVM_TOP] Dumping VCD waveform to sim_soc_uvm.vcd");
            $dumpfile("sim_soc_uvm.vcd");
            $dumpvars(0, tb_soc_uvm_top);
        end
    end

endmodule
