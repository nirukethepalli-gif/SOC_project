// SPDX-License-Identifier: Apache-2.0
// GPIO VIP Monitor
// Observes GPIO external pins and internal DUT probes, publishing observed transactions.

`ifndef GPIO_VIP_MONITOR_SV
`define GPIO_VIP_MONITOR_SV

class gpio_vip_monitor extends uvm_monitor;

    virtual gpio_vip_if vif;
    uvm_analysis_port #(gpio_vip_item) ap;

    `uvm_component_utils(gpio_vip_monitor)

    function new(string name = "gpio_vip_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        gpio_vip_item item;
        logic [15:0] last_in   = 16'hxxxx;
        logic [15:0] last_out  = 16'hxxxx;
        logic [15:0] last_oe   = 16'hxxxx;
        logic [15:0] last_sync = 16'hxxxx;

        if (vif == null) begin
            `uvm_fatal("GPIO_MON", "vif handle is null in gpio_vip_monitor!")
            return;
        end

        // Wait for reset release
        wait (vif.rst_n === 1'b1);
        @(posedge vif.clk);

        `uvm_info(get_type_name(), "GPIO VIP Monitor active.", UVM_LOW)

        forever begin
            @(posedge vif.clk);

            // Sample on any state transition or driver change
            if (vif.gpio_in !== last_in ||
                vif.gpio_out !== last_out ||
                vif.gpio_oe !== last_oe ||
                vif.dut_sync_ff2 !== last_sync) begin

                item = gpio_vip_item::type_id::create("gpio_mon_item");
                item.observed_gpio_in  = vif.gpio_in;
                item.observed_gpio_out = vif.gpio_out;
                item.observed_gpio_oe  = vif.gpio_oe;
                item.observed_dut_sync = vif.dut_sync_ff2;
                item.observed_irq      = vif.irq;
                item.drv_val           = vif.drv_val;
                item.drv_mask          = vif.drv_en;
                item.timestamp         = $time;

                last_in   = vif.gpio_in;
                last_out  = vif.gpio_out;
                last_oe   = vif.gpio_oe;
                last_sync = vif.dut_sync_ff2;

                `uvm_info(get_type_name(),
                    $sformatf("Sampled GPIO: out=0x%04x oe=0x%04x in=0x%04x sync=0x%04x irq=%0b",
                        item.observed_gpio_out, item.observed_gpio_oe,
                        item.observed_gpio_in, item.observed_dut_sync, item.observed_irq), UVM_HIGH)

                ap.write(item);
            end
        end
    endtask

endclass : gpio_vip_monitor

`endif // GPIO_VIP_MONITOR_SV
