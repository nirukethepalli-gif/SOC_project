// SPDX-License-Identifier: Apache-2.0
// Timer VIP Sequence Item
// Represents observed Timer 64-bit counter states, prescaler, comparator, and interrupt flags.

`ifndef TIMER_VIP_ITEM_SV
`define TIMER_VIP_ITEM_SV

class timer_vip_item extends uvm_sequence_item;

    bit [63:0]   mtime;                // Current 64-bit counter value
    bit [63:0]   mtimecmp;             // Programmed 64-bit comparator value
    bit [31:0]   prescale;             // Clock divider prescaler (default 49)
    bit          ctrl_en;              // Timer enable
    bit          ctrl_timer_irq_en;    // Interrupt enable
    bit          timer_int;            // Core machine timer interrupt
    bit          irq;                  // PIC interrupt line
    int unsigned tick_period_cycles;   // Clock cycles elapsed since previous tick
    time         timestamp;

    `uvm_object_utils_begin(timer_vip_item)
        `uvm_field_int(mtime,              UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(mtimecmp,           UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(prescale,           UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(ctrl_en,            UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(ctrl_timer_irq_en,  UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(timer_int,          UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(irq,                UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(tick_period_cycles, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(timestamp,          UVM_ALL_ON | UVM_TIME)
    `uvm_object_utils_end

    function new(string name = "timer_vip_item");
        super.new(name);
        mtime              = 64'h0;
        mtimecmp           = 64'hFFFF_FFFF_FFFF_FFFF;
        prescale           = 32'd49;
        ctrl_en            = 1'b1;
        ctrl_timer_irq_en  = 1'b0;
        timer_int          = 1'b0;
        irq                = 1'b0;
        tick_period_cycles = 0;
        timestamp          = 0;
    endfunction

    virtual function string convert2string();
        return $sformatf(
            "mtime=0x%016x mtimecmp=0x%016x prescale=%0d en=%0b irq_en=%0b timer_int=%0b irq=%0b tick_cycles=%0d",
            mtime, mtimecmp, prescale, ctrl_en, ctrl_timer_irq_en, timer_int, irq, tick_period_cycles);
    endfunction

endclass : timer_vip_item

`endif // TIMER_VIP_ITEM_SV
