// SPDX-License-Identifier: Apache-2.0
// General Purpose Input/Output (gpio)
// Compliant with Section 8.6 of VeeR EL2 SoC Specification v2.0

`timescale 1ns/1ps

module gpio #(
    parameter int NGPIO = 16
)(
    input  logic                 aclk,
    input  logic                 aresetn,

    // AXI4-Lite Slave Port
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

    // External Pins
    input  logic [NGPIO-1:0]     gpio_in,
    output logic [NGPIO-1:0]     gpio_out,
    output logic [NGPIO-1:0]     gpio_oe,
    output logic                 irq
);

    // Register interface signals from shim
    logic [5:0]  reg_waddr;
    logic [31:0] reg_wdata;
    logic        reg_wen;
    logic [5:0]  reg_raddr;
    logic        reg_ren;
    logic [31:0] reg_rdata;
    logic        reg_err;

    assign reg_err = 1'b0;

    axi4lite_regif #(
        .ADDR_LSB(2),
        .REG_BITS(6)
    ) u_regif (
        .aclk     (aclk),
        .aresetn  (aresetn),
        .s_awaddr (s_awaddr),
        .s_awprot (s_awprot),
        .s_awvalid(s_awvalid),
        .s_awready(s_awready),
        .s_wdata  (s_wdata),
        .s_wstrb  (s_wstrb),
        .s_wvalid (s_wvalid),
        .s_wready (s_wready),
        .s_bresp  (s_bresp),
        .s_bvalid (s_bvalid),
        .s_bready (s_bready),
        .s_araddr (s_araddr),
        .s_arprot (s_arprot),
        .s_arvalid(s_arvalid),
        .s_arready(s_arready),
        .s_rdata  (s_rdata),
        .s_rresp  (s_rresp),
        .s_rvalid (s_rvalid),
        .s_rready (s_rready),
        .reg_waddr(reg_waddr),
        .reg_wdata(reg_wdata),
        .reg_wen  (reg_wen),
        .reg_raddr(reg_raddr),
        .reg_ren  (reg_ren),
        .reg_rdata(reg_rdata),
        .reg_err  (reg_err)
    );

    // Registers
    logic [NGPIO-1:0] data_out_q;
    logic [NGPIO-1:0] dir_q;
    logic [NGPIO-1:0] irq_mask_q;
    logic [NGPIO-1:0] irq_edge_q;
    logic [NGPIO-1:0] irq_stat_q;

    // Synchronizer for input pins (2-FF)
    logic [NGPIO-1:0] sync_ff1, sync_ff2, sync_ff2_d1;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            sync_ff1    <= '0;
            sync_ff2    <= '0;
            sync_ff2_d1 <= '0;
        end else begin
            sync_ff1    <= gpio_in;
            sync_ff2    <= sync_ff1;
            sync_ff2_d1 <= sync_ff2;
        end
    end

    assign gpio_out = data_out_q;
    assign gpio_oe  = dir_q;

    // Interrupt calculation
    assign irq = |(irq_stat_q & irq_mask_q);

    // Interrupt detection & register updates
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            data_out_q <= '0;
            dir_q      <= '0;
            irq_mask_q <= '0;
            irq_edge_q <= '0;
            irq_stat_q <= '0;
        end else begin
            // Register writes
            if (reg_wen) begin
                case (reg_waddr)
                    6'd0: data_out_q <= reg_wdata[NGPIO-1:0]; // 0x00: DATA_OUT
                    6'd2: dir_q      <= reg_wdata[NGPIO-1:0]; // 0x08: DIR
                    6'd3: irq_mask_q <= reg_wdata[NGPIO-1:0]; // 0x0C: IRQ_MASK
                    6'd4: irq_edge_q <= reg_wdata[NGPIO-1:0]; // 0x10: IRQ_EDGE
                    6'd5: begin // 0x14: IRQ_STAT (W1C)
                        irq_stat_q <= irq_stat_q & ~reg_wdata[NGPIO-1:0];
                    end
                    default: ;
                endcase
            end

            // Detect interrupts per bit
            for (int i = 0; i < NGPIO; i++) begin
                if (irq_mask_q[i]) begin
                    if (irq_edge_q[i]) begin
                        // Rising edge
                        if (sync_ff2[i] && !sync_ff2_d1[i]) begin
                            irq_stat_q[i] <= 1'b1;
                        end
                    end else begin
                        // Level high
                        if (sync_ff2[i]) begin
                            irq_stat_q[i] <= 1'b1;
                        end
                    end
                end
            end
        end
    end

    // Read mux
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            reg_rdata <= 32'h0;
        end else if (reg_ren) begin
            case (reg_raddr)
                6'd0: reg_rdata <= {16'b0, data_out_q};
                6'd1: reg_rdata <= {16'b0, sync_ff2}; // DATA_IN
                6'd2: reg_rdata <= {16'b0, dir_q};
                6'd3: reg_rdata <= {16'b0, irq_mask_q};
                6'd4: reg_rdata <= {16'b0, irq_edge_q};
                6'd5: reg_rdata <= {16'b0, irq_stat_q};
                default: reg_rdata <= 32'h0;
            endcase
        end
    end

endmodule

