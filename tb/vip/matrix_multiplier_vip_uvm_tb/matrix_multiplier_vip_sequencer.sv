// SPDX-License-Identifier: Apache-2.0
ifndef MATRIX_MULTIPLIER_VIP_SEQUENCER_SV
define MATRIX_MULTIPLIER_VIP_SEQUENCER_SV

class matrix_multiplier_vip_sequencer extends uvm_sequencer #(matrix_multiplier_vip_item);
    uvm_component_utils(matrix_multiplier_vip_sequencer)
    function new(string name = "matrix_multiplier_vip_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

endif
