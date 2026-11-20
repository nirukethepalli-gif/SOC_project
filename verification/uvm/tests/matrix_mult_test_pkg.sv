// SPDX-License-Identifier: Apache-2.0
// UVM Test Package for Custom IP 1: Matrix Multiplier
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package matrix_mult_test_pkg;
    import uvm_pkg::*;
    import axilite_pkg::*;
    import stream_pkg::*;
    import matrix_mult_env_pkg::*;
    `include "uvm_macros.svh"

    // Base Test
    class matrix_mult_base_test extends uvm_test;
        `uvm_component_utils(matrix_mult_base_test)

        matrix_mult_env env;

        function new(string name = "matrix_mult_base_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = matrix_mult_env::type_id::create("env", this);
        endfunction
    endclass : matrix_mult_base_test

    // 2x2 Deterministic Layer Test
    class matrix_mult_2x2_test extends matrix_mult_base_test;
        `uvm_component_utils(matrix_mult_2x2_test)

        function new(string name = "matrix_mult_2x2_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            axilite_base_seq axil_seq = axilite_base_seq::type_id::create("axil_seq");
            bit [31:0] x_vec[2];
            bit [31:0] w_mat[4];
            bit [31:0] b_vec[2];

            phase.raise_objection(this);
            `uvm_info("UVM_TEST", "=== Starting matrix_mult_2x2_test ===", UVM_LOW)

            // Setup Q16.16 test vectors:
            // X = [1.5, -0.5]
            x_vec[0] = 32'h0001_8000;
            x_vec[1] = 32'hFFFF_8000;

            // W = [[2.0, 1.0], [-1.0, 3.0]]
            w_mat[0] = 32'h0002_0000;
            w_mat[1] = 32'h0001_0000;
            w_mat[2] = 32'hFFFF_0000;
            w_mat[3] = 32'h0003_0000;

            // B = [0.25, 0.50]
            b_vec[0] = 32'h0000_4000;
            b_vec[1] = 32'h0000_8000;

            // Compute expected results in scoreboard
            env.scoreboard.compute_expected(x_vec, w_mat, b_vec, 2, 2);

            // Program DUT via AXI4-Lite VIP
            // 1. Dimensions M=2, N=1, K=2 -> MAT_DIM_MNK = 0x00020102
            axil_seq.write_reg(32'h8000_4008, 32'h0002_0102);

            // 2. Load Inputs
            axil_seq.write_reg(32'h8000_4014, 32'h0); // Index = 0
            axil_seq.write_reg(32'h8000_4018, x_vec[0]);
            axil_seq.write_reg(32'h8000_4018, x_vec[1]);

            // 3. Load Weights
            axil_seq.write_reg(32'h8000_4014, 32'h0);
            for (int i = 0; i < 4; i++) axil_seq.write_reg(32'h8000_401C, w_mat[i]);

            // 4. Load Biases
            axil_seq.write_reg(32'h8000_4014, 32'h0);
            axil_seq.write_reg(32'h8000_4020, b_vec[0]);
            axil_seq.write_reg(32'h8000_4020, b_vec[1]);

            // 5. Start Matrix Multiplier
            axil_seq.write_reg(32'h8000_4000, 32'h1);

            // 6. Poll for completion
            axil_seq.poll_reg(32'h8000_4004, 0, 1'b1, 500);
            `uvm_info("UVM_TEST", "Matrix Multiplier signaled DONE flag!", UVM_LOW)

            #200ns;
            phase.drop_objection(this);
        endtask
    endclass : matrix_mult_2x2_test

endpackage : matrix_mult_test_pkg
