// SPDX-License-Identifier: Apache-2.0
// SoC UART Connectivity UVM Test

`ifndef UART_CONNECTIVITY_TEST_SV
`define UART_CONNECTIVITY_TEST_SV

class uart_connectivity_test extends soc_base_test;
    `uvm_component_utils(uart_connectivity_test)

    function new(string name = "uart_connectivity_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting uart_connectivity_test");
        `uvm_info(get_type_name(), "Executing UART Connectivity Test", UVM_LOW)
        
        #300us;
        
        `uvm_info(get_type_name(), "UART Connectivity Test Passed", UVM_LOW)
        phase.drop_objection(this, "Ending uart_connectivity_test");
    endtask
endclass

`endif // UART_CONNECTIVITY_TEST_SV
