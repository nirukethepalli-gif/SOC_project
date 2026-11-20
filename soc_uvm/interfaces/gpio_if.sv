// SPDX-License-Identifier: Apache-2.0
	imescale 1ns/1ps
interface gpio_if #(parameter int NGPIO = 16)(input logic clk, input logic rst_n);
    logic [NGPIO-1:0] gpio_in;
    logic [NGPIO-1:0] gpio_out;
    logic [NGPIO-1:0] gpio_oe;
    logic             irq;
endinterface
