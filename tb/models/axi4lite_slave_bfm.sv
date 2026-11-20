// SPDX-License-Identifier: Apache-2.0
// Reusable AXI4-Lite Slave BFM with controllable handshake delays
// Project: RISC-V Based SoC for Lightweight NN Inference Acceleration

`timescale 1ns/1ps

module axi4lite_slave_bfm #(
    parameter int DEPTH_WORDS = 1024
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
    input  logic        s_rready,

    // Control parameters for verification
    input  int          ready_delay = 0,
    input  logic [1:0]  force_bresp = 2'b00,
    input  logic [1:0]  force_rresp = 2'b00
);

    logic [31:0] mem [0:DEPTH_WORDS-1];

    // Write path
    typedef enum logic [1:0] {WS_IDLE, WS_DELAY, WS_RESP} ws_state_t;
    ws_state_t ws_state;
    int ws_cnt;
    logic [31:0] latched_awaddr;
    logic [31:0] latched_wdata;
    logic [3:0]  latched_wstrb;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            ws_state  <= WS_IDLE;
            s_awready <= 1'b0;
            s_wready  <= 1'b0;
            s_bvalid  <= 1'b0;
            s_bresp   <= 2'b00;
            ws_cnt    <= 0;
        end else begin
            case (ws_state)
                WS_IDLE: begin
                    if (s_awvalid && s_wvalid) begin
                        latched_awaddr <= s_awaddr;
                        latched_wdata  <= s_wdata;
                        latched_wstrb  <= s_wstrb;
                        if (ready_delay == 0) begin
                            s_awready <= 1'b1;
                            s_wready  <= 1'b1;
                            ws_state  <= WS_RESP;
                        end else begin
                            ws_cnt   <= ready_delay;
                            ws_state <= WS_DELAY;
                        end
                    end
                end

                WS_DELAY: begin
                    if (ws_cnt > 1) begin
                        ws_cnt <= ws_cnt - 1;
                    end else begin
                        s_awready <= 1'b1;
                        s_wready  <= 1'b1;
                        ws_state  <= WS_RESP;
                    end
                end

                WS_RESP: begin
                    s_awready <= 1'b0;
                    s_wready  <= 1'b0;
                    if (!s_bvalid) begin
                        s_bvalid <= 1'b1;
                        s_bresp  <= force_bresp;
                        if (latched_wstrb[0]) mem[(latched_awaddr >> 2) % DEPTH_WORDS][7:0]   <= latched_wdata[7:0];
                        if (latched_wstrb[1]) mem[(latched_awaddr >> 2) % DEPTH_WORDS][15:8]  <= latched_wdata[15:8];
                        if (latched_wstrb[2]) mem[(latched_awaddr >> 2) % DEPTH_WORDS][23:16] <= latched_wdata[23:16];
                        if (latched_wstrb[3]) mem[(latched_awaddr >> 2) % DEPTH_WORDS][31:24] <= latched_wdata[31:24];
                    end else if (s_bready) begin
                        s_bvalid <= 1'b0;
                        ws_state <= WS_IDLE;
                    end
                end
            endcase
        end
    end

    // Read path
    typedef enum logic [1:0] {RS_IDLE, RS_DELAY, RS_RESP} rs_state_t;
    rs_state_t rs_state;
    int rs_cnt;
    logic [31:0] latched_araddr;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rs_state  <= RS_IDLE;
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= 32'b0;
            s_rresp   <= 2'b00;
            rs_cnt    <= 0;
        end else begin
            case (rs_state)
                RS_IDLE: begin
                    if (s_arvalid) begin
                        latched_araddr <= s_araddr;
                        if (ready_delay == 0) begin
                            s_arready <= 1'b1;
                            rs_state  <= RS_RESP;
                        end else begin
                            rs_cnt   <= ready_delay;
                            rs_state <= RS_DELAY;
                        end
                    end
                end

                RS_DELAY: begin
                    if (rs_cnt > 1) begin
                        rs_cnt <= rs_cnt - 1;
                    end else begin
                        s_arready <= 1'b1;
                        rs_state  <= RS_RESP;
                    end
                end

                RS_RESP: begin
                    s_arready <= 1'b0;
                    if (!s_rvalid) begin
                        s_rvalid <= 1'b1;
                        s_rdata  <= mem[(latched_araddr >> 2) % DEPTH_WORDS];
                        s_rresp  <= force_rresp;
                    end else if (s_rready) begin
                        s_rvalid <= 1'b0;
                        rs_state <= RS_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
