// SPDX-License-Identifier: Apache-2.0
ifndef MATRIX_MULTIPLIER_VIP_ITEM_SV
define MATRIX_MULTIPLIER_VIP_ITEM_SV

class matrix_multiplier_vip_item extends uvm_sequence_item;
    rand bit [31:0] x_val;
    rand bit [31:0] w_val;
    rand bit [31:0] b_val;
    bit [31:0]      y_result;

    uvm_object_utils_begin(matrix_multiplier_vip_item)
        uvm_field_int(x_val,    UVM_ALL_ON | UVM_HEX)
        uvm_field_int(w_val,    UVM_ALL_ON | UVM_HEX)
        uvm_field_int(b_val,    UVM_ALL_ON | UVM_HEX)
        uvm_field_int(y_result, UVM_ALL_ON | UVM_HEX)
    uvm_object_utils_end

    function new(string name = "matrix_multiplier_vip_item");
        super.new(name);
    endfunction
endclass

endif
