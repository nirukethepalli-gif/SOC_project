// SPDX-License-Identifier: Apache-2.0
// Timer VIP Monitor
// Observes Timer hardware execution, measuring prescaled clock cycles per tick,
// counter increments, comparator evaluation, and interrupt output lines.

`ifndef TIMER_VIP_MONITOR_SV
`define TIMER_VIP_MONITOR_SV

class timer_vip_monitor extends uvm_monitor;

    virtual timer_vip_if vif;
    uvm_analysis_port #(timer_vip_item) ap;

    `uvm_component_utils(timer_vip_monitor)

    function new(string name = "timer_vip_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        timer_vip_item item;
        logic [63:0] last_mtime   = 64'h0;
        int unsigned cycle_count  = 0;
        bit          first_sample = 1;

        if (vif == null) begin
            `uvm_fatal("TIMER_MON", "vif handle is null in timer_vip_monitor!")
            return;
        end

        // Wait for reset release
        wait (vif.rst_n === 1'b1);
        @(posedge vif.clk);

        `uvm_info(get_type_name(), "Timer VIP Monitor active.", UVM_LOW)

        // Capture initial reset state
        item = timer_vip_item::type_id::create("timer_init_item");
        item.mtime              = vif.dut_mtime;
        item.mtimecmp           = vif.dut_mtimecmp;
        item.prescale           = vif.dut_prescale;
        item.ctrl_en            = vif.dut_ctrl_en;
        item.ctrl_timer_irq_en  = vif.dut_ctrl_timer_irq_en;
        item.timer_int          = vif.timer_int;
        item.irq                = vif.irq;
        item.tick_period_cycles = 0;
        item.timestamp          = $time;
        last_mtime              = vif.dut_mtime;
        ap.write(item);

        forever begin
            @(posedge vif.clk);
            cycle_count++;

            // Detect counter increment (tick event)
            if (vif.dut_mtime !== last_mtime) begin
                item = timer_vip_item::type_id::create("timer_tick_item");
                item.mtime              = vif.dut_mtime;
                item.mtimecmp           = vif.dut_mtimecmp;
                item.prescale           = vif.dut_prescale;
                item.ctrl_en            = vif.dut_ctrl_en;
                item.ctrl_timer_irq_en  = vif.dut_ctrl_timer_irq_en;
                item.timer_int          = vif.timer_int;
                item.irq                = vif.irq;
                item.tick_period_cycles = cycle_count;
                item.timestamp          = $time;

                `uvm_info(get_type_name(),
                    $sformatf("Timer Tick: mtime=0x%0x (delta cycles=%0d, expected=%0d)",
                        item.mtime, cycle_count, vif.dut_prescale + 1), UVM_HIGH)

                ap.write(item);

                last_mtime  = vif.dut_mtime;
                cycle_count = 0;
            end
        end
    endtask

endclass : timer_vip_monitor

`endif // TIMER_VIP_MONITOR_SV
