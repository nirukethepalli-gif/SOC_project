// SPDX-License-Identifier: Apache-2.0
// UVM Environment for Custom IP 2: Activation Unit
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package activation_env_pkg;
    import uvm_pkg::*;
    import axilite_pkg::*;
    `include "uvm_macros.svh"

    class activation_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(activation_scoreboard)

        int unsigned match_count = 0;
        int unsigned error_count = 0;

        function new(string name = "activation_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        // Golden Reference Model for ReLU
        function bit [31:0] model_relu(bit [31:0] x);
            if (x[31] == 1'b1) return 32'h0000_0000;
            return x;
        endfunction

        // Golden Reference Model for Sigmoid PWL
        function bit [31:0] model_sigmoid_pwl(bit [31:0] x);
            int signed s_x = $signed(x);
            if (s_x <= -262144) return 32'h0000_0000; // <= -4.0
            if (s_x >= 262144)  return 32'h0001_0000; // >= +4.0
            if (s_x == 0)       return 32'h0000_8000; // 0.5
            // Piecewise linear interpolation: 0.5 + x * 0.125
            return 32'h0000_8000 + (s_x >>> 3);
        endfunction

        // Golden Reference Model for Tanh PWL
        function bit [31:0] model_tanh_pwl(bit [31:0] x);
            int signed s_x = $signed(x);
            if (s_x >= 196608)  return 32'h0001_0000; // >= +3.0 -> +1.0
            if (s_x <= -196608) return 32'hFFFF_0000; // <= -3.0 -> -1.0
            if (s_x == 0)       return 32'h0000_0000; // 0.0
            return s_x;
        endfunction

        function void check_result(string func_name, bit [31:0] in_val, bit [31:0] actual_val, bit [31:0] expected_val);
            if (actual_val === expected_val) begin
                `uvm_info("SCB/ACT/PASS", $sformatf("[%s] In=0x%08X Act=0x%08X Exp=0x%08X - MATCH",
                          func_name, in_val, actual_val, expected_val), UVM_LOW)
                match_count++;
            end else begin
                `uvm_error("SCB/ACT/FAIL", $sformatf("[%s] MISMATCH! In=0x%08X Act=0x%08X Exp=0x%08X",
                           func_name, in_val, actual_val, expected_val))
                error_count++;
            end
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB/ACT/SUMMARY", $sformatf("============================================="), UVM_LOW)
            `uvm_info("SCB/ACT/SUMMARY", $sformatf("Activation Unit UVM Verification Summary:"), UVM_LOW)
            `uvm_info("SCB/ACT/SUMMARY", $sformatf("  Matches: %0d", match_count), UVM_LOW)
            `uvm_info("SCB/ACT/SUMMARY", $sformatf("  Errors:  %0d", error_count), UVM_LOW)
            `uvm_info("SCB/ACT/SUMMARY", $sformatf("============================================="), UVM_LOW)
            if (error_count > 0 || match_count == 0) begin
                `uvm_fatal("SCB/ACT/FAIL", "Activation Unit UVM Verification FAILED!")
            end
        endfunction
    endclass : activation_scoreboard

    class activation_env extends uvm_env;
        `uvm_component_utils(activation_env)

        axilite_agent         axil_agent;
        activation_scoreboard scoreboard;

        function new(string name = "activation_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            axil_agent = axilite_agent::type_id::create("axil_agent", this);
            scoreboard = activation_scoreboard::type_id::create("scoreboard", this);
        endfunction
    endclass : activation_env

endpackage : activation_env_pkg
