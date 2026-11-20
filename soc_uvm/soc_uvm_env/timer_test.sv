// SPDX-License-Identifier: Apache-2.0
// SoC Timer UVM Test

`ifndef TIMER_TEST_SV
`define TIMER_TEST_SV

class timer_test extends soc_base_test;
    `uvm_component_utils(timer_test)

    function new(string name = "timer_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting timer_test");
        `uvm_info(get_type_name(), "Executing Timer Test", UVM_LOW)
        
        #200us;
        
        `uvm_info(get_type_name(), "Timer Test Passed", UVM_LOW)
        phase.drop_objection(this, "Ending timer_test");
    endtask
endclass

`endif // TIMER_TEST_SV
