// ============================================================================
// Module Name: dma_registers
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: AXI4-Lite Slave Register File for DMA Controller.
//              Registers:
//                0x00: CTRL (start, soft_reset, direction: 0=Mem->Acc, 1=Acc->Mem,
//                            acc_target: 00=In_Buf, 01=W_Buf, 10=Bias_Buf, 11=Act_Out)
//                0x04: STATUS (done, busy, error)
//                0x08: SRC_ADDR (source memory base address)
//                0x0C: DST_ADDR (destination memory base address)
//                0x10: BURST_LEN (number of 32-bit words to transfer)
// ============================================================================

`timescale 1ns / 1ps

module dma_registers #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
)(
    input  wire                   s_axi_aclk,
    input  wire                   s_axi_aresetn,

    // AXI4-Lite Write Channels
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [2:0]             s_axi_awprot,
    input  wire                   s_axi_awvalid,
    output reg                    s_axi_awready,

    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wvalid,
    output reg                    s_axi_wready,

    output reg  [1:0]             s_axi_bresp,
    output reg                    s_axi_bvalid,
    input  wire                   s_axi_bready,

    // AXI4-Lite Read Channels
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [2:0]             s_axi_arprot,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,

    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]             s_axi_rresp,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready,

    // Internal Control Signals to DMA Transfer Engine
    output reg                    ctrl_start,
    output reg                    ctrl_soft_reset,
    output reg                    direction,     // 0: Mem->Acc, 1: Acc->Mem
    output reg  [1:0]             acc_target,    // 00: In_Buf, 01: W_Buf, 10: Bias_Buf, 11: Act_Out
    output reg  [DATA_WIDTH-1:0]  src_addr,
    output reg  [DATA_WIDTH-1:0]  dst_addr,
    output reg  [15:0]            burst_len,

    input  wire                   status_done,
    input  wire                   status_busy,
    input  wire                   status_error
);

    localparam [ADDR_WIDTH-1:0]
        REG_CTRL      = 8'h00,
        REG_STATUS    = 8'h04,
        REG_SRC_ADDR  = 8'h08,
        REG_DST_ADDR  = 8'h0C,
        REG_BURST_LEN = 8'h10;

    reg [ADDR_WIDTH-1:0] axi_awaddr;

    // AXI4-Lite Write Channel FSM
    localparam [1:0] WR_IDLE = 2'b00, WR_DATA = 2'b01, WR_RESP = 2'b10;
    reg [1:0] wr_state;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            wr_state        <= WR_IDLE;
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= 2'b00;
            axi_awaddr      <= {ADDR_WIDTH{1'b0}};
            ctrl_start      <= 1'b0;
            ctrl_soft_reset <= 1'b0;
            direction       <= 1'b0;
            acc_target      <= 2'b00;
            src_addr        <= 32'h0001_0000;
            dst_addr        <= 32'h0001_0400;
            burst_len       <= 16'd4;
        end else begin
            ctrl_start <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        axi_awaddr    <= s_axi_awaddr;
                        wr_state      <= WR_RESP;

                        case (s_axi_awaddr)
                            REG_CTRL: begin
                                ctrl_start      <= s_axi_wdata[0];
                                ctrl_soft_reset <= s_axi_wdata[1];
                                direction       <= s_axi_wdata[2];
                                acc_target      <= s_axi_wdata[4:3];
                            end
                            REG_SRC_ADDR:  src_addr  <= s_axi_wdata;
                            REG_DST_ADDR:  dst_addr  <= s_axi_wdata;
                            REG_BURST_LEN: burst_len <= s_axi_wdata[15:0];
                            default: ;
                        endcase
                    end else if (s_axi_awvalid) begin
                        s_axi_awready <= 1'b1;
                        axi_awaddr    <= s_axi_awaddr;
                        wr_state      <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    s_axi_awready <= 1'b0;
                    if (s_axi_wvalid) begin
                        s_axi_wready <= 1'b1;
                        wr_state     <= WR_RESP;

                        case (axi_awaddr)
                            REG_CTRL: begin
                                ctrl_start      <= s_axi_wdata[0];
                                ctrl_soft_reset <= s_axi_wdata[1];
                                direction       <= s_axi_wdata[2];
                                acc_target      <= s_axi_wdata[4:3];
                            end
                            REG_SRC_ADDR:  src_addr  <= s_axi_wdata;
                            REG_DST_ADDR:  dst_addr  <= s_axi_wdata;
                            REG_BURST_LEN: burst_len <= s_axi_wdata[15:0];
                            default: ;
                        endcase
                    end
                end

                WR_RESP: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready  <= 1'b0;
                    s_axi_bvalid  <= 1'b1;
                    s_axi_bresp   <= 2'b00;

                    if (s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        wr_state     <= WR_IDLE;
                    end
                end
            endcase
        end
    end

    // AXI4-Lite Read Channel FSM
    localparam RD_IDLE = 1'b0, RD_RESP = 1'b1;
    reg rd_state;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            rd_state      <= RD_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= {DATA_WIDTH{1'b0}};
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_axi_arvalid) begin
                        s_axi_arready <= 1'b1;
                        rd_state      <= RD_RESP;

                        case (s_axi_araddr)
                            REG_CTRL:      s_axi_rdata <= {27'd0, acc_target, direction, ctrl_soft_reset, 1'b0};
                            REG_STATUS:    s_axi_rdata <= {29'd0, status_error, status_busy, status_done};
                            REG_SRC_ADDR:  s_axi_rdata <= src_addr;
                            REG_DST_ADDR:  s_axi_rdata <= dst_addr;
                            REG_BURST_LEN: s_axi_rdata <= {16'd0, burst_len};
                            default:       s_axi_rdata <= 32'hDEAD_BEEF;
                        endcase
                    end
                end

                RD_RESP: begin
                    s_axi_arready <= 1'b0;
                    s_axi_rvalid  <= 1'b1;
                    s_axi_rresp   <= 2'b00;

                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state     <= RD_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
