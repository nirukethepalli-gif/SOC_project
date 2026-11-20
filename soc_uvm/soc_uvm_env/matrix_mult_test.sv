// SPDX-License-Identifier: Apache-2.0
// SoC Matrix Multiplier UVM Integration Test

`ifndef MATRIX_MULT_TEST_SV
`define MATRIX_MULT_TEST_SV

class matrix_mult_test extends soc_base_test;
    `uvm_component_utils(matrix_mult_test)

    function new(string name = "matrix_mult_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting matrix_mult_test");
        `uvm_info(get_type_name(), "Executing Matrix Multiplier SoC UVM Test", UVM_LOW)
        
        // Wait for firmware boot and accelerator execution
        #500us;
        
        `uvm_info(get_type_name(), "Matrix Multiplier SoC Test Completed Successfully", UVM_LOW)
        phase.drop_objection(this, "Ending matrix_mult_test");
    endtask
endclass

`endif // MATRIX_MULT_TEST_SV
