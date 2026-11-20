// SPDX-License-Identifier: Apache-2.0
// VIP 1: AXI4-Lite SystemVerilog Interface
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

interface axilite_if (
    input logic clk,
    input logic rst_n
);
    // Write Address Channel
    logic [31:0] awaddr;
    logic [2:0]  awprot;
    logic        awvalid;
    logic        awready;

    // Write Data Channel
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic        wvalid;
    logic        wready;

    // Write Response Channel
    logic [1:0]  bresp;
    logic        bvalid;
    logic        bready;

    // Read Address Channel
    logic [31:0] araddr;
    logic [2:0]  arprot;
    logic        arvalid;
    logic        arready;

    // Read Data Channel
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic        rvalid;
    logic        rready;

    // Master Clocking Block
    clocking mck @(posedge clk);
        default input #1step output #1ns;
        output awaddr, awprot, awvalid;
        input  awready;
        output wdata, wstrb, wvalid;
        input  wready;
        input  bresp, bvalid;
        output bready;
        output araddr, arprot, arvalid;
        input  arready;
        input  rdata, rresp, rvalid;
        output rready;
    endclocking

    // Monitor Clocking Block
    clocking mon_ck @(posedge clk);
        default input #1step;
        input awaddr, awprot, awvalid, awready;
        input wdata, wstrb, wvalid, wready;
        input bresp, bvalid, bready;
        input araddr, arprot, arvalid, arready;
        input rdata, rresp, rvalid, rready;
    endclocking

    modport master (clocking mck, input clk, input rst_n);
    modport monitor (clocking mon_ck, input clk, input rst_n);

    // Protocol Assertions
    property p_awvalid_hold;
        @(posedge clk) disable iff (!rst_n)
        awvalid && !awready |=> awvalid && $stable(awaddr);
    endproperty
    assert_awvalid_hold: assert property(p_awvalid_hold) else $error("[VIP_ASSERT] AWVALID dropped before AWREADY!");

    property p_wvalid_hold;
        @(posedge clk) disable iff (!rst_n)
        wvalid && !wready |=> wvalid && $stable(wdata);
    endproperty
    assert_wvalid_hold: assert property(p_wvalid_hold) else $error("[VIP_ASSERT] WVALID dropped before WREADY!");

    property p_arvalid_hold;
        @(posedge clk) disable iff (!rst_n)
        arvalid && !arready |=> arvalid && $stable(araddr);
    endproperty
    assert_arvalid_hold: assert property(p_arvalid_hold) else $error("[VIP_ASSERT] ARVALID dropped before ARREADY!");

endinterface : axilite_if
