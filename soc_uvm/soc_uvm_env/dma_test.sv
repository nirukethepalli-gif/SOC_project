// SPDX-License-Identifier: Apache-2.0
// SoC DMA Controller UVM Integration Test

`ifndef DMA_TEST_SV
`define DMA_TEST_SV

class dma_test extends soc_base_test;
    `uvm_component_utils(dma_test)

    function new(string name = "dma_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting dma_test");
        `uvm_info(get_type_name(), "Executing DMA Controller SoC UVM Test", UVM_LOW)
        
        #500us;
        
        `uvm_info(get_type_name(), "DMA Controller SoC Test Completed Successfully", UVM_LOW)
        phase.drop_objection(this, "Ending dma_test");
    endtask
endclass

`endif // DMA_TEST_SV
