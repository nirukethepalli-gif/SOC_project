// SPDX-License-Identifier: Apache-2.0
// SoC UVM Configuration Object
// Project: RISC-V Based SoC for Lightweight NN Inference Acceleration

`ifndef SOC_CONFIG_SV
`define SOC_CONFIG_SV

class soc_config extends uvm_object;
    `uvm_object_utils(soc_config)

    // Agent Active/Passive configurations
    uvm_active_passive_enum is_uart_active        = UVM_ACTIVE;
    uvm_active_passive_enum is_gpio_active        = UVM_ACTIVE;
    uvm_active_passive_enum is_timer_active       = UVM_PASSIVE;
    uvm_active_passive_enum is_mm_active          = UVM_PASSIVE;
    uvm_active_passive_enum is_act_active         = UVM_PASSIVE;
    uvm_active_passive_enum is_dma_active         = UVM_PASSIVE;

    // Coverage & Check enables
    bit enable_coverage                           = 1'b1;
    bit enable_scoreboard                         = 1'b1;

    // Simulation parameters
    int unsigned num_test_iterations              = 10;
    string       firmware_hex                     = "main.hex";

    function new(string name = "soc_config");
        super.new(name);
    endfunction
endclass

`endif // SOC_CONFIG_SV
