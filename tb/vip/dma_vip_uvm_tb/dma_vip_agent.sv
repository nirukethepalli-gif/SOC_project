ifndef DMA_VIP_AGENT_SV
define DMA_VIP_AGENT_SV
class dma_vip_agent extends uvm_agent;
    uvm_component_utils(dma_vip_agent)
    dma_vip_driver    drv;
    dma_vip_sequencer seqr;
    dma_vip_monitor   mon;
    dma_vip_scoreboard sb;
    function new(string name = "dma_vip_agent", uvm_component parent = null); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = dma_vip_driver::type_id::create("drv", this);
        seqr = dma_vip_sequencer::type_id::create("seqr", this);
        mon  = dma_vip_monitor::type_id::create("mon", this);
        sb   = dma_vip_scoreboard::type_id::create("sb", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.item_collected_port.connect(sb.item_export);
    endfunction
endclass
endif
