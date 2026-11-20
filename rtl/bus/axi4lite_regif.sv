// SPDX-License-Identifier: Apache-2.0
// Reusable AXI4-Lite Register Interface Shim (axi4lite_regif)
// Compliant with Section 6.5 of VeeR EL2 SoC Specification v2.0

`timescale 1ns/1ps

module axi4lite_regif #(
    parameter int ADDR_LSB = 2, // word aligned (bit 2 is LSB of word index)
    parameter int REG_BITS = 6  // [7:2] -> 64 registers
)(
    input  logic                 aclk,
    input  logic                 aresetn,

    // ---- AXI4-Lite Slave Port ----
    input  logic [31:0]          s_awaddr,
    input  logic [2:0]           s_awprot,
    input  logic                 s_awvalid,
    output logic                 s_awready,

    input  logic [31:0]          s_wdata,
    input  logic [3:0]           s_wstrb,
    input  logic                 s_wvalid,
    output logic                 s_wready,

    output logic [1:0]           s_bresp,
    output logic                 s_bvalid,
    input  logic                 s_bready,

    input  logic [31:0]          s_araddr,
    input  logic [2:0]           s_arprot,
    input  logic                 s_arvalid,
    output logic                 s_arready,

    output logic [31:0]          s_rdata,
    output logic [1:0]           s_rresp,
    output logic                 s_rvalid,
    input  logic                 s_rready,

    // ---- Simple Register-Side Interface to the IP ----
    output logic [REG_BITS-1:0]  reg_waddr,
    output logic [31:0]          reg_wdata,
    output logic                 reg_wen,   // 1-cycle strobe
    output logic [REG_BITS-1:0]  reg_raddr,
    output logic                 reg_ren,   // 1-cycle strobe
    input  logic [31:0]          reg_rdata, // Valid 1 cycle after reg_ren
    input  logic                 reg_err    // IP-signalled error -> SLVERR
);

    // =========================================================================
    // Write Channel
    // =========================================================================
    typedef enum logic [1:0] {
        W_IDLE,
        W_RESP
    } w_state_t;

    w_state_t w_state;
    logic [3:0] wstrb_latched;
    logic       werr_latched;

    // Both AW and W must be valid to handshake
    wire w_handshake = s_awvalid && s_wvalid && (w_state == W_IDLE);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state       <= W_IDLE;
            s_awready     <= 1'b0;
            s_wready      <= 1'b0;
            s_bvalid      <= 1'b0;
            s_bresp       <= 2'b00;
            reg_wen       <= 1'b0;
            reg_waddr     <= '0;
            reg_wdata     <= '0;
            wstrb_latched <= 4'b0;
            werr_latched  <= 1'b0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (s_awvalid && s_wvalid) begin
                        s_awready     <= 1'b1;
                        s_wready      <= 1'b1;
                        reg_wen       <= 1'b1;
                        reg_waddr     <= s_awaddr[ADDR_LSB +: REG_BITS];
                        reg_wdata     <= s_wdata;
                        wstrb_latched <= s_wstrb;
                        werr_latched  <= (s_wstrb != 4'hF || reg_err);
                        w_state       <= W_RESP;
                    end else begin
                        s_awready <= 1'b0;
                        s_wready  <= 1'b0;
                        reg_wen   <= 1'b0;
                    end
                end

                W_RESP: begin
                    s_awready <= 1'b0;
                    s_wready  <= 1'b0;
                    reg_wen   <= 1'b0;
                    if (!s_bvalid) begin
                        s_bvalid <= 1'b1;
                        // SLVERR if partial strobe (WSTRB != 4'hF) or IP reports reg_err
                        s_bresp  <= (wstrb_latched != 4'hF || werr_latched || reg_err) ? 2'b10 : 2'b00;
                    end else if (s_bready) begin
                        s_bvalid <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Read Channel
    // =========================================================================
    typedef enum logic [1:0] {
        R_IDLE,
        R_WAIT,
        R_RESP
    } r_state_t;

    r_state_t r_state;
    logic     rerr_latched;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state      <= R_IDLE;
            s_arready    <= 1'b0;
            s_rvalid     <= 1'b0;
            s_rresp      <= 2'b00;
            reg_ren      <= 1'b0;
            reg_raddr    <= '0;
            rerr_latched <= 1'b0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (s_arvalid) begin
                        s_arready    <= 1'b1;
                        reg_ren      <= 1'b1;
                        reg_raddr    <= s_araddr[ADDR_LSB +: REG_BITS];
                        rerr_latched <= reg_err;
                        r_state      <= R_WAIT;
                    end else begin
                        s_arready <= 1'b0;
                        reg_ren   <= 1'b0;
                    end
                end

                R_WAIT: begin
                    // 1 cycle latency for IP register read
                    s_arready    <= 1'b0;
                    reg_ren      <= 1'b0;
                    s_rresp      <= (reg_err || rerr_latched) ? 2'b10 : 2'b00;
                    s_rvalid     <= 1'b1;
                    r_state      <= R_RESP;
                end

                R_RESP: begin
                    if (s_rready) begin
                        s_rvalid <= 1'b0;
                        r_state  <= R_IDLE;
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

    assign s_rdata = reg_rdata;

endmodule

