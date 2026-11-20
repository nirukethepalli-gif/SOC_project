// SPDX-License-Identifier: Apache-2.0
ifndef MATRIX_MULTIPLIER_VIP_DRIVER_SV
define MATRIX_MULTIPLIER_VIP_DRIVER_SV

class matrix_multiplier_vip_driver extends uvm_driver #(matrix_multiplier_vip_item);
    uvm_component_utils(matrix_multiplier_vip_driver)
    virtual matrix_multiplier_vip_if vif;

    function new(string name = "matrix_multiplier_vip_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            seq_item_port.item_done();
        end
    endtask
endclass

endif
