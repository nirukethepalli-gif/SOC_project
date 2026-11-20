ifndef ACTIVATION_VIP_ENV_SV
define ACTIVATION_VIP_ENV_SV
class activation_vip_env extends uvm_env;
    uvm_component_utils(activation_vip_env)
    activation_vip_agent agent;
    function new(string name = "activation_vip_env", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = activation_vip_agent::type_id::create("agent", this);
    endfunction
endclass
endif
