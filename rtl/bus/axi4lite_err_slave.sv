// SPDX-License-Identifier: Apache-2.0
// AXI4-Lite Decode Error Slave (axi4lite_err_slave)
// Consumes transactions to unmapped addresses and returns DECERR (2'b11)

`timescale 1ns/1ps

module axi4lite_err_slave (
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

    localparam logic [1:0] RESP_DECERR = 2'b11;

    // Write Channel FSM
    typedef enum logic [1:0] {
        W_IDLE,
        W_RESP
    } w_state_t;

    w_state_t w_state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            w_state   <= W_IDLE;
            s_awready <= 1'b0;
            s_wready  <= 1'b0;
            s_bvalid  <= 1'b0;
            s_bresp   <= RESP_DECERR;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (s_awvalid && s_wvalid) begin
                        s_awready <= 1'b1;
                        s_wready  <= 1'b1;
                        w_state   <= W_RESP;
                    end else begin
                        s_awready <= 1'b0;
                        s_wready  <= 1'b0;
                    end
                end

                W_RESP: begin
                    s_awready <= 1'b0;
                    s_wready  <= 1'b0;
                    if (!s_bvalid) begin
                        s_bvalid <= 1'b1;
                        s_bresp  <= RESP_DECERR;
                    end else if (s_bready) begin
                        s_bvalid <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end

                default: w_state <= W_IDLE;
            endcase
        end
    end

    // Read Channel FSM
    typedef enum logic [1:0] {
        R_IDLE,
        R_RESP
    } r_state_t;

    r_state_t r_state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            r_state   <= R_IDLE;
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
            s_rdata   <= 32'h0;
            s_rresp   <= RESP_DECERR;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (s_arvalid) begin
                        s_arready <= 1'b1;
                        r_state   <= R_RESP;
                    end else begin
                        s_arready <= 1'b0;
                    end
                end

                R_RESP: begin
                    s_arready <= 1'b0;
                    if (!s_rvalid) begin
                        s_rvalid <= 1'b1;
                        s_rdata  <= 32'h0;
                        s_rresp  <= RESP_DECERR;
                    end else if (s_rready) begin
                        s_rvalid <= 1'b0;
                        r_state  <= R_IDLE;
                    end
                end

                default: r_state <= R_IDLE;
            endcase
        end
    end

endmodule

