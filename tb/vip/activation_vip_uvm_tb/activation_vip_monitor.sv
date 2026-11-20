ifndef ACTIVATION_VIP_MONITOR_SV
define ACTIVATION_VIP_MONITOR_SV
class activation_vip_monitor extends uvm_monitor;
    uvm_component_utils(activation_vip_monitor)
    virtual activation_vip_if vif;
    uvm_analysis_port #(activation_vip_item) item_collected_port;
    function new(string name = "activation_vip_monitor", uvm_component parent = null);
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
