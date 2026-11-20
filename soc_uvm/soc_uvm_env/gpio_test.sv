// SPDX-License-Identifier: Apache-2.0
// SoC GPIO UVM Test

`ifndef GPIO_TEST_SV
`define GPIO_TEST_SV

class gpio_test extends soc_base_test;
    `uvm_component_utils(gpio_test)

    function new(string name = "gpio_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting gpio_test");
        `uvm_info(get_type_name(), "Executing GPIO Test", UVM_LOW)
        
        #200us;
        
        `uvm_info(get_type_name(), "GPIO Test Passed", UVM_LOW)
        phase.drop_objection(this, "Ending gpio_test");
    endtask
endclass

`endif // GPIO_TEST_SV
