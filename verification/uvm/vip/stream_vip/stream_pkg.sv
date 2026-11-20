// SPDX-License-Identifier: Apache-2.0
// VIP 2: Accelerator Streaming UVM Package
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package stream_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum { STREAM_SRC, STREAM_SNK } stream_role_e;

    // =========================================================================
    // 1. Sequence Item
    // =========================================================================
    class stream_seq_item extends uvm_sequence_item;
        rand bit [31:0] data;
        rand int unsigned delay;

        constraint c_delay_reasonable {
            delay inside {[0:5]};
        }

        `uvm_object_utils_begin(stream_seq_item)
            `uvm_field_int(data,  UVM_ALL_ON | UVM_HEX)
            `uvm_field_int(delay, UVM_ALL_ON | UVM_DEC)
        `uvm_object_utils_end

        function new(string name = "stream_seq_item");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf("STREAM_ITEM [Data=0x%08X Delay=%0d]", data, delay);
        endfunction
    endclass : stream_seq_item

    // =========================================================================
    // 2. Sequencer
    // =========================================================================
    class stream_sequencer extends uvm_sequencer #(stream_seq_item);
        `uvm_component_utils(stream_sequencer)

        function new(string name = "stream_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass : stream_sequencer

    // =========================================================================
    // 3. Driver
    // =========================================================================
    class stream_driver extends uvm_driver #(stream_seq_item);
        `uvm_component_utils(stream_driver)

        virtual stream_if vif;
        stream_role_e     role = STREAM_SNK;

        function new(string name = "stream_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual stream_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("VIP/STREAM/NODRV", "Virtual interface stream_if not found in config_db!")
            end
        endfunction

        task run_phase(uvm_phase phase);
            if (role == STREAM_SRC) begin
                vif.src_ck.valid <= 1'b0;
                vif.src_ck.data  <= '0;
                @(posedge vif.rst_n);

                forever begin
                    seq_item_port.get_next_item(req);
                    repeat (req.delay) @(vif.src_ck);
                    vif.src_ck.data  <= req.data;
                    vif.src_ck.valid <= 1'b1;
                    do @(vif.src_ck); while (!vif.src_ck.ready);
                    vif.src_ck.valid <= 1'b0;
                    seq_item_port.item_done();
                end
            end else begin
                // Sink role: drives ready to receive from Matrix Multiplier
                vif.snk_ck.ready <= 1'b0;
                @(posedge vif.rst_n);

                forever begin
                    // Consume items from sequencer for backpressure profiling
                    seq_item_port.try_next_item(req);
                    if (req != null) begin
                        repeat (req.delay) begin
                            vif.snk_ck.ready <= 1'b0;
                            @(vif.snk_ck);
                        end
                        vif.snk_ck.ready <= 1'b1;
                        do @(vif.snk_ck); while (!vif.snk_ck.valid);
                        seq_item_port.item_done();
                    end else begin
                        vif.snk_ck.ready <= 1'b1;
                        @(vif.snk_ck);
                    end
                end
            end
        endtask
    endclass : stream_driver

    // =========================================================================
    // 4. Monitor
    // =========================================================================
    class stream_monitor extends uvm_monitor;
        `uvm_component_utils(stream_monitor)

        virtual stream_if vif;
        uvm_analysis_port #(stream_seq_item) item_collected_port;

        function new(string name = "stream_monitor", uvm_component parent = null);
            super.new(name, parent);
            item_collected_port = new("item_collected_port", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual stream_if)::get(this, "", "vif", vif)) begin
                `uvm_fatal("VIP/STREAM/NOMON", "Virtual interface stream_if not found in config_db!")
            end
        endfunction

        task run_phase(uvm_phase phase);
            @(posedge vif.rst_n);
            forever begin
                do @(vif.mon_ck); while (!(vif.mon_ck.valid && vif.mon_ck.ready));
                begin
                    stream_seq_item item = stream_seq_item::type_id::create("item");
                    item.data = vif.mon_ck.data;
                    `uvm_info("VIP/STREAM/SAMPLE", item.convert2string(), UVM_HIGH)
                    item_collected_port.write(item);
                end
            end
        endtask
    endclass : stream_monitor

    // =========================================================================
    // 5. Agent
    // =========================================================================
    class stream_agent extends uvm_agent;
        `uvm_component_utils(stream_agent)

        uvm_active_passive_enum is_active = UVM_ACTIVE;
        stream_role_e           role      = STREAM_SNK;
        stream_driver           driver;
        stream_sequencer        sequencer;
        stream_monitor          monitor;
        uvm_analysis_port #(stream_seq_item) item_collected_port;

        function new(string name = "stream_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            monitor = stream_monitor::type_id::create("monitor", this);
            if (is_active == UVM_ACTIVE) begin
                driver    = stream_driver::type_id::create("driver", this);
                driver.role = this.role;
                sequencer = stream_sequencer::type_id::create("sequencer", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (is_active == UVM_ACTIVE) begin
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
            item_collected_port = monitor.item_collected_port;
        endfunction
    endclass : stream_agent

endpackage : stream_pkg
