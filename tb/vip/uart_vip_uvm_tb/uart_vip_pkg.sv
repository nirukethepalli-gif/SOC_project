// SPDX-License-Identifier: Apache-2.0
// UART VIP Package

`ifndef UART_VIP_PKG_SV
`define UART_VIP_PKG_SV

package uart_vip_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "uart_vip_item.sv"
    `include "uart_vip_sequencer.sv"
    `include "uart_connectivity_sequence.sv"
    `include "uart_vip_driver.sv"
    `include "uart_vip_monitor.sv"
    `include "uart_vip_scoreboard.sv"
    `include "uart_vip_agent.sv"
    `include "uart_vip_env.sv"
    `include "uart_vip_test.sv"

endpackage : uart_vip_pkg

`endif // UART_VIP_PKG_SV
