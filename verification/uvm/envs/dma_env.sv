// SPDX-License-Identifier: Apache-2.0
// UVM Environment for Custom IP 3: DMA Controller
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package dma_env_pkg;
    import uvm_pkg::*;
    import axilite_pkg::*;
    import axi_mem_slave_pkg::*;
    `include "uvm_macros.svh"

    class dma_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(dma_scoreboard)

        int unsigned match_count = 0;
        int unsigned error_count = 0;

        function new(string name = "dma_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void check_transfer(string name, bit [31:0] expected, bit [31:0] actual);
            if (expected === actual) begin
                `uvm_info("SCB/DMA/PASS", $sformatf("[%s] Data matched: 0x%08X", name, actual), UVM_LOW)
                match_count++;
            end else begin
                `uvm_error("SCB/DMA/FAIL", $sformatf("[%s] Data mismatch! Exp=0x%08X Act=0x%08X", name, expected, actual))
                error_count++;
            end
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB/DMA/SUMMARY", $sformatf("============================================="), UVM_LOW)
            `uvm_info("SCB/DMA/SUMMARY", $sformatf("DMA Controller UVM Verification Summary:"), UVM_LOW)
            `uvm_info("SCB/DMA/SUMMARY", $sformatf("  Matches: %0d", match_count), UVM_LOW)
            `uvm_info("SCB/DMA/SUMMARY", $sformatf("  Errors:  %0d", error_count), UVM_LOW)
            `uvm_info("SCB/DMA/SUMMARY", $sformatf("============================================="), UVM_LOW)
            if (error_count > 0 || match_count == 0) begin
                `uvm_fatal("SCB/DMA/FAIL", "DMA Controller UVM Verification FAILED!")
            end
        endfunction
    endclass : dma_scoreboard

    class dma_env extends uvm_env;
        `uvm_component_utils(dma_env)

        axilite_agent        axil_agent;     // For CPU register programming
        axi_mem_slave_agent  mem_agent;      // For AXI4 memory responder
        dma_scoreboard       scoreboard;

        function new(string name = "dma_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            axil_agent = axilite_agent::type_id::create("axil_agent", this);
            mem_agent  = axi_mem_slave_agent::type_id::create("mem_agent", this);
            scoreboard = dma_scoreboard::type_id::create("scoreboard", this);
        endfunction
    endclass : dma_env

endpackage : dma_env_pkg
