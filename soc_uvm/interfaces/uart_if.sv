// SPDX-License-Identifier: Apache-2.0
	imescale 1ns/1ps
interface uart_if(input logic clk, input logic rst_n);
    logic uart_tx;
    logic uart_rx;
    logic irq;
endinterface
