ifndef DMA_VIP_TEST_SV
define DMA_VIP_TEST_SV
class dma_vip_test extends uvm_test;
    uvm_component_utils(dma_vip_test)
    dma_vip_env env;
    function new(string name = "dma_vip_test", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = dma_vip_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #1000ns;
        phase.drop_objection(this);
    endtask
endclass
endif
