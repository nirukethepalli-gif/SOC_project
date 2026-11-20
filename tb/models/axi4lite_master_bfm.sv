// SPDX-License-Identifier: Apache-2.0
// Reusable AXI4-Lite Master BFM per Section 14.1 of SoC Specification v2.0

`timescale 1ns/1ps

module axi4lite_master_bfm (
    input  logic        aclk,
    input  logic        aresetn,

    // AXI4-Lite Master Signals
    output logic [31:0] m_awaddr,
    output logic [2:0]  m_awprot,
    output logic        m_awvalid,
    input  logic        m_awready,

    output logic [31:0] m_wdata,
    output logic [3:0]  m_wstrb,
    output logic        m_wvalid,
    input  logic        m_wready,

    input  logic [1:0]  m_bresp,
    input  logic        m_bvalid,
    output logic        m_bready,

    output logic [31:0] m_araddr,
    output logic [2:0]  m_arprot,
    output logic        m_arvalid,
    input  logic        m_arready,

    input  logic [31:0] m_rdata,
    input  logic [1:0]  m_rresp,
    input  logic        m_rvalid,
    output logic        m_rready
);

    // Initial state
    initial begin
        m_awaddr  = '0;
        m_awprot  = 3'b000;
        m_awvalid = 1'b0;
        m_wdata   = '0;
        m_wstrb   = 4'h0;
        m_wvalid  = 1'b0;
        m_bready  = 1'b0;
        m_araddr  = '0;
        m_arprot  = 3'b000;
        m_arvalid = 1'b0;
        m_rready  = 1'b0;
    end

    // Reset task
    task automatic reset_master();
        @(posedge aclk);
        m_awvalid <= 1'b0;
        m_wvalid  <= 1'b0;
        m_bready  <= 1'b0;
        m_arvalid <= 1'b0;
        m_rready  <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Write Task: supports simultaneous, AW-before-W, or W-before-AW
    // -------------------------------------------------------------------------
    task automatic write(
        input  logic [31:0] addr,
        input  logic [31:0] data,
        input  logic [3:0]  strb = 4'hF,
        output logic [1:0]  resp,
        input  int          aw_w_order = 0, // 0: simultaneous, 1: AW first, 2: W first
        input  int          bready_delay = 0
    );
        bit aw_done = 0;
        bit w_done  = 0;
        fork
            // AW Channel
            begin
                if (aw_w_order == 2) repeat (2) @(posedge aclk);
                @(posedge aclk);
                m_awaddr  <= addr;
                m_awprot  <= 3'b000;
                m_awvalid <= 1'b1;
                do begin
                    @(posedge aclk);
                end while (!m_awready);
                m_awvalid <= 1'b0;
                aw_done = 1;
            end

            // W Channel
            begin
                if (aw_w_order == 1) repeat (2) @(posedge aclk);
                @(posedge aclk);
                m_wdata  <= data;
                m_wstrb  <= strb;
                m_wvalid <= 1'b1;
                do begin
                    @(posedge aclk);
                end while (!m_wready);
                m_wvalid <= 1'b0;
                w_done = 1;
            end

            // B Channel
            begin
                m_bready <= 1'b0;
                wait (aw_done && w_done);
                while (!m_bvalid) @(posedge aclk);
                if (bready_delay > 0) repeat (bready_delay) @(posedge aclk);
                m_bready <= 1'b1;
                @(posedge aclk);
                resp = m_bresp;
                m_bready <= 1'b0;
            end
        join
    endtask

    // -------------------------------------------------------------------------
    // Read Task: supports variable rready latency
    // -------------------------------------------------------------------------
    task automatic read(
        input  logic [31:0] addr,
        output logic [31:0] data,
        output logic [1:0]  resp,
        input  int          rready_delay = 0
    );
        bit ar_done = 0;
        fork
            // AR Channel
            begin
                @(posedge aclk);
                m_araddr  <= addr;
                m_arprot  <= 3'b000;
                m_arvalid <= 1'b1;
                do begin
                    @(posedge aclk);
                end while (!m_arready);
                m_arvalid <= 1'b0;
                ar_done = 1;
            end

            // R Channel
            begin
                m_rready <= 1'b0;
                wait (ar_done);
                while (!m_rvalid) @(posedge aclk);
                if (rready_delay > 0) repeat (rready_delay) @(posedge aclk);
                m_rready <= 1'b1;
                @(posedge aclk);
                data = m_rdata;
                resp = m_rresp;
                m_rready <= 1'b0;
            end
        join
    endtask

endmodule

