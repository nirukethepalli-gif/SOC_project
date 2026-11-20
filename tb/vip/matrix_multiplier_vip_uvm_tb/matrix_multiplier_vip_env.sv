// SPDX-License-Identifier: Apache-2.0
ifndef MATRIX_MULTIPLIER_VIP_ENV_SV
define MATRIX_MULTIPLIER_VIP_ENV_SV

class matrix_multiplier_vip_env extends uvm_env;
    uvm_component_utils(matrix_multiplier_vip_env)
    matrix_multiplier_vip_agent agent;

    function new(string name = "matrix_multiplier_vip_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = matrix_multiplier_vip_agent::type_id::create("agent", this);
    endfunction
endclass

endif
