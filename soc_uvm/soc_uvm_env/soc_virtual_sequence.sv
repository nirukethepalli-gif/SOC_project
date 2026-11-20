// SPDX-License-Identifier: Apache-2.0
// SoC Virtual Sequence Base Class

`ifndef SOC_VIRTUAL_SEQUENCE_SV
`define SOC_VIRTUAL_SEQUENCE_SV

class soc_base_virtual_sequence extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(soc_base_virtual_sequence)
    `uvm_declare_p_sequencer(soc_virtual_sequencer)

    function new(string name = "soc_base_virtual_sequence");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "Executing SoC base virtual sequence body", UVM_MEDIUM)
    endtask
endclass

`endif // SOC_VIRTUAL_SEQUENCE_SV
