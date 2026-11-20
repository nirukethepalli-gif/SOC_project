// SPDX-License-Identifier: Apache-2.0
// GPIO VIP Connectivity Sequence
// Applies pin-by-pin and multi-pin patterns to GPIO input pins (pins 8..15).

`ifndef GPIO_CONNECTIVITY_SEQUENCE_SV
`define GPIO_CONNECTIVITY_SEQUENCE_SV

class gpio_connectivity_sequence extends uvm_sequence #(gpio_vip_item);

    `uvm_object_utils(gpio_connectivity_sequence)

    function new(string name = "gpio_connectivity_sequence");
        super.new(name);
    endfunction

    virtual task body();
        gpio_vip_item item;
        bit [15:0] test_patterns [12];
        int num_patterns;

        // Walking 1s across upper 8 input pins (8..15)
        test_patterns[0]  = 16'h0100; // Pin 8
        test_patterns[1]  = 16'h0200; // Pin 9
        test_patterns[2]  = 16'h0400; // Pin 10
        test_patterns[3]  = 16'h0800; // Pin 11
        test_patterns[4]  = 16'h1000; // Pin 12
        test_patterns[5]  = 16'h2000; // Pin 13
        test_patterns[6]  = 16'h4000; // Pin 14
        test_patterns[7]  = 16'h8000; // Pin 15

        // Multi-pin patterns
        test_patterns[8]  = 16'h0000; // All zeros
        test_patterns[9]  = 16'hFF00; // All ones
        test_patterns[10] = 16'hAA00; // Alternating 1010_1010
        test_patterns[11] = 16'h5500; // Alternating 0101_0101
        num_patterns = 12;

        `uvm_info(get_type_name(),
            "Starting GPIO Connectivity Sequence: Walking 1s & Multi-Pin Patterns...", UVM_LOW)

        for (int i = 0; i < num_patterns; i++) begin
            item = gpio_vip_item::type_id::create($sformatf("gpio_item_%0d", i));
            start_item(item);
            item.drv_val     = test_patterns[i];
            item.drv_mask    = 16'hFF00; // Drive upper 8 pins (inputs)
            item.hold_cycles = 10;       // Hold 10 cycles for 2-FF synchronizer
            finish_item(item);

            `uvm_info(get_type_name(),
                $sformatf("Applied pattern %0d/%0d: drv_val=0x%04x", i+1, num_patterns, test_patterns[i]),
                UVM_HIGH)
        end

        `uvm_info(get_type_name(),
            "GPIO Connectivity Sequence completed all 12 test patterns.", UVM_LOW)
    endtask

endclass : gpio_connectivity_sequence

`endif // GPIO_CONNECTIVITY_SEQUENCE_SV
