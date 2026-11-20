ifndef DMA_VIP_ENV_SV
define DMA_VIP_ENV_SV
class dma_vip_env extends uvm_env;
    uvm_component_utils(dma_vip_env)
    dma_vip_agent agent;
    function new(string name = "dma_vip_env", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = dma_vip_agent::type_id::create("agent", this);
    endfunction
endclass
endif
