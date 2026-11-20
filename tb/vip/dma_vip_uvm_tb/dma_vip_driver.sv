ifndef DMA_VIP_DRIVER_SV
define DMA_VIP_DRIVER_SV
class dma_vip_driver extends uvm_driver #(dma_vip_item);
    uvm_component_utils(dma_vip_driver)
    virtual dma_vip_if vif;
    function new(string name = "dma_vip_driver", uvm_component parent = null); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            seq_item_port.item_done();
        end
    endtask
endclass
endif
