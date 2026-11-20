// SPDX-License-Identifier: Apache-2.0
	imescale 1ns/1ps
interface dma_vip_if;
    logic        clk;
    logic        rst_n;
    logic        busy;
    logic        done;
    logic        error;
    logic        irq;
    logic [31:0] dut_src_addr;
    logic [31:0] dut_dst_addr;
    logic [15:0] dut_burst_len;
endinterface
