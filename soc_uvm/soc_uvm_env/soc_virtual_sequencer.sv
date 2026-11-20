// SPDX-License-Identifier: Apache-2.0
// SoC Virtual Sequencer: coordinates stimuli across multiple VIP agents

`ifndef SOC_VIRTUAL_SEQUENCER_SV
`define SOC_VIRTUAL_SEQUENCER_SV

class soc_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(soc_virtual_sequencer)

    // Sub-sequencer handles
    uart_vip_sequencer              uart_seqr;
    gpio_vip_sequencer              gpio_seqr;
    timer_vip_sequencer             timer_seqr;
    matrix_multiplier_vip_sequencer mm_seqr;
    activation_vip_sequencer        act_seqr;
    dma_vip_sequencer               dma_seqr;

    function new(string name = "soc_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

`endif // SOC_VIRTUAL_SEQUENCER_SV
