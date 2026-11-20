// SPDX-License-Identifier: Apache-2.0
ifndef MATRIX_MULTIPLIER_VIP_SCOREBOARD_SV
define MATRIX_MULTIPLIER_VIP_SCOREBOARD_SV

class matrix_multiplier_vip_scoreboard extends uvm_scoreboard;
    uvm_component_utils(matrix_multiplier_vip_scoreboard)
    virtual matrix_multiplier_vip_if vif;
    uvm_analysis_imp #(matrix_multiplier_vip_item, matrix_multiplier_vip_scoreboard) item_export;

    int matches = 0;
    int errors  = 0;

    function new(string name = "matrix_multiplier_vip_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction

    function void write(matrix_multiplier_vip_item item);
        uvm_info("MM_VIP_SCB", ("Observed MAC Output: 0x%08X", item.y_result), UVM_LOW)
        matches++;
    endfunction
endclass

endif
