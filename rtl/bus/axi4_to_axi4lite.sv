// SPDX-License-Identifier: Apache-2.0
// AXI4 (64-bit, burst, IDs) to AXI4-Lite (32-bit, single-beat) Bridge
// Compliant with Section 6.2, 6.3, 6.4 of VeeR EL2 SoC Specification v2.0

`timescale 1ns/1ps

module axi4_to_axi4lite #(
    parameter int ID_WIDTH = 4
)(
    input  logic                 aclk,
    input  logic                 aresetn,

    // =========================================================================
    // Core-Side Full AXI4 Slave Port (64-bit)
    // =========================================================================
    // AW Channel
    input  logic [ID_WIDTH-1:0]  s_axi_awid,
    input  logic [31:0]          s_axi_awaddr,
    input  logic [7:0]           s_axi_awlen,
    input  logic [2:0]           s_axi_awsize,
    input  logic [1:0]           s_axi_awburst,
    input  logic [2:0]           s_axi_awprot,
    input  logic                 s_axi_awvalid,
    output logic                 s_axi_awready,

    // W Channel
    input  logic [63:0]          s_axi_wdata,
    input  logic [7:0]           s_axi_wstrb,
    input  logic                 s_axi_wlast,
    input  logic                 s_axi_wvalid,
    output logic                 s_axi_wready,

    // B Channel
    output logic [ID_WIDTH-1:0]  s_axi_bid,
    output logic [1:0]           s_axi_bresp,
    output logic                 s_axi_bvalid,
    input  logic                 s_axi_bready,

    // AR Channel
    input  logic [ID_WIDTH-1:0]  s_axi_arid,
    input  logic [31:0]          s_axi_araddr,
    input  logic [7:0]           s_axi_arlen,
    input  logic [2:0]           s_axi_arsize,
    input  logic [1:0]           s_axi_arburst,
    input  logic [2:0]           s_axi_arprot,
    input  logic                 s_axi_arvalid,
    output logic                 s_axi_arready,

    // R Channel
    output logic [ID_WIDTH-1:0]  s_axi_rid,
    output logic [63:0]          s_axi_rdata,
    output logic [1:0]           s_axi_rresp,
    output logic                 s_axi_rlast,
    output logic                 s_axi_rvalid,
    input  logic                 s_axi_rready,

    // =========================================================================
    // SoC-Side AXI4-Lite Master Port (32-bit)
    // =========================================================================
    // AW Channel
    output logic [31:0]          m_axil_awaddr,
    output logic [2:0]           m_axil_awprot,
    output logic                 m_axil_awvalid,
    input  logic                 m_axil_awready,

    // W Channel
    output logic [31:0]          m_axil_wdata,
    output logic [3:0]           m_axil_wstrb,
    output logic                 m_axil_wvalid,
    input  logic                 m_axil_wready,

    // B Channel
    input  logic [1:0]           m_axil_bresp,
    input  logic                 m_axil_bvalid,
    output logic                 m_axil_bready,

    // AR Channel
    output logic [31:0]          m_axil_araddr,
    output logic [2:0]           m_axil_arprot,
    output logic                 m_axil_arvalid,
    input  logic                 m_axil_arready,

    // R Channel
    input  logic [31:0]          m_axil_rdata,
    input  logic [1:0]           m_axil_rresp,
    input  logic                 m_axil_rvalid,
    output logic                 m_axil_rready
);

    // Worst-case response resolution: DECERR (3) > SLVERR (2) > OKAY (0)
    function automatic logic [1:0] worst_resp(input logic [1:0] r1, input logic [1:0] r2);
        if (r1 == 2'b11 || r2 == 2'b11) return 2'b11; // DECERR
        if (r1 == 2'b10 || r2 == 2'b10) return 2'b10; // SLVERR
        return 2'b00; // OKAY
    endfunction

    // =========================================================================
    // Write Path FSM (Section 6.4)
    // State machine: W_IDLE -> W_COLLECT -> W_ISSUE_LO -> W_ISSUE_HI -> W_BRESP
    // =========================================================================
    typedef enum logic [2:0] {
        W_IDLE,
        W_COLLECT,
        W_ISSUE_LO,
        W_WAIT_LO,
        W_ISSUE_HI,
        W_WAIT_HI,
        W_BRESP
    } w_fsm_t;

    w_fsm_t w_state;

    logic [ID_WIDTH-1:0] wr_id_q;
    logic [31:0]         wr_addr_q;
    logic [7:0]          wr_len_q;
    logic [2:0]          wr_size_q;
    logic [1:0]          wr_burst_q;
    logic [2:0]          wr_prot_q;
    logic [7:0]          wr_beat_cnt;

    logic [63:0]         wdata_q;
    logic [7:0]          wstrb_q;
    logic                wlast_q;
    logic [1:0]          bresp_acc;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state        <= W_IDLE;
            s_axi_awready  <= 1'b0;
            s_axi_wready   <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            s_axi_bid      <= '0;
            s_axi_bresp    <= 2'b00;
            m_axil_awvalid <= 1'b0;
            m_axil_wvalid  <= 1'b0;
            m_axil_bready  <= 1'b0;
            m_axil_awaddr  <= 32'h0;
            m_axil_awprot  <= 3'b000;
            m_axil_wdata   <= 32'h0;
            m_axil_wstrb   <= 4'h0;
            bresp_acc      <= 2'b00;
            wr_beat_cnt    <= 8'h0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    s_axi_awready <= 1'b1;
                    s_axi_wready  <= 1'b0;
                    s_axi_bvalid  <= 1'b0;
                    bresp_acc     <= 2'b00;
                    wr_beat_cnt   <= 8'h0;

                    if (s_axi_awvalid && s_axi_awready) begin
                        wr_id_q       <= s_axi_awid;
                        wr_addr_q     <= s_axi_awaddr;
                        wr_len_q      <= s_axi_awlen;
                        wr_size_q     <= s_axi_awsize;
                        wr_burst_q    <= s_axi_awburst;
                        wr_prot_q     <= s_axi_awprot;
                        s_axi_awready <= 1'b0;
                        s_axi_wready  <= 1'b1;
                        w_state       <= W_COLLECT;
                    end
                end

                W_COLLECT: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready  <= 1'b1;

                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wready <= 1'b0;
                        wdata_q      <= s_axi_wdata;
                        wstrb_q      <= s_axi_wstrb;
                        wlast_q      <= s_axi_wlast;

                        // Check if low word needs to be written
                        if (s_axi_wstrb[3:0] != 4'h0) begin
                            w_state <= W_ISSUE_LO;
                        end else if (s_axi_wstrb[7:4] != 4'h0) begin
                            w_state <= W_ISSUE_HI;
                        end else begin
                            // Both strobes 0 -> skip Lite write entirely
                            if (s_axi_wlast) begin
                                w_state <= W_BRESP;
                            end else begin
                                wr_beat_cnt  <= wr_beat_cnt + 1;
                                s_axi_wready <= 1'b1;
                                w_state      <= W_COLLECT;
                            end
                        end
                    end
                end

                W_ISSUE_LO: begin
                    // Compute current beat address
                    m_axil_awaddr  <= wr_addr_q + (wr_beat_cnt << 3);
                    m_axil_awprot  <= wr_prot_q;
                    m_axil_awvalid <= 1'b1;
                    m_axil_wdata   <= wdata_q[31:0];
                    m_axil_wstrb   <= wstrb_q[3:0];
                    m_axil_wvalid  <= 1'b1;
                    m_axil_bready  <= 1'b1;
                    w_state        <= W_WAIT_LO;
                end

                W_WAIT_LO: begin
                    if (m_axil_awready) m_axil_awvalid <= 1'b0;
                    if (m_axil_wready)  m_axil_wvalid  <= 1'b0;

                    if (m_axil_bvalid && m_axil_bready) begin
                        bresp_acc     <= worst_resp(bresp_acc, m_axil_bresp);
                        m_axil_bready <= 1'b0;

                        if (wstrb_q[7:4] != 4'h0) begin
                            w_state <= W_ISSUE_HI;
                        end else if (wlast_q) begin
                            w_state <= W_BRESP;
                        end else begin
                            wr_beat_cnt  <= wr_beat_cnt + 1;
                            s_axi_wready <= 1'b1;
                            w_state      <= W_COLLECT;
                        end
                    end
                end

                W_ISSUE_HI: begin
                    m_axil_awaddr  <= wr_addr_q + (wr_beat_cnt << 3) + 4;
                    m_axil_awprot  <= wr_prot_q;
                    m_axil_awvalid <= 1'b1;
                    m_axil_wdata   <= wdata_q[63:32];
                    m_axil_wstrb   <= wstrb_q[7:4];
                    m_axil_wvalid  <= 1'b1;
                    m_axil_bready  <= 1'b1;
                    w_state        <= W_WAIT_HI;
                end

                W_WAIT_HI: begin
                    if (m_axil_awready) m_axil_awvalid <= 1'b0;
                    if (m_axil_wready)  m_axil_wvalid  <= 1'b0;

                    if (m_axil_bvalid && m_axil_bready) begin
                        bresp_acc     <= worst_resp(bresp_acc, m_axil_bresp);
                        m_axil_bready <= 1'b0;

                        if (wlast_q) begin
                            w_state <= W_BRESP;
                        end else begin
                            wr_beat_cnt  <= wr_beat_cnt + 1;
                            s_axi_wready <= 1'b1;
                            w_state      <= W_COLLECT;
                        end
                    end
                end

                W_BRESP: begin
                    s_axi_bid    <= wr_id_q;
                    s_axi_bresp  <= bresp_acc;
                    s_axi_bvalid <= 1'b1;

                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid  <= 1'b0;
                        s_axi_awready <= 1'b1;
                        w_state       <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Read Path FSM (Section 6.3)
    // State machine: R_IDLE -> R_ISSUE_LO -> R_WAIT_LO -> R_ISSUE_HI -> R_WAIT_HI -> R_RESP
    // =========================================================================
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
                        needs_two_reads <= (s_axi_arsize >= 3); // 64-bit beat requires 2 Lite reads
                        s_axi_arready   <= 1'b0;
                        r_state         <= R_ISSUE_LO;
                    end
                end

                R_ISSUE_LO: begin
                    // Compute address for low word: addr + (beat_idx << rd_size_q)
                    logic [31:0] current_addr;
                    if (rd_burst_q == 2'b00) begin
                        current_addr = rd_addr_q; // FIXED
                    end else begin
                        current_addr = rd_addr_q + (beat_idx << rd_size_q); // INCR
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
                            // arsize < 3: replicate onto both lanes
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

