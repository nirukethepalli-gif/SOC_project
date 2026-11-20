// SPDX-License-Identifier: Apache-2.0
ifndef MATRIX_MULTIPLIER_VIP_MONITOR_SV
define MATRIX_MULTIPLIER_VIP_MONITOR_SV

class matrix_multiplier_vip_monitor extends uvm_monitor;
    uvm_component_utils(matrix_multiplier_vip_monitor)
    virtual matrix_multiplier_vip_if vif;
    uvm_analysis_port #(matrix_multiplier_vip_item) item_collected_port;

    function new(string name = "matrix_multiplier_vip_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.clk);
            if (vif.stream_act_valid && vif.stream_act_ready) begin
                matrix_multiplier_vip_item item = matrix_multiplier_vip_item::type_id::create("item");
                item.y_result = vif.stream_act_data;
                item_collected_port.write(item);
            end
        end
    endtask
endclass

endif
