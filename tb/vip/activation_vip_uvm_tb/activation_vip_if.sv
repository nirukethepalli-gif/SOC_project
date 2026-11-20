// SPDX-License-Identifier: Apache-2.0
	imescale 1ns/1ps
interface activation_vip_if;
    logic        clk;
    logic        rst_n;
    logic        busy;
    logic        done;
    logic        irq;
    logic [31:0] stream_in_data;
    logic        stream_in_valid;
    logic        stream_in_ready;
    logic [1:0]  dut_func_sel;
    logic [15:0] dut_vec_len;
endinterface
