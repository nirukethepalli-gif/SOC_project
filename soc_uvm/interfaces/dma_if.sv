// SPDX-License-Identifier: Apache-2.0
	imescale 1ns/1ps
interface dma_if(input logic clk, input logic rst_n);
    logic        busy;
    logic        done;
    logic        error;
    logic        irq;
endinterface
