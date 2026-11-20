// ============================================================================
// Module Name: matrix_axi_regs
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: AXI4-Lite Slave Register Interface for Matrix Multiplier.
//              Provides memory-mapped control, status, dimension registers,
//              and direct buffer loading access for the RISC-V host CPU.
// ============================================================================

`timescale 1ns / 1ps

module matrix_axi_regs #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
)(
    input  wire                   s_axi_aclk,
    input  wire                   s_axi_aresetn,

    // AXI4-Lite Write Address Channel
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [2:0]             s_axi_awprot,
    input  wire                   s_axi_awvalid,
    output reg                    s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wvalid,
    output reg                    s_axi_wready,

    // AXI4-Lite Write Response Channel
    output reg  [1:0]             s_axi_bresp,
    output reg                    s_axi_bvalid,
    input  wire                   s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [2:0]             s_axi_arprot,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,

    // AXI4-Lite Read Data Channel
    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]             s_axi_rresp,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready,

    // Internal Control / Status Signals to Matrix Multiplier Core
    output reg                    ctrl_start,
    output reg                    ctrl_soft_reset,
    output reg  [7:0]             dim_m,
    output reg  [7:0]             dim_n,
    output reg  [7:0]             dim_k,
    output reg  [DATA_WIDTH-1:0]  base_in_addr,
    output reg  [DATA_WIDTH-1:0]  base_out_addr,

    input  wire                   status_done,
    input  wire                   status_busy,
    input  wire                   status_overflow,

    // Direct Buffer Access Ports
    output reg                    dir_in_wr_en,
    output reg  [7:0]             dir_in_wr_addr,
    output reg  [DATA_WIDTH-1:0]  dir_in_wr_data,

    output reg                    dir_w_wr_en,
    output reg  [9:0]             dir_w_wr_addr,
    output reg  [DATA_WIDTH-1:0]  dir_w_wr_data,

    output reg                    dir_bias_wr_en,
    output reg  [7:0]             dir_bias_wr_addr,
    output reg  [DATA_WIDTH-1:0]  dir_bias_wr_data,

    output reg  [7:0]             dir_out_rd_addr,
    input  wire [DATA_WIDTH-1:0]  dir_out_rd_data
);

    // Register Offsets
    localparam [ADDR_WIDTH-1:0]
        REG_CTRL          = 8'h00,
        REG_STATUS        = 8'h04,
        REG_DIM_M_N_K     = 8'h08,
        REG_BASE_IN_ADDR  = 8'h0C,
        REG_BASE_OUT_ADDR = 8'h10,
        REG_BUF_INDEX     = 8'h14,
        REG_IN_BUF_DATA   = 8'h20,
        REG_W_BUF_DATA    = 8'h24,
        REG_BIAS_BUF_DATA = 8'h28,
        REG_OUT_BUF_DATA  = 8'h2C;

    // Internal Registers
    reg [9:0] reg_buf_index;
    reg [ADDR_WIDTH-1:0] axi_awaddr;
    reg [ADDR_WIDTH-1:0] axi_araddr;

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
            dim_m           <= 8'd2;
            dim_n           <= 8'd1;
            dim_k           <= 8'd2;
            base_in_addr    <= 32'h0001_0000;
            base_out_addr   <= 32'h0001_0400;
            reg_buf_index   <= 10'd0;
            dir_in_wr_en    <= 1'b0;
            dir_in_wr_addr  <= 8'd0;
            dir_in_wr_data  <= 32'd0;
            dir_w_wr_en     <= 1'b0;
            dir_w_wr_addr   <= 10'd0;
            dir_w_wr_data   <= 32'd0;
            dir_bias_wr_en  <= 1'b0;
            dir_bias_wr_addr<= 8'd0;
            dir_bias_wr_data<= 32'd0;
        end else begin
            // Single-cycle self-clearing write strobes
            ctrl_start     <= 1'b0;
            dir_in_wr_en   <= 1'b0;
            dir_w_wr_en    <= 1'b0;
            dir_bias_wr_en <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    if (s_axi_awvalid && s_axi_wvalid) begin
                        s_axi_awready <= 1'b1;
                        s_axi_wready  <= 1'b1;
                        axi_awaddr    <= s_axi_awaddr;
                        wr_state      <= WR_RESP;

                        // Perform Register Write
                        case (s_axi_awaddr)
                            REG_CTRL: begin
                                ctrl_start      <= s_axi_wdata[0];
                                ctrl_soft_reset <= s_axi_wdata[1];
                            end
                            REG_DIM_M_N_K: begin
                                dim_k <= s_axi_wdata[7:0];
                                dim_n <= s_axi_wdata[15:8];
                                dim_m <= s_axi_wdata[23:16];
                            end
                            REG_BASE_IN_ADDR:  base_in_addr  <= s_axi_wdata;
                            REG_BASE_OUT_ADDR: base_out_addr <= s_axi_wdata;
                            REG_BUF_INDEX:     reg_buf_index <= s_axi_wdata[9:0];

                            // Direct memory load registers
                            REG_IN_BUF_DATA: begin
                                dir_in_wr_en   <= 1'b1;
                                dir_in_wr_addr <= reg_buf_index[7:0];
                                dir_in_wr_data <= s_axi_wdata;
                                reg_buf_index  <= reg_buf_index + 1'b1;
                            end
                            REG_W_BUF_DATA: begin
                                dir_w_wr_en   <= 1'b1;
                                dir_w_wr_addr <= reg_buf_index;
                                dir_w_wr_data <= s_axi_wdata;
                                reg_buf_index <= reg_buf_index + 1'b1;
                            end
                            REG_BIAS_BUF_DATA: begin
                                dir_bias_wr_en   <= 1'b1;
                                dir_bias_wr_addr <= reg_buf_index[7:0];
                                dir_bias_wr_data <= s_axi_wdata;
                                reg_buf_index    <= reg_buf_index + 1'b1;
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
                            end
                            REG_DIM_M_N_K: begin
                                dim_k <= s_axi_wdata[7:0];
                                dim_n <= s_axi_wdata[15:8];
                                dim_m <= s_axi_wdata[23:16];
                            end
                            REG_BASE_IN_ADDR:  base_in_addr  <= s_axi_wdata;
                            REG_BASE_OUT_ADDR: base_out_addr <= s_axi_wdata;
                            REG_BUF_INDEX:     reg_buf_index <= s_axi_wdata[9:0];

                            REG_IN_BUF_DATA: begin
                                dir_in_wr_en   <= 1'b1;
                                dir_in_wr_addr <= reg_buf_index[7:0];
                                dir_in_wr_data <= s_axi_wdata;
                                reg_buf_index  <= reg_buf_index + 1'b1;
                            end
                            REG_W_BUF_DATA: begin
                                dir_w_wr_en   <= 1'b1;
                                dir_w_wr_addr <= reg_buf_index;
                                dir_w_wr_data <= s_axi_wdata;
                                reg_buf_index <= reg_buf_index + 1'b1;
                            end
                            REG_BIAS_BUF_DATA: begin
                                dir_bias_wr_en   <= 1'b1;
                                dir_bias_wr_addr <= reg_buf_index[7:0];
                                dir_bias_wr_data <= s_axi_wdata;
                                reg_buf_index    <= reg_buf_index + 1'b1;
                            end
                            default: ;
                        endcase
                    end
                end

                WR_RESP: begin
                    s_axi_awready <= 1'b0;
                    s_axi_wready  <= 1'b0;
                    s_axi_bvalid  <= 1'b1;
                    s_axi_bresp   <= 2'b00; // OKAY

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
                        s_axi_arready <= 1'b1;
                        rd_state      <= RD_RESP;
                        dir_out_rd_addr <= reg_buf_index[7:0];

                        case (s_axi_araddr)
                            REG_CTRL:          s_axi_rdata <= {30'd0, ctrl_soft_reset, 1'b0};
                            REG_STATUS:        s_axi_rdata <= {29'd0, status_overflow, status_busy, status_done};
                            REG_DIM_M_N_K:     s_axi_rdata <= {8'd0, dim_m, dim_n, dim_k};
                            REG_BASE_IN_ADDR:  s_axi_rdata <= base_in_addr;
                            REG_BASE_OUT_ADDR: s_axi_rdata <= base_out_addr;
                            REG_BUF_INDEX:     s_axi_rdata <= {22'd0, reg_buf_index};
                            REG_OUT_BUF_DATA:  s_axi_rdata <= dir_out_rd_data;
                            default:           s_axi_rdata <= 32'hDEAD_BEEF;
                        endcase
                    end
                end

                RD_RESP: begin
                    s_axi_arready <= 1'b0;
                    s_axi_rvalid  <= 1'b1;
                    s_axi_rresp   <= 2'b00; // OKAY

                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state     <= RD_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
