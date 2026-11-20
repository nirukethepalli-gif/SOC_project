// SPDX-License-Identifier: Apache-2.0
// GPIO VIP Driver
// Drives stimulus onto GPIO input pins according to transaction mask and value.

`ifndef GPIO_VIP_DRIVER_SV
`define GPIO_VIP_DRIVER_SV

class gpio_vip_driver extends uvm_driver #(gpio_vip_item);

    virtual gpio_vip_if vif;

    `uvm_component_utils(gpio_vip_driver)

    function new(string name = "gpio_vip_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        // Initialize driver outputs
        if (vif == null) begin
            `uvm_fatal("GPIO_DRV", "vif handle is null in gpio_vip_driver!")
            return;
        end

        vif.drv_en  <= 16'h0000;
        vif.drv_val <= 16'h0000;

        // Wait for reset release
        wait (vif.rst_n === 1'b1);
        @(posedge vif.clk);

        `uvm_info(get_type_name(), "GPIO VIP Driver initialized and ready.", UVM_LOW)

        forever begin
            seq_item_port.get_next_item(req);

            `uvm_info(get_type_name(),
                $sformatf("Driving GPIO stimulus: val=0x%04x mask=0x%04x hold=%0d cycles",
                    req.drv_val, req.drv_mask, req.hold_cycles), UVM_HIGH)

            // Drive pins on clock edge
            @(posedge vif.clk);
            vif.drv_en  <= req.drv_mask;
            vif.drv_val <= req.drv_val;

            // Hold stimulus for requested duration
            repeat (req.hold_cycles) @(posedge vif.clk);

            seq_item_port.item_done();
        end
    endtask

endclass : gpio_vip_driver

`endif // GPIO_VIP_DRIVER_SV
