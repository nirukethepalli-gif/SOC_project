ifndef DMA_VIP_ITEM_SV
define DMA_VIP_ITEM_SV
class dma_vip_item extends uvm_sequence_item;
    rand bit [31:0] src_addr;
    rand bit [31:0] dst_addr;
    rand bit [15:0] burst_len;
    uvm_object_utils_begin(dma_vip_item)
        uvm_field_int(src_addr,  UVM_ALL_ON | UVM_HEX)
        uvm_field_int(dst_addr,  UVM_ALL_ON | UVM_HEX)
        uvm_field_int(burst_len, UVM_ALL_ON | UVM_DEC)
    uvm_object_utils_end
    function new(string name = "dma_vip_item"); super.new(name); endfunction
endclass
endif
