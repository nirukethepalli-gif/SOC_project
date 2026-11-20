// SPDX-License-Identifier: Apache-2.0
// VIP 3: AXI4 Memory Slave SystemVerilog Interface
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

interface axi_mem_slave_if (
    input logic clk,
    input logic rst_n
);
    // Read Address Channel
    logic [31:0] araddr;
    logic [7:0]  arlen;
    logic [2:0]  arsize;
    logic [1:0]  arburst;
    logic        arvalid;
    logic        arready;

    // Read Data Channel
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rlast;
    logic        rvalid;
    logic        rready;

    // Write Address Channel
    logic [31:0] awaddr;
    logic [7:0]  awlen;
    logic [2:0]  awsize;
    logic [1:0]  awburst;
    logic        awvalid;
    logic        awready;

    // Write Data Channel
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wlast;
    logic        wvalid;
    logic        wready;

    // Write Response Channel
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    // Slave Clocking Block
    clocking sck @(posedge clk);
        default input #1step output #1ns;
        input  araddr, arlen, arsize, arburst, arvalid;
        output arready;
        output rdata, rresp, rlast, rvalid;
        input  rready;
        input  awaddr, awlen, awsize, awburst, awvalid;
        output awready;
        input  wdata, wstrb, wlast, wvalid;
        output wready;
        output bresp, bvalid;
        input  bready;
    endclocking

    modport slave   (clocking sck, input clk, input rst_n);
    modport monitor (input clk, input rst_n,
                     input araddr, arlen, arsize, arburst, arvalid, arready,
                     input rdata, rresp, rlast, rvalid, rready,
                     input awaddr, awlen, awsize, awburst, awvalid, awready,
                     input wdata, wstrb, wlast, wvalid, wready,
                     input bresp, bvalid, bready);

endinterface : axi_mem_slave_if
