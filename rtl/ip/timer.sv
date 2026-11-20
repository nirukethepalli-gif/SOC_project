// SPDX-License-Identifier: Apache-2.0
// RISC-V 64-bit Machine Timer (timer)
// Compliant with Section 8.5 of VeeR EL2 SoC Specification v2.0

`timescale 1ns/1ps

module timer (
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

    // Interrupts
    output logic                 timer_int, // Connects directly to core timer_int
    output logic                 irq        // Connects to PIC extintsrc_req[2]
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

    // 64-bit mtime and mtimecmp registers
    logic [63:0] mtime;
    logic [63:0] mtimecmp;

    // Control & Prescaler
    logic        ctrl_en;
    logic        ctrl_timer_irq_en;
    logic [31:0] prescale;
    logic [31:0] pre_cnt;

    // Core machine timer interrupt
    assign timer_int = (mtime >= mtimecmp) && ctrl_en;
    assign irq       = timer_int && ctrl_timer_irq_en;

    wire tick = (pre_cnt >= prescale);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            mtime             <= 64'h0;
            mtimecmp          <= 64'hFFFF_FFFF_FFFF_FFFF;
            ctrl_en           <= 1'b1;
            ctrl_timer_irq_en <= 1'b0;
            prescale          <= 32'd49;
            pre_cnt           <= 32'd0;
        end else begin
            // Register writes
            if (reg_wen) begin
                case (reg_waddr)
                    6'd0: mtime[31:0]          <= reg_wdata;
                    6'd1: mtime[63:32]         <= reg_wdata;
                    6'd2: mtimecmp[31:0]       <= reg_wdata;
                    6'd3: mtimecmp[63:32]      <= reg_wdata;
                    6'd4: begin // CTRL (0x10)
                        ctrl_en           <= reg_wdata[0];
                        ctrl_timer_irq_en <= reg_wdata[1];
                    end
                    6'd5: prescale <= reg_wdata; // PRESCALE (0x14)
                    default: ;
                endcase
            end

            // Free-running timer increment
            if (ctrl_en) begin
                if (tick) begin
                    pre_cnt <= 32'd0;
                    mtime   <= mtime + 1;
                end else begin
                    pre_cnt <= pre_cnt + 1;
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
                6'd0: reg_rdata <= mtime[31:0];
                6'd1: reg_rdata <= mtime[63:32];
                6'd2: reg_rdata <= mtimecmp[31:0];
                6'd3: reg_rdata <= mtimecmp[63:32];
                6'd4: reg_rdata <= {30'b0, ctrl_timer_irq_en, ctrl_en};
                6'd5: reg_rdata <= prescale;
                default: reg_rdata <= 32'h0;
            endcase
        end
    end

endmodule

