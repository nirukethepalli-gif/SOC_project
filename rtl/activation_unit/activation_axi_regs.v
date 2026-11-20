// ============================================================================
// Module Name: activation_axi_regs
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: AXI4-Lite Slave Register Interface for Activation Unit IP.
//              Registers:
//                0x00: CTRL (start, reset, func_sel: 00=ReLU, 01=Sigmoid, 10=Tanh)
//                0x04: STATUS (done, busy)
//                0x08: VEC_LEN (vector length)
//                0x0C: OUT_ADDR (output buffer / memory address)
//                0x14: BUF_INDEX (index for direct memory access)
//                0x20: IN_DATA (direct push into input buffer)
//                0x24: OUT_DATA (direct read from activated output buffer)
// ============================================================================

`timescale 1ns / 1ps

module activation_axi_regs #(
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

    // Control and Configuration Signals to Core
    output reg                    ctrl_start,
    output reg                    ctrl_soft_reset,
    output reg  [1:0]             func_sel,
    output reg  [15:0]            vec_len,
    output reg  [DATA_WIDTH-1:0]  out_addr,

    input  wire                   status_done,
    input  wire                   status_busy,

    // Direct Access Interface
    output reg                    dir_in_wr_en,
    output reg  [7:0]             dir_in_wr_addr,
    output reg  [DATA_WIDTH-1:0]  dir_in_wr_data,

    output reg  [7:0]             dir_out_rd_addr,
    input  wire [DATA_WIDTH-1:0]  dir_out_rd_data
);

    localparam [ADDR_WIDTH-1:0]
        REG_CTRL      = 8'h00,
        REG_STATUS    = 8'h04,
        REG_VEC_LEN   = 8'h08,
        REG_OUT_ADDR  = 8'h0C,
        REG_BUF_INDEX = 8'h14,
        REG_IN_DATA   = 8'h20,
        REG_OUT_DATA  = 8'h24;

    reg [7:0] reg_buf_index;
    reg [ADDR_WIDTH-1:0] axi_awaddr;

    // -------------------------------------------------------------------------
    // AXI4-Lite Write Channel FSM
    // -------------------------------------------------------------------------
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
            func_sel        <= 2'b00; // ReLU default
            vec_len         <= 16'd2;
            out_addr        <= 32'h0001_0400;
            reg_buf_index   <= 8'd0;
            dir_in_wr_en    <= 1'b0;
            dir_in_wr_addr  <= 8'd0;
            dir_in_wr_data  <= 32'd0;
        end else begin
            ctrl_start   <= 1'b0;
            dir_in_wr_en <= 1'b0;

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
                                func_sel        <= s_axi_wdata[3:2];
                            end
                            REG_VEC_LEN:   vec_len       <= s_axi_wdata[15:0];
                            REG_OUT_ADDR:  out_addr      <= s_axi_wdata;
                            REG_BUF_INDEX: reg_buf_index <= s_axi_wdata[7:0];
                            REG_IN_DATA: begin
                                dir_in_wr_en   <= 1'b1;
                                dir_in_wr_addr <= reg_buf_index;
                                dir_in_wr_data <= s_axi_wdata;
                                reg_buf_index  <= reg_buf_index + 1'b1;
                            end
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
                                func_sel        <= s_axi_wdata[3:2];
                            end
                            REG_VEC_LEN:   vec_len       <= s_axi_wdata[15:0];
                            REG_OUT_ADDR:  out_addr      <= s_axi_wdata;
                            REG_BUF_INDEX: reg_buf_index <= s_axi_wdata[7:0];
                            REG_IN_DATA: begin
                                dir_in_wr_en   <= 1'b1;
                                dir_in_wr_addr <= reg_buf_index;
                                dir_in_wr_data <= s_axi_wdata;
                                reg_buf_index  <= reg_buf_index + 1'b1;
                            end
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

    // -------------------------------------------------------------------------
    // AXI4-Lite Read Channel FSM
    // -------------------------------------------------------------------------
    localparam RD_IDLE = 1'b0, RD_RESP = 1'b1;
    reg rd_state;

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            rd_state        <= RD_IDLE;
            s_axi_arready   <= 1'b0;
            s_axi_rvalid    <= 1'b0;
            s_axi_rresp     <= 2'b00;
            s_axi_rdata     <= {DATA_WIDTH{1'b0}};
            dir_out_rd_addr <= 8'd0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_axi_arvalid) begin
                        s_axi_arready   <= 1'b1;
                        rd_state        <= RD_RESP;
                        dir_out_rd_addr <= reg_buf_index;

                        case (s_axi_araddr)
                            REG_CTRL:      s_axi_rdata <= {28'd0, func_sel, ctrl_soft_reset, 1'b0};
                            REG_STATUS:    s_axi_rdata <= {30'd0, status_busy, status_done};
                            REG_VEC_LEN:   s_axi_rdata <= {16'd0, vec_len};
                            REG_OUT_ADDR:  s_axi_rdata <= out_addr;
                            REG_BUF_INDEX: s_axi_rdata <= {24'd0, reg_buf_index};
                            REG_OUT_DATA:  s_axi_rdata <= dir_out_rd_data;
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
