// SPDX-License-Identifier: Apache-2.0
// Synchronous Dual-Port AXI4-Lite SRAM (IMEM) per Section 6.7 of SoC Specification v2.0
// Port A: Read-Only (served to IFU Bridge)
// Port B: Read-Write (served to LSU Interconnect)

`timescale 1ns/1ps

module axi4lite_sram_dp #(
    parameter int DEPTH_WORDS = 8192 // 32 KB
)(
    input  logic        aclk,
    input  logic        aresetn,

    // =========================================================================
    // Port A: Read-Only (IFU)
    // =========================================================================
    input  logic [31:0] s_a_araddr,
    input  logic [2:0]  s_a_arprot,
    input  logic        s_a_arvalid,
    output logic        s_a_arready,

    output logic [31:0] s_a_rdata,
    output logic [1:0]  s_a_rresp,
    output logic        s_a_rvalid,
    input  logic        s_a_rready,

    // =========================================================================
    // Port B: Read-Write (Interconnect)
    // =========================================================================
    input  logic [31:0] s_b_awaddr,
    input  logic [2:0]  s_b_awprot,
    input  logic        s_b_awvalid,
    output logic        s_b_awready,

    input  logic [31:0] s_b_wdata,
    input  logic [3:0]  s_b_wstrb,
    input  logic        s_b_wvalid,
    output logic        s_b_wready,

    output logic [1:0]  s_b_bresp,
    output logic        s_b_bvalid,
    input  logic        s_b_bready,

    input  logic [31:0] s_b_araddr,
    input  logic [2:0]  s_b_arprot,
    input  logic        s_b_arvalid,
    output logic        s_b_arready,

    output logic [31:0] s_b_rdata,
    output logic [1:0]  s_b_rresp,
    output logic        s_b_rvalid,
    input  logic        s_b_rready
);

    localparam int ADDR_BITS = $clog2(DEPTH_WORDS);

    // Shared dual-port memory array
    logic [31:0] mem [0:DEPTH_WORDS-1];

    // =========================================================================
    // Port A Read Channel
    // =========================================================================
    typedef enum logic [1:0] {A_IDLE, A_WAIT, A_RESP} a_state_t;
    a_state_t a_state;
    logic [ADDR_BITS-1:0] a_rd_addr_q;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            a_state     <= A_IDLE;
            s_a_arready <= 1'b0;
            s_a_rvalid  <= 1'b0;
            s_a_rdata   <= 32'b0;
            s_a_rresp   <= 2'b00;
            a_rd_addr_q <= '0;
        end else begin
            case (a_state)
                A_IDLE: begin
                    if (s_a_arvalid) begin
                        s_a_arready <= 1'b1;
                        a_rd_addr_q <= s_a_araddr[2 +: ADDR_BITS];
                        a_state     <= A_WAIT;
                    end else begin
                        s_a_arready <= 1'b0;
                    end
                end

                A_WAIT: begin
                    s_a_arready <= 1'b0;
                    s_a_rdata   <= mem[a_rd_addr_q];
                    s_a_rresp   <= 2'b00;
                    s_a_rvalid  <= 1'b1;
                    a_state     <= A_RESP;
                end

                A_RESP: begin
                    if (s_a_rready) begin
                        s_a_rvalid <= 1'b0;
                        a_state    <= A_IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // Port B Write Channel
    // =========================================================================
    typedef enum logic [1:0] {BW_IDLE, BW_RESP} bw_state_t;
    bw_state_t bw_state;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            bw_state    <= BW_IDLE;
            s_b_awready <= 1'b0;
            s_b_wready  <= 1'b0;
            s_b_bvalid  <= 1'b0;
            s_b_bresp   <= 2'b00;
        end else begin
            case (bw_state)
                BW_IDLE: begin
                    if (s_b_awvalid && s_b_wvalid) begin
                        s_b_awready <= 1'b1;
                        s_b_wready  <= 1'b1;
                        bw_state    <= BW_RESP;

                        if (s_b_wstrb[0]) mem[s_b_awaddr[2 +: ADDR_BITS]][7:0]   <= s_b_wdata[7:0];
                        if (s_b_wstrb[1]) mem[s_b_awaddr[2 +: ADDR_BITS]][15:8]  <= s_b_wdata[15:8];
                        if (s_b_wstrb[2]) mem[s_b_awaddr[2 +: ADDR_BITS]][23:16] <= s_b_wdata[23:16];
                        if (s_b_wstrb[3]) mem[s_b_awaddr[2 +: ADDR_BITS]][31:24] <= s_b_wdata[31:24];
                    end else begin
                        s_b_awready <= 1'b0;
                        s_b_wready  <= 1'b0;
                    end
                end

                BW_RESP: begin
                    s_b_awready <= 1'b0;
                    s_b_wready  <= 1'b0;
                    if (!s_b_bvalid) begin
                        s_b_bvalid <= 1'b1;
                        s_b_bresp  <= 2'b00;
                    end else if (s_b_bready) begin
                        s_b_bvalid <= 1'b0;
                        bw_state   <= BW_IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // Port B Read Channel
    // =========================================================================
    typedef enum logic [1:0] {BR_IDLE, BR_WAIT, BR_RESP} br_state_t;
    br_state_t br_state;
    logic [ADDR_BITS-1:0] b_rd_addr_q;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            br_state    <= BR_IDLE;
            s_b_arready <= 1'b0;
            s_b_rvalid  <= 1'b0;
            s_b_rdata   <= 32'b0;
            s_b_rresp   <= 2'b00;
            b_rd_addr_q <= '0;
        end else begin
            case (br_state)
                BR_IDLE: begin
                    if (s_b_arvalid) begin
                        s_b_arready <= 1'b1;
                        b_rd_addr_q <= s_b_araddr[2 +: ADDR_BITS];
                        br_state    <= BR_WAIT;
                    end else begin
                        s_b_arready <= 1'b0;
                    end
                end

                BR_WAIT: begin
                    s_b_arready <= 1'b0;
                    s_b_rdata   <= mem[b_rd_addr_q];
                    s_b_rresp   <= 2'b00;
                    s_b_rvalid  <= 1'b1;
                    br_state    <= BR_RESP;
                end

                BR_RESP: begin
                    if (s_b_rready) begin
                        s_b_rvalid <= 1'b0;
                        br_state   <= BR_IDLE;
                    end
                end
            endcase
        end
    end

    // Preload task
    task automatic preload(input string hexfile);
        $readmemh(hexfile, mem);
    endtask

endmodule

