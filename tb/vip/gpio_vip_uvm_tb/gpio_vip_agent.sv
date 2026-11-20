// SPDX-License-Identifier: Apache-2.0
// GPIO VIP Agent
// Encapsulates sequencer, driver, monitor, and scoreboard.

`ifndef GPIO_VIP_AGENT_SV
`define GPIO_VIP_AGENT_SV

class gpio_vip_agent extends uvm_agent;

    gpio_vip_driver     drv;
    gpio_vip_monitor    mon;
    gpio_vip_sequencer  seqr;
    gpio_vip_scoreboard sb;

    `uvm_component_utils(gpio_vip_agent)

    function new(string name = "gpio_vip_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mon = gpio_vip_monitor::type_id::create("mon", this);
        sb  = gpio_vip_scoreboard::type_id::create("sb", this);

        if (get_is_active() == UVM_ACTIVE) begin
            drv  = gpio_vip_driver::type_id::create("drv", this);
            seqr = gpio_vip_sequencer::type_id::create("seqr", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(seqr.seq_item_export);
        end

        mon.ap.connect(sb.mon_export);
    endfunction

endclass : gpio_vip_agent

`endif // GPIO_VIP_AGENT_SV
