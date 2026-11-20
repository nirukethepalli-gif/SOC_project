// SPDX-License-Identifier: Apache-2.0
// VIP 1: AXI4-Lite UVM Package
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package axilite_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Transaction Kind Enum
    typedef enum bit {
        AXIL_WRITE = 1'b0,
        AXIL_READ  = 1'b1
    } axil_kind_e;

    // Response Enum
    typedef enum logic [1:0] {
        AXIL_RESP_OKAY   = 2'b00,
        AXIL_RESP_EXOKAY = 2'b01,
        AXIL_RESP_SLVERR = 2'b10,
        AXIL_RESP_DECERR = 2'b11
    } axil_resp_e;

    // =========================================================================
    // 1. Sequence Item
    // =========================================================================
    class axilite_seq_item extends uvm_sequence_item;
        rand axil_kind_e    kind;
        rand bit [31:0]     addr;
        rand bit [31:0]     data;
        rand bit [3:0]      strb;
        rand bit [2:0]      prot;
        bit [1:0]           resp;

        // Constraints
        constraint c_addr_aligned {
            addr[1:0] == 2'b00; // Word aligned by default
        }
        constraint c_strb_default {
            strb == 4'b1111;
        }
        constraint c_prot_default {
            prot == 3'b000;
        }

        `uvm_object_utils_begin(axilite_seq_item)
            `uvm_field_enum(axil_kind_e, kind, UVM_ALL_ON)
            `uvm_field_int(addr,               UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(data,               UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(strb,               UVM_ALL_ON | UVM_BIN)
            `uvm_field_int(prot,               UVM_ALL_ON)
            `uvm_field_int(resp,               UVM_ALL_ON | UVM_BIN)
        `uvm_object_utils_end

        function new(string name = "axilite_seq_item");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("AXIL_%s [Addr=0x%08X Data=0x%08X Strb=0x%X Resp=%02b]",
                            kind.name(), addr, data, strb, resp);
        endfunction
    endclass : axilite_seq_item

    // =========================================================================
    // 2. Sequencer
    // =========================================================================
    class axilite_sequencer extends uvm_sequencer #(axilite_seq_item);
        `uvm_component_utils(axilite_sequencer)

        function new(string name = "axilite_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass : axilite_sequencer

    // =========================================================================
    // 3. Driver
    // =========================================================================
    class axilite_driver extends uvm_driver #(axilite_seq_item);
        `uvm_component_utils(axilite_driver)

        virtual axilite_if vif;

        function new(string name = "axilite_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axilite_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("VIP/AXIL/NODRV", "Virtual interface axilite_if not found in config_db!")
            end
        endfunction

        task run_phase(uvm_phase phase);
            reset_signals();
            @(posedge vif.rst_n);

            forever begin
                seq_item_port.get_next_item(req);
                drive_item(req);
                seq_item_port.item_done();
            end
        endtask

        task reset_signals();
            vif.mck.awvalid <= 1'b0;
            vif.mck.awaddr  <= '0;
            vif.mck.awprot  <= '0;
            vif.mck.wvalid  <= 1'b0;
            vif.mck.wdata   <= '0;
            vif.mck.wstrb   <= '0;
            vif.mck.bready  <= 1'b0;
            vif.mck.arvalid <= 1'b0;
            vif.mck.araddr  <= '0;
            vif.mck.arprot  <= '0;
            vif.mck.rready  <= 1'b0;
        endtask

        task drive_item(axilite_seq_item item);
            if (item.kind == AXIL_WRITE) begin
                drive_write(item);
            end else begin
                drive_read(item);
            end
        endtask

        task drive_write(axilite_seq_item item);
            @(vif.mck);
            vif.mck.awaddr  <= item.addr;
            vif.mck.awprot  <= item.prot;
            vif.mck.awvalid <= 1'b1;
            vif.mck.wdata   <= item.data;
            vif.mck.wstrb   <= item.strb;
            vif.mck.wvalid  <= 1'b1;
            vif.mck.bready  <= 1'b1;

            fork
                begin
                    do @(vif.mck); while (!vif.mck.awready);
                    vif.mck.awvalid <= 1'b0;
                end
                begin
                    do @(vif.mck); while (!vif.mck.wready);
                    vif.mck.wvalid  <= 1'b0;
                end
            join

            do @(vif.mck); while (!vif.mck.bvalid);
            item.resp = vif.mck.bresp;
            vif.mck.bready <= 1'b0;
            @(vif.mck);
        endtask

        task drive_read(axilite_seq_item item);
            @(vif.mck);
            vif.mck.araddr  <= item.addr;
            vif.mck.arprot  <= item.prot;
            vif.mck.arvalid <= 1'b1;
            vif.mck.rready  <= 1'b1;

            do @(vif.mck); while (!vif.mck.arready);
            vif.mck.arvalid <= 1'b0;

            do @(vif.mck); while (!vif.mck.rvalid);
            item.data = vif.mck.rdata;
            item.resp = vif.mck.rresp;
            vif.mck.rready <= 1'b0;
            @(vif.mck);
        endtask
    endclass : axilite_driver

    // =========================================================================
    // 4. Monitor
    // =========================================================================
    class axilite_monitor extends uvm_monitor;
        `uvm_component_utils(axilite_monitor)

        virtual axilite_if vif;
        uvm_analysis_port #(axilite_seq_item) item_collected_port;

        function new(string name = "axilite_monitor", uvm_component parent = null);
            super.new(name, parent);
            item_collected_port = new("item_collected_port", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual axilite_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("VIP/AXIL/NOMON", "Virtual interface axilite_if not found in config_db!")
            end
        endfunction

        task run_phase(uvm_phase phase);
            fork
                collect_writes();
                collect_reads();
            join
        endtask

        task collect_writes();
            forever begin
                axilite_seq_item item;
                bit [31:0] captured_addr;
                bit [31:0] captured_data;
                bit [3:0]  captured_strb;

                // Wait for address and data handshakes
                fork
                    begin
                        do @(vif.mon_ck); while (!(vif.mon_ck.awvalid && vif.mon_ck.awready));
                        captured_addr = vif.mon_ck.awaddr;
                    end
                    begin
                        do @(vif.mon_ck); while (!(vif.mon_ck.wvalid && vif.mon_ck.wready));
                        captured_data = vif.mon_ck.wdata;
                        captured_strb = vif.mon_ck.wstrb;
                    end
                join

                // Wait for response handshake
                do @(vif.mon_ck); while (!(vif.mon_ck.bvalid && vif.mon_ck.bready));

                item = axilite_seq_item::type_id::create("item");
                item.kind = AXIL_WRITE;
                item.addr = captured_addr;
                item.data = captured_data;
                item.strb = captured_strb;
                item.resp = vif.mon_ck.bresp;

                `uvm_info("VIP/AXIL/MON_WR", item.convert2string(), UVM_HIGH)
                item_collected_port.write(item);
            end
        endtask

        task collect_reads();
            forever begin
                axilite_seq_item item;
                bit [31:0] captured_addr;

                do @(vif.mon_ck); while (!(vif.mon_ck.arvalid && vif.mon_ck.arready));
                captured_addr = vif.mon_ck.araddr;

                do @(vif.mon_ck); while (!(vif.mon_ck.rvalid && vif.mon_ck.rready));

                item = axilite_seq_item::type_id::create("item");
                item.kind = AXIL_READ;
                item.addr = captured_addr;
                item.data = vif.mon_ck.rdata;
                item.resp = vif.mon_ck.rresp;

                `uvm_info("VIP/AXIL/MON_RD", item.convert2string(), UVM_HIGH)
                item_collected_port.write(item);
            end
        endtask
    endclass : axilite_monitor

    // =========================================================================
    // 5. Agent
    // =========================================================================
    class axilite_agent extends uvm_agent;
        `uvm_component_utils(axilite_agent)

        uvm_active_passive_enum is_active = UVM_ACTIVE;
        axilite_driver          driver;
        axilite_sequencer       sequencer;
        axilite_monitor         monitor;
        uvm_analysis_port #(axilite_seq_item) item_collected_port;

        function new(string name = "axilite_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            monitor = axilite_monitor::type_id::create("monitor", this);
            if (is_active == UVM_ACTIVE) begin
                driver    = axilite_driver::type_id::create("driver", this);
                sequencer = axilite_sequencer::type_id::create("sequencer", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (is_active == UVM_ACTIVE) begin
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
            item_collected_port = monitor.item_collected_port;
        endfunction
    endclass : axilite_agent

    // =========================================================================
    // 6. Sequence Library
    // =========================================================================
    class axilite_base_seq extends uvm_sequence #(axilite_seq_item);
        `uvm_object_utils(axilite_base_seq)

        function new(string name = "axilite_base_seq");
            super.new(name);
        endfunction

        task write_reg(input bit [31:0] addr, input bit [31:0] data);
            axilite_seq_item item = axilite_seq_item::type_id::create("item");
            start_item(item);
            item.kind = AXIL_WRITE;
            item.addr = addr;
            item.data = data;
            item.strb = 4'hF;
            finish_item(item);
        endtask

        task read_reg(input bit [31:0] addr, output bit [31:0] data);
            axilite_seq_item item = axilite_seq_item::type_id::create("item");
            start_item(item);
            item.kind = AXIL_READ;
            item.addr = addr;
            finish_item(item);
            data = item.data;
        endtask

        task poll_reg(input bit [31:0] addr, input int bit_idx, input bit expected_val, input int timeout_cycles = 1000);
            bit [31:0] val;
            int count = 0;
            do begin
                read_reg(addr, val);
                count++;
                if (count > timeout_cycles) begin
                    `uvm_fatal("VIP/AXIL/TIMEOUT", $sformatf("Timeout polling addr 0x%08X bit %0d!", addr, bit_idx))
                end
            end while (val[bit_idx] !== expected_val);
        endtask
    endclass : axilite_base_seq

endpackage : axilite_pkg
