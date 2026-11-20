// SPDX-License-Identifier: Apache-2.0
// SoC Base Test Class

`ifndef SOC_TEST_SV
`define SOC_TEST_SV

class soc_base_test extends uvm_test;
    `uvm_component_utils(soc_base_test)

    soc_env    env;
    soc_config cfg;

    function new(string name = "soc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = soc_config::type_id::create("cfg");
        uvm_config_db#(soc_config)::set(this, "env", "soc_config", cfg);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this, "Starting base test");
        `uvm_info(get_type_name(), "Running SoC Base Test...", UVM_LOW)
        #100us;
        phase.drop_objection(this, "Ending base test");
    endtask
endclass

`endif // SOC_TEST_SV
