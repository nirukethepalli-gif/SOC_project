// SPDX-License-Identifier: Apache-2.0
// UART VIP Agent
// Encapsulates sequencer, driver, monitor, and scoreboard.

`ifndef UART_VIP_AGENT_SV
`define UART_VIP_AGENT_SV

class uart_vip_agent extends uvm_agent;

    uart_vip_driver     drv;
    uart_vip_monitor    mon;
    uart_vip_sequencer  seqr;
    uart_vip_scoreboard sb;

    `uvm_component_utils(uart_vip_agent)

    function new(string name = "uart_vip_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        mon = uart_vip_monitor::type_id::create("mon", this);
        sb  = uart_vip_scoreboard::type_id::create("sb", this);

        if (get_is_active() == UVM_ACTIVE) begin
            drv  = uart_vip_driver::type_id::create("drv", this);
            seqr = uart_vip_sequencer::type_id::create("seqr", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(seqr.seq_item_export);
        end

        mon.ap.connect(sb.mon_export);
    endfunction

endclass : uart_vip_agent

`endif // UART_VIP_AGENT_SV
