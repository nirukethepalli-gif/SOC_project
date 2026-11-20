// SPDX-License-Identifier: Apache-2.0
// Read-Only AXI4 to AXI4-Lite Bridge (for VeeR EL2 IFU Instruction Fetch)
// Compliant with Section 6.1 & 6.3 of VeeR EL2 SoC Specification v2.0

`timescale 1ns/1ps

module axi4_to_axi4lite_ro #(
    parameter int ID_WIDTH = 3
)(
    input  logic                 aclk,
    input  logic                 aresetn,

    // Core-side AXI4 Read Channel
    input  logic [ID_WIDTH-1:0]  s_axi_arid,
    input  logic [31:0]          s_axi_araddr,
    input  logic [7:0]           s_axi_arlen,
    input  logic [2:0]           s_axi_arsize,
    input  logic [1:0]           s_axi_arburst,
    input  logic [2:0]           s_axi_arprot,
    input  logic                 s_axi_arvalid,
    output logic                 s_axi_arready,

    output logic [ID_WIDTH-1:0]  s_axi_rid,
    output logic [63:0]          s_axi_rdata,
    output logic [1:0]           s_axi_rresp,
    output logic                 s_axi_rlast,
    output logic                 s_axi_rvalid,
    input  logic                 s_axi_rready,

    // SoC-side AXI4-Lite Read Channel (to IMEM Port A)
    output logic [31:0]          m_axil_araddr,
    output logic [2:0]           m_axil_arprot,
    output logic                 m_axil_arvalid,
    input  logic                 m_axil_arready,

    input  logic [31:0]          m_axil_rdata,
    input  logic [1:0]           m_axil_rresp,
    input  logic                 m_axil_rvalid,
    output logic                 m_axil_rready
);

    function automatic logic [1:0] worst_resp(input logic [1:0] r1, input logic [1:0] r2);
        if (r1 == 2'b11 || r2 == 2'b11) return 2'b11;
        if (r1 == 2'b10 || r2 == 2'b10) return 2'b10;
        return 2'b00;
    endfunction

    typedef enum logic [2:0] {
        R_IDLE,
        R_ISSUE_LO,
        R_WAIT_LO,
        R_ISSUE_HI,
        R_WAIT_HI,
        R_RESP
    } r_fsm_t;

    r_fsm_t r_state;

    logic [ID_WIDTH-1:0] rd_id_q;
    logic [31:0]         rd_addr_q;
    logic [7:0]          rd_len_q;
    logic [2:0]          rd_size_q;
    logic [1:0]          rd_burst_q;
    logic [2:0]          rd_prot_q;
    logic [7:0]          beat_idx;
    logic [7:0]          beat_total;

    logic [31:0]         word_lo;
    logic [31:0]         word_hi;
    logic [1:0]          rresp_acc;
    logic                needs_two_reads;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state         <= R_IDLE;
            s_axi_arready   <= 1'b0;
            s_axi_rvalid    <= 1'b0;
            s_axi_rid       <= '0;
            s_axi_rdata     <= 64'b0;
            s_axi_rresp     <= 2'b00;
            s_axi_rlast     <= 1'b0;
            m_axil_arvalid  <= 1'b0;
            m_axil_araddr   <= 32'h0;
            m_axil_arprot   <= 3'b000;
            m_axil_rready   <= 1'b0;
            beat_idx        <= 8'h0;
            beat_total      <= 8'h0;
            rresp_acc       <= 2'b00;
            word_lo         <= 32'h0;
            word_hi         <= 32'h0;
            needs_two_reads <= 1'b0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    s_axi_arready <= 1'b1;
                    s_axi_rvalid  <= 1'b0;

                    if (s_axi_arvalid && s_axi_arready) begin
                        rd_id_q         <= s_axi_arid;
                        rd_addr_q       <= s_axi_araddr;
                        rd_len_q        <= s_axi_arlen;
                        rd_size_q       <= s_axi_arsize;
                        rd_burst_q      <= s_axi_arburst;
                        rd_prot_q       <= s_axi_arprot;
                        beat_total      <= s_axi_arlen + 1;
                        beat_idx        <= 8'h0;
                        needs_two_reads <= (s_axi_arsize >= 3);
                        s_axi_arready   <= 1'b0;
                        r_state         <= R_ISSUE_LO;
                    end
                end

                R_ISSUE_LO: begin
                    logic [31:0] current_addr;
                    if (rd_burst_q == 2'b00) begin
                        current_addr = rd_addr_q;
                    end else begin
                        current_addr = rd_addr_q + (beat_idx << rd_size_q);
                    end

                    m_axil_araddr  <= {current_addr[31:3], 3'b000} | (needs_two_reads ? 32'h0 : (current_addr & 32'h4));
                    m_axil_arprot  <= rd_prot_q;
                    m_axil_arvalid <= 1'b1;
                    m_axil_rready  <= 1'b1;
                    r_state        <= R_WAIT_LO;
                end

                R_WAIT_LO: begin
                    if (m_axil_arready) m_axil_arvalid <= 1'b0;

                    if (m_axil_rvalid && m_axil_rready) begin
                        word_lo       <= m_axil_rdata;
                        rresp_acc     <= m_axil_rresp;
                        m_axil_rready <= 1'b0;

                        if (needs_two_reads) begin
                            r_state <= R_ISSUE_HI;
                        end else begin
                            word_hi <= m_axil_rdata;
                            r_state <= R_RESP;
                        end
                    end
                end

                R_ISSUE_HI: begin
                    logic [31:0] current_addr;
                    if (rd_burst_q == 2'b00) begin
                        current_addr = rd_addr_q;
                    end else begin
                        current_addr = rd_addr_q + (beat_idx << rd_size_q);
                    end

                    m_axil_araddr  <= {current_addr[31:3], 3'b000} + 4;
                    m_axil_arprot  <= rd_prot_q;
                    m_axil_arvalid <= 1'b1;
                    m_axil_rready  <= 1'b1;
                    r_state        <= R_WAIT_HI;
                end

                R_WAIT_HI: begin
                    if (m_axil_arready) m_axil_arvalid <= 1'b0;

                    if (m_axil_rvalid && m_axil_rready) begin
                        word_hi       <= m_axil_rdata;
                        rresp_acc     <= worst_resp(rresp_acc, m_axil_rresp);
                        m_axil_rready <= 1'b0;
                        r_state       <= R_RESP;
                    end
                end

                R_RESP: begin
                    s_axi_rid    <= rd_id_q;
                    s_axi_rdata  <= {word_hi, word_lo};
                    s_axi_rresp  <= rresp_acc;
                    s_axi_rlast  <= (beat_idx == (beat_total - 1));
                    s_axi_rvalid <= 1'b1;

                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        if (beat_idx + 1 < beat_total) begin
                            beat_idx <= beat_idx + 1;
                            r_state  <= R_ISSUE_LO;
                        end else begin
                            s_axi_arready <= 1'b1;
                            r_state       <= R_IDLE;
                        end
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

endmodule

