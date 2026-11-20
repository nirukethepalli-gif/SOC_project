ifndef ACTIVATION_VIP_DRIVER_SV
define ACTIVATION_VIP_DRIVER_SV
class activation_vip_driver extends uvm_driver #(activation_vip_item);
    uvm_component_utils(activation_vip_driver)
    virtual activation_vip_if vif;
    function new(string name = "activation_vip_driver", uvm_component parent = null); super.new(name, parent); endfunction
    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            seq_item_port.item_done();
        end
    endtask
endclass
endif
