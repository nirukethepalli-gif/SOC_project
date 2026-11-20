// SPDX-License-Identifier: Apache-2.0
// UVM Environment for Custom IP 1: Matrix Multiplier
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

package matrix_mult_env_pkg;
    import uvm_pkg::*;
    import axilite_pkg::*;
    import stream_pkg::*;
    `include "uvm_macros.svh"

    // Matrix Multiplier Golden Reference Scoreboard
    class matrix_mult_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(matrix_mult_scoreboard)

        uvm_analysis_imp #(stream_seq_item, matrix_mult_scoreboard) stream_export;

        int unsigned match_count = 0;
        int unsigned error_count = 0;

        bit [31:0] expected_outputs[$];

        function new(string name = "matrix_mult_scoreboard", uvm_component parent = null);
            super.new(name, parent);
            stream_export = new("stream_export", this);
        endfunction

        // Golden model: Y = W*X + B in Q16.16 signed fixed-point with saturation
        function void compute_expected(
            input bit [31:0] x_vec[],
            input bit [31:0] w_mat[],
            input bit [31:0] b_vec[],
            input int m, input int k
        );
            expected_outputs.delete();
            for (int r = 0; r < m; r++) begin
                longint signed acc = 0;
                for (int c = 0; c < k; c++) begin
                    longint signed x_val = $signed(x_vec[c]);
                    longint signed w_val = $signed(w_mat[r * k + c]);
                    longint signed prod  = (x_val * w_val) >>> 16;
                    acc += prod;
                end
                acc += $signed(b_vec[r]);

                // Saturation clamping to 32-bit signed
                if (acc > 64'sh0000_0000_7FFF_FFFF) begin
                    expected_outputs.push_back(32'h7FFF_FFFF);
                end else if (acc < -64'sh0000_0000_8000_0000) begin
                    expected_outputs.push_back(32'h8000_0000);
                end else begin
                    expected_outputs.push_back(acc[31:0]);
                end
            end
        endfunction

        function void write(stream_seq_item item);
            if (expected_outputs.size() == 0) begin
                `uvm_error("SCB/MM/UNEXPECTED", $sformatf("Received unexpected output: 0x%08X", item.data))
                error_count++;
                return;
            end

            begin
                bit [31:0] exp = expected_outputs.pop_front();
                if (item.data === exp) begin
                    `uvm_info("SCB/MM/PASS", $sformatf("MATCH: Out=0x%08X Expected=0x%08X", item.data, exp), UVM_LOW)
                    match_count++;
                end else begin
                    `uvm_error("SCB/MM/MISMATCH", $sformatf("MISMATCH: Out=0x%08X Expected=0x%08X", item.data, exp))
                    error_count++;
                end
            end
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SCB/MM/SUMMARY", $sformatf("============================================="), UVM_LOW)
            `uvm_info("SCB/MM/SUMMARY", $sformatf("Matrix Multiplier UVM Verification Summary:"), UVM_LOW)
            `uvm_info("SCB/MM/SUMMARY", $sformatf("  Matches: %0d", match_count), UVM_LOW)
            `uvm_info("SCB/MM/SUMMARY", $sformatf("  Errors:  %0d", error_count), UVM_LOW)
            `uvm_info("SCB/MM/SUMMARY", $sformatf("============================================="), UVM_LOW)
            if (error_count > 0 || match_count == 0) begin
                `uvm_fatal("SCB/MM/FAIL", "Matrix Multiplier UVM Verification FAILED!")
            end
        endfunction
    endclass : matrix_mult_scoreboard

    // Matrix Multiplier Environment
    class matrix_mult_env extends uvm_env;
        `uvm_component_utils(matrix_mult_env)

        axilite_agent           axil_agent;
        stream_agent            stream_snk_agent;
        matrix_mult_scoreboard  scoreboard;

        function new(string name = "matrix_mult_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            axil_agent = axilite_agent::type_id::create("axil_agent", this);
            axil_agent.is_active = UVM_ACTIVE;

            stream_snk_agent = stream_agent::type_id::create("stream_snk_agent", this);
            stream_snk_agent.is_active = UVM_ACTIVE;
            stream_snk_agent.role      = STREAM_SNK;

            scoreboard = matrix_mult_scoreboard::type_id::create("scoreboard", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            stream_snk_agent.item_collected_port.connect(scoreboard.stream_export);
        endfunction
    endclass : matrix_mult_env

endpackage : matrix_mult_env_pkg
