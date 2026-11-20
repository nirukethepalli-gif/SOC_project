ifndef DMA_VIP_SCOREBOARD_SV
define DMA_VIP_SCOREBOARD_SV
class dma_vip_scoreboard extends uvm_scoreboard;
    uvm_component_utils(dma_vip_scoreboard)
    virtual dma_vip_if vif;
    uvm_analysis_imp #(dma_vip_item, dma_vip_scoreboard) item_export;
    function new(string name = "dma_vip_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction
    function void write(dma_vip_item item); endfunction
endclass
endif
