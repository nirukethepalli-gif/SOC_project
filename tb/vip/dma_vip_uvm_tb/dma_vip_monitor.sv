ifndef DMA_VIP_MONITOR_SV
define DMA_VIP_MONITOR_SV
class dma_vip_monitor extends uvm_monitor;
    uvm_component_utils(dma_vip_monitor)
    virtual dma_vip_if vif;
    uvm_analysis_port #(dma_vip_item) item_collected_port;
    function new(string name = "dma_vip_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction
    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
        end
    endtask
endclass
endif
