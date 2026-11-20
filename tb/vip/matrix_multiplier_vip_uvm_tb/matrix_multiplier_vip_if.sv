// SPDX-License-Identifier: Apache-2.0
	imescale 1ns/1ps

interface matrix_multiplier_vip_if;
    logic        clk;
    logic        rst_n;
    logic        busy;
    logic        done;
    logic        irq;
    logic [31:0] stream_act_data;
    logic        stream_act_valid;
    logic        stream_act_ready;
    logic [7:0]  dut_dim_m;
    logic [7:0]  dut_dim_k;
    logic        dut_status_overflow;
endinterface
