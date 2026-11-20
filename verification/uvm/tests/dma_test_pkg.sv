// SPDX-License-Identifier: Apache-2.0
// UVM Test Package for Custom IP 3: DMA Controller
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package dma_test_pkg;
    import uvm_pkg::*;
    import axilite_pkg::*;
    import axi_mem_slave_pkg::*;
    import dma_env_pkg::*;
    `include "uvm_macros.svh"

    class dma_base_test extends uvm_test;
        `uvm_component_utils(dma_base_test)

        dma_env env;

        function new(string name = "dma_base_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = dma_env::type_id::create("env", this);
        endfunction
    endclass : dma_base_test

    class dma_transfer_test extends dma_base_test;
        `uvm_component_utils(dma_transfer_test)

        function new(string name = "dma_transfer_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            axilite_base_seq axil_seq = axilite_base_seq::type_id::create("axil_seq");
            bit [31:0] test_words[4];
            bit [31:0] rdata;

            phase.raise_objection(this);
            `uvm_info("UVM_TEST", "=== Starting dma_transfer_test ===", UVM_LOW)

            test_words[0] = 32'h1122_3344;
            test_words[1] = 32'h5566_7788;
            test_words[2] = 32'h99AA_BBCC;
            test_words[3] = 32'hDDEE_FF00;

            // Preload memory in AXI4 Memory Slave VIP at 0x1000_0100
            env.mem_agent.driver.preload(32'h1000_0100, test_words);

            // Program DMA via AXI4-Lite VIP:
            // Source: 0x1000_0100
            axil_seq.write_reg(32'h8000_3008, 32'h1000_0100);
            // Destination Buffer: 0x0
            axil_seq.write_reg(32'h8000_300C, 32'h0);
            // Length: 4
            axil_seq.write_reg(32'h8000_3010, 32'd4);

            // Start DMA: direction = 0 (Mem->Acc), target = 00 (Input Buffer), start = 1 -> CTRL = 0x1
            `uvm_info("UVM_TEST", "Triggering DMA Memory->Accelerator Burst...", UVM_LOW)
            axil_seq.write_reg(32'h8000_3000, 32'h1);

            // Poll for DMA DONE
            axil_seq.poll_reg(32'h8000_3004, 0, 1'b1, 500);
            `uvm_info("UVM_TEST", "DMA Controller signaled DONE!", UVM_LOW)

            axil_seq.read_reg(32'h8000_3004, rdata);
            env.scoreboard.check_transfer("DMA_DONE_FLAG", 32'h1, {31'b0, rdata[0]});

            #100ns;
            phase.drop_objection(this);
        endtask
    endclass : dma_transfer_test

endpackage : dma_test_pkg
