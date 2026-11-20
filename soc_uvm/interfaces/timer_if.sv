// SPDX-License-Identifier: Apache-2.0
	imescale 1ns/1ps
interface timer_if(input logic clk, input logic rst_n);
    logic timer_int;
    logic irq;
endinterface
