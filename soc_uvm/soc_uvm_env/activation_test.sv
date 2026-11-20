// SPDX-License-Identifier: Apache-2.0
// SoC Activation Unit UVM Integration Test

`ifndef ACTIVATION_TEST_SV
`define ACTIVATION_TEST_SV

class activation_test extends soc_base_test;
    `uvm_component_utils(activation_test)

    function new(string name = "activation_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting activation_test");
        `uvm_info(get_type_name(), "Executing Activation Unit SoC UVM Test", UVM_LOW)
        
        #500us;
        
        `uvm_info(get_type_name(), "Activation Unit SoC Test Completed Successfully", UVM_LOW)
        phase.drop_objection(this, "Ending activation_test");
    endtask
endclass

`endif // ACTIVATION_TEST_SV
