// SPDX-License-Identifier: Apache-2.0
// VIP 3: AXI4 Memory Slave UVM Package
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package axi_mem_slave_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Transaction Object
    class axi_mem_trans extends uvm_sequence_item;
        bit        is_write;
        bit [31:0] addr;
        bit [7:0]  len;
        bit [31:0] data_beats[$];
        bit [1:0]  resp;

        `uvm_object_utils_begin(axi_mem_trans)
            `uvm_field_int(is_write, UVM_ALL_ON)
            `uvm_field_int(addr,     UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(len,      UVM_ALL_ON | UVM_DEC)
            `uvm_field_queue_int(data_beats, UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(resp,     UVM_ALL_ON | UVM_BIN)
        `uvm_object_utils_end

        function new(string name = "axi_mem_trans");
            super.new(name);
        endfunction
    endclass : axi_mem_trans

    // Driver (Memory Responder)
    class axi_mem_slave_driver extends uvm_driver #(axi_mem_trans);
        `uvm_component_utils(axi_mem_slave_driver)

        virtual axi_mem_slave_if vif;
        bit [31:0] mem[bit [31:0]]; // Sparse memory associative array

        function new(string name = "axi_mem_slave_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_mem_slave_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("VIP/AXIMEM/NODRV", "Virtual interface axi_mem_slave_if not found in config_db!")
            end
        endfunction

        // Preload memory method
        function void preload(bit [31:0] start_addr, bit [31:0] words[]);
            for (int i = 0; i < words.size(); i++) begin
                mem[start_addr + (i * 4)] = words[i];
            end
        endfunction

        task run_phase(uvm_phase phase);
            vif.sck.arready <= 1'b0;
            vif.sck.rvalid  <= 1'b0;
            vif.sck.rlast   <= 1'b0;
            vif.sck.awready <= 1'b0;
            vif.sck.wready  <= 1'b0;
            vif.sck.bvalid  <= 1'b0;
            @(posedge vif.rst_n);

            fork
                handle_reads();
                handle_writes();
            join
        endtask

        task handle_reads();
            forever begin
                bit [31:0] cur_addr;
                bit [7:0]  burst_len;

                vif.sck.arready <= 1'b1;
                do @(vif.sck); while (!vif.sck.arvalid);
                cur_addr  = vif.sck.araddr;
                burst_len = vif.sck.arlen;
                vif.sck.arready <= 1'b0;

                // Send read beats
                for (int beat = 0; beat <= burst_len; beat++) begin
                    bit [31:0] rdata_val;
                    if (mem.exists(cur_addr)) rdata_val = mem[cur_addr];
                    else rdata_val = 32'hDEAD_BEEF;

                    vif.sck.rdata  <= rdata_val;
                    vif.sck.rresp  <= 2'b00;
                    vif.sck.rlast  <= (beat == burst_len);
                    vif.sck.rvalid <= 1'b1;

                    do @(vif.sck); while (!vif.sck.rready);
                    cur_addr += 4;
                end
                vif.sck.rvalid <= 1'b0;
                vif.sck.rlast  <= 1'b0;
            end
        endtask

        task handle_writes();
            forever begin
                bit [31:0] cur_addr;
                bit [7:0]  burst_len;

                vif.sck.awready <= 1'b1;
                do @(vif.sck); while (!vif.sck.awvalid);
                cur_addr  = vif.sck.awaddr;
                burst_len = vif.sck.awlen;
                vif.sck.awready <= 1'b0;

                vif.sck.wready <= 1'b1;
                for (int beat = 0; beat <= burst_len; beat++) begin
                    do @(vif.sck); while (!vif.sck.wvalid);
                    mem[cur_addr] = vif.sck.wdata;
                    cur_addr += 4;
                end
                vif.sck.wready <= 1'b0;

                // Send write response
                vif.sck.bresp  <= 2'b00;
                vif.sck.bvalid <= 1'b1;
                do @(vif.sck); while (!vif.sck.bready);
                vif.sck.bvalid <= 1'b0;
            end
        endtask
    endclass : axi_mem_slave_driver

    // Monitor
    class axi_mem_slave_monitor extends uvm_monitor;
        `uvm_component_utils(axi_mem_slave_monitor)

        virtual axi_mem_slave_if vif;
        uvm_analysis_port #(axi_mem_trans) item_collected_port;

        function new(string name = "axi_mem_slave_monitor", uvm_component parent = null);
            super.new(name, parent);
            item_collected_port = new("item_collected_port", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axi_mem_slave_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("VIP/AXIMEM/NOMON", "Virtual interface axi_mem_slave_if not found in config_db!")
            end
        endfunction
    endclass : axi_mem_slave_monitor

    // Agent
    class axi_mem_slave_agent extends uvm_agent;
        `uvm_component_utils(axi_mem_slave_agent)

        axi_mem_slave_driver  driver;
        axi_mem_slave_monitor monitor;

        function new(string name = "axi_mem_slave_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            driver  = axi_mem_slave_driver::type_id::create("driver", this);
            monitor = axi_mem_slave_monitor::type_id::create("monitor", this);
        endfunction
    endclass : axi_mem_slave_agent

endpackage : axi_mem_slave_pkg
