// SPDX-License-Identifier: Apache-2.0
ifndef MATRIX_MULTIPLIER_VIP_AGENT_SV
define MATRIX_MULTIPLIER_VIP_AGENT_SV

class matrix_multiplier_vip_agent extends uvm_agent;
    uvm_component_utils(matrix_multiplier_vip_agent)
    matrix_multiplier_vip_driver    drv;
    matrix_multiplier_vip_sequencer seqr;
    matrix_multiplier_vip_monitor   mon;
    matrix_multiplier_vip_scoreboard sb;

    function new(string name = "matrix_multiplier_vip_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = matrix_multiplier_vip_driver::type_id::create("drv", this);
        seqr = matrix_multiplier_vip_sequencer::type_id::create("seqr", this);
        mon  = matrix_multiplier_vip_monitor::type_id::create("mon", this);
        sb   = matrix_multiplier_vip_scoreboard::type_id::create("sb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.item_collected_port.connect(sb.item_export);
    endfunction
endclass

endif
