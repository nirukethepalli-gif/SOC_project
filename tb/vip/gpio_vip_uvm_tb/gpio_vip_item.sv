// SPDX-License-Identifier: Apache-2.0
// GPIO VIP Sequence Item
// Represents GPIO input stimulus drive transactions and observed pin/register states.

`ifndef GPIO_VIP_ITEM_SV
`define GPIO_VIP_ITEM_SV

class gpio_vip_item extends uvm_sequence_item;

    // -------------------------------------------------------------------------
    // Stimulus Fields (driven by VIP driver into DUT GPIO pins)
    // -------------------------------------------------------------------------
    rand bit [15:0] drv_val;       // Value to drive on pins
    rand bit [15:0] drv_mask;      // Active pin drive mask (1=drive, 0=float/Z)
    int unsigned    hold_cycles;   // Number of clock cycles to hold stimulus

    // -------------------------------------------------------------------------
    // Observed / Monitor Fields (sampled by VIP monitor)
    // -------------------------------------------------------------------------
    bit [15:0] observed_gpio_out;  // DUT output register data_out_q
    bit [15:0] observed_gpio_oe;   // DUT output enable dir_q
    bit [15:0] observed_gpio_in;   // Observed external pins
    bit [15:0] observed_dut_sync;  // DUT internal 2-FF synchronized input (sync_ff2)
    bit        observed_irq;       // GPIO interrupt flag
    time       timestamp;

    `uvm_object_utils_begin(gpio_vip_item)
        `uvm_field_int(drv_val,           UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(drv_mask,          UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(hold_cycles,       UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(observed_gpio_out, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(observed_gpio_oe,  UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(observed_gpio_in,  UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(observed_dut_sync, UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(observed_irq,      UVM_ALL_ON | UVM_BIN)
        `uvm_field_int(timestamp,         UVM_ALL_ON | UVM_TIME)
    `uvm_object_utils_end

    function new(string name = "gpio_vip_item");
        super.new(name);
        drv_val     = 16'h0000;
        drv_mask    = 16'hFF00; // Default: drive upper 8 input pins
        hold_cycles = 10;
        timestamp   = 0;
    endfunction

    virtual function string convert2string();
        return $sformatf(
            "drv_val=0x%04x drv_mask=0x%04x | obs_out=0x%04x obs_oe=0x%04x obs_in=0x%04x obs_sync=0x%04x irq=%0b",
            drv_val, drv_mask, observed_gpio_out, observed_gpio_oe, observed_gpio_in, observed_dut_sync, observed_irq);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        gpio_vip_item rhs_;
        if (!$cast(rhs_, rhs)) begin
            `uvm_fatal("GPIO_ITEM", "Cast failed in do_copy")
            return;
        end
        super.do_copy(rhs);
        this.drv_val           = rhs_.drv_val;
        this.drv_mask          = rhs_.drv_mask;
        this.hold_cycles       = rhs_.hold_cycles;
        this.observed_gpio_out = rhs_.observed_gpio_out;
        this.observed_gpio_oe  = rhs_.observed_gpio_oe;
        this.observed_gpio_in  = rhs_.observed_gpio_in;
        this.observed_dut_sync = rhs_.observed_dut_sync;
        this.observed_irq      = rhs_.observed_irq;
        this.timestamp         = rhs_.timestamp;
    endfunction

endclass : gpio_vip_item

`endif // GPIO_VIP_ITEM_SV
