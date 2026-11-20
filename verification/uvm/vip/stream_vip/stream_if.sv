// SPDX-License-Identifier: Apache-2.0
// VIP 2: Accelerator Streaming SystemVerilog Interface
// Project: UVM Verification Environment for Neural Network Accelerator SoC

`timescale 1ns/1ps

interface stream_if (
    input logic clk,
    input logic rst_n
);
    logic [31:0] data;
    logic        valid;
    logic        ready;

    // Master Clocking (Source: drives valid & data, samples ready)
    clocking src_ck @(posedge clk);
        default input #1step output #1ns;
        output data, valid;
        input  ready;
    endclocking

    // Slave Clocking (Sink: drives ready, samples valid & data)
    clocking snk_ck @(posedge clk);
        default input #1step output #1ns;
        output ready;
        input  data, valid;
    endclocking

    // Monitor Clocking
    clocking mon_ck @(posedge clk);
        default input #1step;
        input data, valid, ready;
    endclocking

    modport source  (clocking src_ck, input clk, input rst_n);
    modport sink    (clocking snk_ck, input clk, input rst_n);
    modport monitor (clocking mon_ck, input clk, input rst_n);

    // Stream Protocol Assertions
    property p_valid_hold;
        @(posedge clk) disable iff (!rst_n)
        valid && !ready |=> valid && $stable(data);
    endproperty
    assert_stream_valid_hold: assert property(p_valid_hold)
        else $error("[VIP_ASSERT] Stream VALID dropped or DATA changed before READY!");

endinterface : stream_if
