// SPDX-License-Identifier: Apache-2.0
// AXI4-Lite 1-to-N Interconnect (axi4lite_interconnect)
// Fully independent read and write paths per Section 6.6 of SoC Specification v2.0

`timescale 1ns/1ps

module axi4lite_interconnect #(
    parameter int NSLV = 9
)(
    input  logic                                aclk,
    input  logic                                aresetn,

    // ---- Master Port (from Core LSU Bridge) ----
    input  logic [31:0]                         m_awaddr,
    input  logic [2:0]                          m_awprot,
    input  logic                                m_awvalid,
    output logic                                m_awready,

    input  logic [31:0]                         m_wdata,
    input  logic [3:0]                          m_wstrb,
    input  logic                                m_wvalid,
    output logic                                m_wready,

    output logic [1:0]                          m_bresp,
    output logic                                m_bvalid,
    input  logic                                m_bready,

    input  logic [31:0]                         m_araddr,
    input  logic [2:0]                          m_arprot,
    input  logic                                m_arvalid,
    output logic                                m_arready,

    output logic [31:0]                         m_rdata,
    output logic [1:0]                          m_rresp,
    output logic                                m_rvalid,
    input  logic                                m_rready,

    // ---- Slave Ports (to Memories and Peripherals) ----
    output logic [NSLV-1:0][31:0]               s_awaddr,
    output logic [NSLV-1:0][2:0]                s_awprot,
    output logic [NSLV-1:0]                     s_awvalid,
    input  logic [NSLV-1:0]                     s_awready,

    output logic [NSLV-1:0][31:0]               s_wdata,
    output logic [NSLV-1:0][3:0]                s_wstrb,
    output logic [NSLV-1:0]                     s_wvalid,
    input  logic [NSLV-1:0]                     s_wready,

    input  logic [NSLV-1:0][1:0]                s_bresp,
    input  logic [NSLV-1:0]                     s_bvalid,
    output logic [NSLV-1:0]                     s_bready,

    output logic [NSLV-1:0][31:0]               s_araddr,
    output logic [NSLV-1:0][2:0]                s_arprot,
    output logic [NSLV-1:0]                     s_arvalid,
    input  logic [NSLV-1:0]                     s_arready,

    input  logic [NSLV-1:0][31:0]               s_rdata,
    input  logic [NSLV-1:0][1:0]                s_rresp,
    input  logic [NSLV-1:0]                     s_rvalid,
    output logic [NSLV-1:0]                     s_rready
);

    // =========================================================================
    // Address Decoders
    // =========================================================================
    logic [NSLV-1:0] wsel_comb;
    logic            dec_err_w;
    axi4lite_decoder #(.NSLV(NSLV)) u_dec_w (
        .addr   (m_awaddr),
        .sel    (wsel_comb),
        .dec_err(dec_err_w)
    );

    logic [NSLV-1:0] rsel_comb;
    logic            dec_err_r;
    axi4lite_decoder #(.NSLV(NSLV)) u_dec_r (
        .addr   (m_araddr),
        .sel    (rsel_comb),
        .dec_err(dec_err_r)
    );

    // =========================================================================
    // Write Path Routing (Single outstanding write per D15)
    // =========================================================================
    logic [NSLV-1:0] wsel_q;
    logic            w_in_flight;
    logic            aw_done;
    logic            w_done;

    wire [NSLV-1:0] active_wsel = w_in_flight ? wsel_q : wsel_comb;

    // Master AW & W handshakes
    wire m_aw_handshake = m_awvalid && m_awready;
    wire m_w_handshake  = m_wvalid  && m_wready;
    wire m_b_handshake  = m_bvalid  && m_bready;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wsel_q      <= '0;
            w_in_flight <= 1'b0;
            aw_done     <= 1'b0;
            w_done      <= 1'b0;
        end else begin
            if (!w_in_flight) begin
                if (m_aw_handshake) begin
                    wsel_q      <= wsel_comb;
                    w_in_flight <= 1'b1;
                    aw_done     <= 1'b1;
                    w_done      <= m_w_handshake;
                end else if (m_w_handshake) begin
                    // If W handshakes before AW (rare), wait for AW
                    w_done <= 1'b1;
                end
            end else begin
                if (m_aw_handshake) aw_done <= 1'b1;
                if (m_w_handshake)  w_done  <= 1'b1;

                if (m_b_handshake) begin
                    w_in_flight <= 1'b0;
                    aw_done     <= 1'b0;
                    w_done      <= 1'b0;
                end
            end
        end
    end

    // Route AW to slaves
    always_comb begin
        m_awready = 1'b0;
        for (int i = 0; i < NSLV; i++) begin
            s_awaddr[i]  = m_awaddr;
            s_awprot[i]  = m_awprot;
            s_awvalid[i] = m_awvalid && active_wsel[i] && (!aw_done);
            if (active_wsel[i] && (!aw_done)) begin
                m_awready = s_awready[i];
            end
        end
    end

    // Route W to slaves
    always_comb begin
        m_wready = 1'b0;
        for (int i = 0; i < NSLV; i++) begin
            s_wdata[i]  = m_wdata;
            s_wstrb[i]  = m_wstrb;
            s_wvalid[i] = m_wvalid && active_wsel[i] && (!w_done);
            if (active_wsel[i] && (!w_done)) begin
                m_wready = s_wready[i];
            end
        end
    end

    // Route B response from active slave
    always_comb begin
        m_bvalid = 1'b0;
        m_bresp  = 2'b00;
        for (int i = 0; i < NSLV; i++) begin
            s_bready[i] = m_bready && active_wsel[i] && w_in_flight;
            if (active_wsel[i] && w_in_flight) begin
                m_bvalid = s_bvalid[i];
                m_bresp  = s_bresp[i];
            end
        end
    end

    // =========================================================================
    // Read Path Routing (Single outstanding read per D15)
    // =========================================================================
    logic [NSLV-1:0] rsel_q;
    logic            r_in_flight;

    wire [NSLV-1:0] active_rsel = r_in_flight ? rsel_q : rsel_comb;

    wire m_ar_handshake = m_arvalid && m_arready;
    wire m_r_handshake  = m_rvalid  && m_rready;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rsel_q      <= '0;
            r_in_flight <= 1'b0;
        end else begin
            if (!r_in_flight) begin
                if (m_ar_handshake) begin
                    rsel_q      <= rsel_comb;
                    r_in_flight <= 1'b1;
                end
            end else begin
                if (m_r_handshake) begin
                    r_in_flight <= 1'b0;
                end
            end
        end
    end

    // Route AR to slaves
    always_comb begin
        m_arready = 1'b0;
        for (int i = 0; i < NSLV; i++) begin
            s_araddr[i]  = m_araddr;
            s_arprot[i]  = m_arprot;
            s_arvalid[i] = m_arvalid && active_rsel[i] && (!r_in_flight);
            if (active_rsel[i] && (!r_in_flight)) begin
                m_arready = s_arready[i];
            end
        end
    end

    // Route R response from active slave
    always_comb begin
        m_rvalid = 1'b0;
        m_rdata  = 32'b0;
        m_rresp  = 2'b00;
        for (int i = 0; i < NSLV; i++) begin
            s_rready[i] = m_rready && active_rsel[i] && r_in_flight;
            if (active_rsel[i] && r_in_flight) begin
                m_rvalid = s_rvalid[i];
                m_rdata  = s_rdata[i];
                m_rresp  = s_rresp[i];
            end
        end
    end

endmodule

