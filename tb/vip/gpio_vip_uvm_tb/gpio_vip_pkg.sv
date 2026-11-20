// SPDX-License-Identifier: Apache-2.0
// GPIO VIP Package

`ifndef GPIO_VIP_PKG_SV
`define GPIO_VIP_PKG_SV

package gpio_vip_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "gpio_vip_item.sv"
    `include "gpio_vip_sequencer.sv"
    `include "gpio_connectivity_sequence.sv"
    `include "gpio_vip_driver.sv"
    `include "gpio_vip_monitor.sv"
    `include "gpio_vip_scoreboard.sv"
    `include "gpio_vip_agent.sv"
    `include "gpio_vip_env.sv"
    `include "gpio_vip_test.sv"

endpackage : gpio_vip_pkg

`endif // GPIO_VIP_PKG_SV
