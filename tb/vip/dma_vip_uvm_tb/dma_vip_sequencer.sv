ifndef DMA_VIP_SEQUENCER_SV
define DMA_VIP_SEQUENCER_SV
class dma_vip_sequencer extends uvm_sequencer #(dma_vip_item);
    uvm_component_utils(dma_vip_sequencer)
    function new(string name = "dma_vip_sequencer", uvm_component parent = null); super.new(name, parent); endfunction
endclass
endif
