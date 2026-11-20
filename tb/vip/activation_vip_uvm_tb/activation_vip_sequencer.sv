ifndef ACTIVATION_VIP_SEQUENCER_SV
define ACTIVATION_VIP_SEQUENCER_SV
class activation_vip_sequencer extends uvm_sequencer #(activation_vip_item);
    uvm_component_utils(activation_vip_sequencer)
    function new(string name = "activation_vip_sequencer", uvm_component parent = null); super.new(name, parent); endfunction
endclass
endif
