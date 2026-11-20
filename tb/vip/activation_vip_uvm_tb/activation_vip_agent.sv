ifndef ACTIVATION_VIP_AGENT_SV
define ACTIVATION_VIP_AGENT_SV
class activation_vip_agent extends uvm_agent;
    uvm_component_utils(activation_vip_agent)
    activation_vip_driver    drv;
    activation_vip_sequencer seqr;
    activation_vip_monitor   mon;
    activation_vip_scoreboard sb;
    function new(string name = "activation_vip_agent", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = activation_vip_driver::type_id::create("drv", this);
        seqr = activation_vip_sequencer::type_id::create("seqr", this);
        mon  = activation_vip_monitor::type_id::create("mon", this);
        sb   = activation_vip_scoreboard::type_id::create("sb", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.item_collected_port.connect(sb.item_export);
    endfunction
endclass
endif
