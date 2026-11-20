// SPDX-License-Identifier: Apache-2.0
// Synchronous Single-Port AXI4-Lite SRAM (DMEM) per Section 6.7 of SoC Specification v2.0

`timescale 1ns/1ps

module axi4lite_sram #(
    parameter int DEPTH_WORDS = 8192 // 32 KB
)(
    input  logic        aclk,
    input  logic        aresetn,

    // AXI4-Lite Slave Port
    input  logic [31:0] s_awaddr,
    input  logic [2:0]  s_awprot,
    input  logic        s_awvalid,
    output logic        s_awready,

    input  logic [31:0] s_wdata,
    input  logic [3:0]  s_wstrb,
    input  logic        s_wvalid,
    output logic        s_wready,

    output logic [1:0]  s_bresp,
    output logic        s_bvalid,
    input  logic        s_bready,

    input  logic [31:0] s_araddr,
    input  logic [2:0]  s_arprot,
    input  logic        s_arvalid,
    output logic        s_arready,

    output logic [31:0] s_rdata,
    output logic [1:0]  s_rresp,
    output logic        s_rvalid,
    input  logic        s_rready
);

    localparam int ADDR_BITS = $clog2(DEPTH_WORDS);

    // Memory array
    logic [31:0] mem [0:DEPTH_WORDS-1];

    // =========================================================================
    // Write Channel
    // =========================================================================
    typedef enum logic [1:0] {WS_IDLE, WS_RESP} ws_state_t;
    ws_state_t ws_state;

    wire write_start = s_awvalid && s_wvalid && (ws_state == WS_IDLE);

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ws_state  <= WS_IDLE;
            s_awready <= 1'b0;
            s_wready  <= 1'b0;
            s_bvalid  <= 1'b0;
            s_bresp   <= 2'b00;
        end else begin
            case (ws_state)
                WS_IDLE: begin
                    if (s_awvalid && s_wvalid) begin
                        s_awready <= 1'b1;
                        s_wready  <= 1'b1;
                        ws_state  <= WS_RESP;

                        // Byte-lane writes
                        if (s_wstrb[0]) mem[s_awaddr[2 +: ADDR_BITS]][7:0]   <= s_wdata[7:0];
                        if (s_wstrb[1]) mem[s_awaddr[2 +: ADDR_BITS]][15:8]  <= s_wdata[15:8];
                        if (s_wstrb[2]) mem[s_awaddr[2 +: ADDR_BITS]][23:16] <= s_wdata[23:16];
                        if (s_wstrb[3]) mem[s_awaddr[2 +: ADDR_BITS]][31:24] <= s_wdata[31:24];
                    end else begin
                        s_awready <= 1'b0;
                        s_wready  <= 1'b0;
                    end
                end

                WS_RESP: begin
                    s_awready <= 1'b0;
                    s_wready  <= 1'b0;
                    if (!s_bvalid) begin
                        s_bvalid <= 1'b1;
                        s_bresp  <= 2'b00; // OKAY
                    end else if (s_bready) begin
                        s_bvalid <= 1'b0;
                        ws_state <= WS_IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // Read Channel (1-cycle synchronous latency)
    // =========================================================================
    typedef enum logic [1:0] {RS_IDLE, RS_WAIT, RS_RESP} rs_state_t;
    rs_state_t rs_state;

    logic [ADDR_BITS-1:0] rd_addr_q;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rs_state  <= RS_IDLE;
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= 32'b0;
            s_rresp   <= 2'b00;
            rd_addr_q <= '0;
        end else begin
            case (rs_state)
                RS_IDLE: begin
                    if (s_arvalid) begin
                        s_arready <= 1'b1;
                        rd_addr_q <= s_araddr[2 +: ADDR_BITS];
                        rs_state  <= RS_WAIT;
                    end else begin
                        s_arready <= 1'b0;
                    end
                end

                RS_WAIT: begin
                    s_arready <= 1'b0;
                    s_rdata   <= mem[rd_addr_q];
                    s_rresp   <= 2'b00;
                    s_rvalid  <= 1'b1;
                    rs_state  <= RS_RESP;
                end

                RS_RESP: begin
                    if (s_rready) begin
                        s_rvalid <= 1'b0;
                        rs_state <= RS_IDLE;
                    end
                end
            endcase
        end
    end

    // Preload task for testbench
    task automatic preload(input string hexfile);
        $readmemh(hexfile, mem);
    endtask

endmodule

