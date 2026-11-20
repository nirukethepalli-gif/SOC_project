// SPDX-License-Identifier: Apache-2.0
	imescale 1ns/1ps
interface activation_if(input logic clk, input logic rst_n);
    logic        busy;
    logic        done;
    logic        irq;
    logic [31:0] stream_in_data;
    logic        stream_in_valid;
    logic        stream_in_ready;
endinterface
