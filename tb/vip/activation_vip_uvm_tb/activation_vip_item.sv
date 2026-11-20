ifndef ACTIVATION_VIP_ITEM_SV
define ACTIVATION_VIP_ITEM_SV
class activation_vip_item extends uvm_sequence_item;
    rand bit [31:0] in_data;
    bit [31:0]      out_data;
    uvm_object_utils_begin(activation_vip_item)
        uvm_field_int(in_data,  UVM_ALL_ON | UVM_HEX)
        uvm_field_int(out_data, UVM_ALL_ON | UVM_HEX)
    uvm_object_utils_end
    function new(string name = "activation_vip_item"); super.new(name); endfunction
endclass
endif
