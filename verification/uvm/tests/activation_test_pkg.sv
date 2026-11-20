// SPDX-License-Identifier: Apache-2.0
// UVM Test Package for Custom IP 2: Activation Unit
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package activation_test_pkg;
    import uvm_pkg::*;
    import axilite_pkg::*;
    import activation_env_pkg::*;
    `include "uvm_macros.svh"

    class activation_base_test extends uvm_test;
        `uvm_component_utils(activation_base_test)

        activation_env env;

        function new(string name = "activation_base_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = activation_env::type_id::create("env", this);
        endfunction
    endclass : activation_base_test

    class activation_all_func_test extends activation_base_test;
        `uvm_component_utils(activation_all_func_test)

        function new(string name = "activation_all_func_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            axilite_base_seq axil_seq = axilite_base_seq::type_id::create("axil_seq");
            bit [31:0] test_inputs[4];
            bit [31:0] read_out;

            phase.raise_objection(this);
            `uvm_info("UVM_TEST", "=== Starting activation_all_func_test ===", UVM_LOW)

            test_inputs[0] = 32'h0002_C000; // +2.75
            test_inputs[1] = 32'hFFFD_8000; // -2.50
            test_inputs[2] = 32'h0000_0000; //  0.00
            test_inputs[3] = 32'h0001_8000; // +1.50

            // -------------------------------------------------------------
            // Sub-test 1: ReLU
            // -------------------------------------------------------------
            `uvm_info("UVM_TEST", "Testing ReLU Activation...", UVM_LOW)
            axil_seq.write_reg(32'h8000_5008, 32'd4); // vec_len = 4
            axil_seq.write_reg(32'h8000_5010, 32'd0); // buf_index = 0
            for (int i = 0; i < 4; i++) axil_seq.write_reg(32'h8000_5014, test_inputs[i]);

            // Start ReLU (func_sel = 00, start = 1 -> CTRL = 0x1)
            axil_seq.write_reg(32'h8000_5000, 32'h1);
            axil_seq.poll_reg(32'h8000_5004, 0, 1'b1, 500);

            // Read back and score
            axil_seq.write_reg(32'h8000_5010, 32'd0);
            for (int i = 0; i < 4; i++) begin
                axil_seq.read_reg(32'h8000_5018, read_out);
                env.scoreboard.check_result("ReLU", test_inputs[i], read_out,
                                           env.scoreboard.model_relu(test_inputs[i]));
            end

            // -------------------------------------------------------------
            // Sub-test 2: Sigmoid PWL
            // -------------------------------------------------------------
            `uvm_info("UVM_TEST", "Testing Sigmoid PWL Activation...", UVM_LOW)
            axil_seq.write_reg(32'h8000_5008, 32'd4);
            axil_seq.write_reg(32'h8000_5010, 32'd0);
            for (int i = 0; i < 4; i++) axil_seq.write_reg(32'h8000_5014, test_inputs[i]);

            // Start Sigmoid (func_sel = 01 << 2 = 0x4, start = 1 -> CTRL = 0x5)
            axil_seq.write_reg(32'h8000_5000, 32'h5);
            axil_seq.poll_reg(32'h8000_5004, 0, 1'b1, 500);

            axil_seq.write_reg(32'h8000_5010, 32'd0);
            for (int i = 0; i < 4; i++) begin
                axil_seq.read_reg(32'h8000_5018, read_out);
                env.scoreboard.check_result("Sigmoid", test_inputs[i], read_out,
                                           env.scoreboard.model_sigmoid_pwl(test_inputs[i]));
            end

            // -------------------------------------------------------------
            // Sub-test 3: Tanh PWL
            // -------------------------------------------------------------
            `uvm_info("UVM_TEST", "Testing Tanh PWL Activation...", UVM_LOW)
            axil_seq.write_reg(32'h8000_5008, 32'd4);
            axil_seq.write_reg(32'h8000_5010, 32'd0);
            for (int i = 0; i < 4; i++) axil_seq.write_reg(32'h8000_5014, test_inputs[i]);

            // Start Tanh (func_sel = 10 << 2 = 0x8, start = 1 -> CTRL = 0x9)
            axil_seq.write_reg(32'h8000_5000, 32'h9);
            axil_seq.poll_reg(32'h8000_5004, 0, 1'b1, 500);

            axil_seq.write_reg(32'h8000_5010, 32'd0);
            for (int i = 0; i < 4; i++) begin
                axil_seq.read_reg(32'h8000_5018, read_out);
                env.scoreboard.check_result("Tanh", test_inputs[i], read_out,
                                           env.scoreboard.model_tanh_pwl(test_inputs[i]));
            end

            #100ns;
            phase.drop_objection(this);
        endtask
    endclass : activation_all_func_test

endpackage : activation_test_pkg
