// SPDX-License-Identifier: Apache-2.0
// Timer VIP Agent
// Encapsulates monitor, scoreboard, and optional sequencer/driver.

`ifndef TIMER_VIP_AGENT_SV
`define TIMER_VIP_AGENT_SV

class timer_vip_agent extends uvm_agent;

    timer_vip_driver     drv;
    timer_vip_monitor    mon;
    timer_vip_sequencer  seqr;
    timer_vip_scoreboard sb;

    `uvm_component_utils(timer_vip_agent)

    function new(string name = "timer_vip_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mon = timer_vip_monitor::type_id::create("mon", this);
        sb  = timer_vip_scoreboard::type_id::create("sb", this);

        if (get_is_active() == UVM_ACTIVE) begin
            drv  = timer_vip_driver::type_id::create("drv", this);
            seqr = timer_vip_sequencer::type_id::create("seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(seqr.seq_item_export);
        end

        mon.ap.connect(sb.mon_export);
    endfunction

endclass : timer_vip_agent

`endif // TIMER_VIP_AGENT_SV
