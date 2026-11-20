// SPDX-License-Identifier: Apache-2.0
// SoC UVM Environment
// Integrates custom IP VIP agents and baseline peripheral VIPs

`ifndef SOC_ENV_SV
`define SOC_ENV_SV

class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    // Configuration
    soc_config cfg;

    // VIP Agents
    uart_vip_agent              uart_agnt;
    gpio_vip_agent              gpio_agnt;
    timer_vip_agent             timer_agnt;
    matrix_multiplier_vip_agent mm_agnt;
    activation_vip_agent        act_agnt;
    dma_vip_agent               dma_agnt;

    // Virtual Sequencer
    soc_virtual_sequencer       v_sequencer;

    function new(string name = "soc_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(soc_config)::get(this, "", "soc_config", cfg)) begin
            `uvm_info(get_type_name(), "soc_config not set in config_db, creating default", UVM_LOW)
            cfg = soc_config::type_id::create("cfg");
        end

        // Instantiate Agents
        uart_agnt   = uart_vip_agent::type_id::create("uart_agnt", this);
        gpio_agnt   = gpio_vip_agent::type_id::create("gpio_agnt", this);
        timer_agnt  = timer_vip_agent::type_id::create("timer_agnt", this);
        mm_agnt     = matrix_multiplier_vip_agent::type_id::create("mm_agnt", this);
        act_agnt    = activation_vip_agent::type_id::create("act_agnt", this);
        dma_agnt    = dma_vip_agent::type_id::create("dma_agnt", this);

        // Virtual Sequencer
        v_sequencer = soc_virtual_sequencer::type_id::create("v_sequencer", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect virtual sequencer handles
        v_sequencer.uart_seqr  = uart_agnt.seqr;
        v_sequencer.gpio_seqr  = gpio_agnt.seqr;
        v_sequencer.timer_seqr = timer_agnt.seqr;
        v_sequencer.mm_seqr    = mm_agnt.seqr;
        v_sequencer.act_seqr   = act_agnt.seqr;
        v_sequencer.dma_seqr   = dma_agnt.seqr;
    endfunction
endclass

`endif // SOC_ENV_SV
