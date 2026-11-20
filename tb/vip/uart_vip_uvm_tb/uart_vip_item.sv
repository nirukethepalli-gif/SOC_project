// SPDX-License-Identifier: Apache-2.0
// UART VIP Sequence Item
// Represents a single UART frame transaction with full protocol parameters.

`ifndef UART_VIP_ITEM_SV
`define UART_VIP_ITEM_SV

class uart_vip_item extends uvm_sequence_item;

    rand logic [7:0]     data;
    rand int unsigned    baud_rate;
    rand int unsigned    clk_freq_hz;
    rand int unsigned    data_bits;
    rand bit [1:0]       stop_bits;
    rand bit             parity_en;
    rand bit             parity_type; // 0 = Even, 1 = Odd

    `uvm_object_utils_begin(uart_vip_item)
        `uvm_field_int(data,        UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(baud_rate,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(clk_freq_hz, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(data_bits,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(stop_bits,   UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(parity_en,   UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(parity_type, UVM_ALL_ON | UVM_BIN)
    `uvm_object_utils_end

    constraint c_defaults {
        soft data        == 8'hA5;
        soft baud_rate   == 115200;
        soft clk_freq_hz == 50_000_000;
        soft data_bits   == 8;
        soft stop_bits   == 1;
        soft parity_en   == 0;
        soft parity_type == 0;
    }

    function new(string name = "uart_vip_item");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf("data=0x%02X (%08b) baud=%0d bits=%0d stop=%0d parity=%s",
            data, data, baud_rate, data_bits, stop_bits,
            parity_en ? (parity_type ? "ODD" : "EVEN") : "NONE");
    endfunction

endclass : uart_vip_item

`endif // UART_VIP_ITEM_SV
