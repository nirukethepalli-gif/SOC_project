// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// Module Name: dma_controller
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Base Addr:   0x8000_3000
// Description: Custom IP 3: Autonomous Direct Memory Access Engine.
//              Transfers weight matrices, input vectors, and biases between
//              Data Memory (0x1000_0000) and Matrix Multiplier buffers, and
//              writes activated output vectors back to memory.
//              Features:
//                - AXI4-Lite Slave Interface (0x8000_3000) for CPU programming
//                - AXI4 Master Memory Interface for high-speed burst data transfers
//                - Automatic 32-bit linear address incrementing (+4 bytes)
//                - Misalignment error reporting and completion IRQ
// ============================================================================

`timescale 1ns/1ps

module dma_controller #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32
)(
    input  logic                   aclk,
    input  logic                   aresetn,

    // AXI4-Lite Slave Interface (Base 0x8000_3000)
    input  logic [31:0]            s_awaddr,
    input  logic [2:0]             s_awprot,
    input  logic                   s_awvalid,
    output logic                   s_awready,

    input  logic [31:0]            s_wdata,
    input  logic [3:0]             s_wstrb,
    input  logic                   s_wvalid,
    output logic                   s_wready,

    output logic [1:0]             s_bresp,
    output logic                   s_bvalid,
    input  logic                   s_bready,

    input  logic [31:0]            s_araddr,
    input  logic [2:0]             s_arprot,
    input  logic                   s_arvalid,
    output logic                   s_arready,

    output logic [31:0]            s_rdata,
    output logic [1:0]             s_rresp,
    output logic                   s_rvalid,
    input  logic                   s_rready,

    // AXI4 Master Read Channel (Memory Fetch)
    output logic [ADDR_WIDTH-1:0]  m_axi_araddr,
    output logic [7:0]             m_axi_arlen,
    output logic [2:0]             m_axi_arsize,
    output logic [1:0]             m_axi_arburst,
    output logic                   m_axi_arvalid,
    input  logic                   m_axi_arready,
    input  logic [DATA_WIDTH-1:0]  m_axi_rdata,
    input  logic [1:0]             m_axi_rresp,
    input  logic                   m_axi_rlast,
    input  logic                   m_axi_rvalid,
    output logic                   m_axi_rready,

    // AXI4 Master Write Channel (Memory Store)
    output logic [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output logic [7:0]             m_axi_awlen,
    output logic [2:0]             m_axi_awsize,
    output logic [1:0]             m_axi_awburst,
    output logic                   m_axi_awvalid,
    input  logic                   m_axi_awready,
    output logic [DATA_WIDTH-1:0]  m_axi_wdata,
    output logic [3:0]             m_axi_wstrb,
    output logic                   m_axi_wlast,
    output logic                   m_axi_wvalid,
    input  logic                   m_axi_wready,
    input  logic [1:0]             m_axi_bresp,
    input  logic                   m_axi_bvalid,
    output logic                   m_axi_bready,

    // Dedicated Fast Write Ports to Matrix Multiplier Buffers
    output logic                   dma_in_wr_en,
    output logic [7:0]             dma_in_wr_addr,
    output logic [DATA_WIDTH-1:0]  dma_in_wr_data,

    output logic                   dma_w_wr_en,
    output logic [9:0]             dma_w_wr_addr,
    output logic [DATA_WIDTH-1:0]  dma_w_wr_data,

    output logic                   dma_bias_wr_en,
    output logic [7:0]             dma_bias_wr_addr,
    output logic [DATA_WIDTH-1:0]  dma_bias_wr_data,

    // Dedicated Readout Port from Activation Unit
    output logic                   dma_act_rd_en,
    output logic [7:0]             dma_act_rd_addr,
    input  logic [DATA_WIDTH-1:0]  dma_act_rd_data,

    // Status & Interrupt
    output logic                   busy,
    output logic                   done,
    output logic                   error,
    output logic                   irq
);

    // Register Offsets
    localparam [7:0]
        REG_CTRL      = 8'h00,
        REG_STATUS    = 8'h04,
        REG_SRC_ADDR  = 8'h08,
        REG_DST_ADDR  = 8'h0C,
        REG_BURST_LEN = 8'h10;

    logic        ctrl_start;
    logic        ctrl_soft_reset;
    logic        direction;   // 0: Mem->Acc, 1: Acc->Mem
    logic [1:0]  acc_target;  // 00: In, 01: Weight, 10: Bias, 11: Act Out
    logic [31:0] src_addr;
    logic [31:0] dst_addr;
    logic [15:0] burst_len;

    assign irq = done;

    // =========================================================================
    // AXI4-Lite Register Interface
    // =========================================================================
    typedef enum logic [1:0] { WR_IDLE, WR_DATA, WR_RESP } wr_state_t;
    wr_state_t wr_state;
    logic [7:0] axi_awaddr;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state        <= WR_IDLE;
            s_awready       <= 1'b0;
            s_wready        <= 1'b0;
            s_bvalid        <= 1'b0;
            s_bresp         <= 2'b00;
            axi_awaddr      <= 8'h0;
            ctrl_start      <= 1'b0;
            ctrl_soft_reset <= 1'b0;
            direction       <= 1'b0;
            acc_target      <= 2'b00;
            src_addr        <= 32'h1000_0000;
            dst_addr        <= 32'h1000_0400;
            burst_len       <= 16'd4;
        end else begin
            ctrl_start <= 1'b0;

            case (wr_state)
                WR_IDLE: begin
                    if (s_awvalid && s_wvalid) begin
                        s_awready  <= 1'b1;
                        s_wready   <= 1'b1;
                        axi_awaddr <= s_awaddr[7:0];
                        wr_state   <= WR_RESP;

                        case (s_awaddr[7:0])
                            REG_CTRL: begin
                                ctrl_start      <= s_wdata[0];
                                ctrl_soft_reset <= s_wdata[1];
                                direction       <= s_wdata[2];
                                acc_target      <= s_wdata[4:3];
                            end
                            REG_SRC_ADDR:  src_addr  <= s_wdata;
                            REG_DST_ADDR:  dst_addr  <= s_wdata;
                            REG_BURST_LEN: burst_len <= s_wdata[15:0];
                            default: ;
                        endcase
                    end else if (s_awvalid) begin
                        s_awready  <= 1'b1;
                        axi_awaddr <= s_awaddr[7:0];
                        wr_state   <= WR_DATA;
                    end
                end

                WR_DATA: begin
                    s_awready <= 1'b0;
                    if (s_wvalid) begin
                        s_wready <= 1'b1;
                        wr_state <= WR_RESP;
                        case (axi_awaddr)
                            REG_CTRL: begin
                                ctrl_start      <= s_wdata[0];
                                ctrl_soft_reset <= s_wdata[1];
                                direction       <= s_wdata[2];
                                acc_target      <= s_wdata[4:3];
                            end
                            REG_SRC_ADDR:  src_addr  <= s_wdata;
                            REG_DST_ADDR:  dst_addr  <= s_wdata;
                            REG_BURST_LEN: burst_len <= s_wdata[15:0];
                            default: ;
                        endcase
                    end
                end

                WR_RESP: begin
                    s_awready <= 1'b0;
                    s_wready  <= 1'b0;
                    s_bvalid  <= 1'b1;
                    s_bresp   <= 2'b00;
                    if (s_bready) begin
                        s_bvalid <= 1'b0;
                        wr_state <= WR_IDLE;
                    end
                end
            endcase
        end
    end

    // AXI Read Channel
    typedef enum logic { RD_IDLE, RD_RESP } rd_state_t;
    rd_state_t rd_state;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rd_state      <= RD_IDLE;
            s_arready     <= 1'b0;
            s_rvalid      <= 1'b0;
            s_rresp       <= 2'b00;
            s_rdata       <= '0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_arvalid) begin
                        s_arready <= 1'b1;
                        rd_state  <= RD_RESP;
                        case (s_araddr[7:0])
                            REG_CTRL:      s_rdata <= {27'd0, acc_target, direction, ctrl_soft_reset, 1'b0};
                            REG_STATUS:    s_rdata <= {29'd0, error, busy, done};
                            REG_SRC_ADDR:  s_rdata <= src_addr;
                            REG_DST_ADDR:  s_rdata <= dst_addr;
                            REG_BURST_LEN: s_rdata <= {16'd0, burst_len};
                            default:       s_rdata <= 32'hDEAD_BEEF;
                        endcase
                    end
                end

                RD_RESP: begin
                    s_arready <= 1'b0;
                    s_rvalid  <= 1'b1;
                    s_rresp   <= 2'b00;
                    if (s_rready) begin
                        s_rvalid <= 1'b0;
                        rd_state <= RD_IDLE;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // DMA Transfer Engine & Master Execution FSM
    // =========================================================================
    typedef enum logic [2:0] {
        DMA_IDLE, DMA_INIT, DMA_READ_REQ, DMA_READ_DATA, DMA_WRITE_REQ, DMA_WRITE_DATA, DMA_WRITE_RESP, DMA_DONE
    } dma_fsm_t;

    dma_fsm_t state;
    logic [31:0] curr_src;
    logic [31:0] curr_dst;
    logic [15:0] rem_words;
    logic [DATA_WIDTH-1:0] transfer_buf;

    assign m_axi_arsize  = 3'b010; // 4 bytes
    assign m_axi_arburst = 2'b01;  // INCR
    assign m_axi_arlen   = 8'd0;   // 1 beat per step
    assign m_axi_awsize  = 3'b010;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awlen   = 8'd0;
    assign m_axi_wstrb   = 4'hF;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state          <= DMA_IDLE;
            busy           <= 1'b0;
            done           <= 1'b0;
            error          <= 1'b0;
            curr_src       <= '0;
            curr_dst       <= '0;
            rem_words      <= '0;
            m_axi_arvalid  <= 1'b0;
            m_axi_araddr   <= '0;
            m_axi_rready   <= 1'b0;
            m_axi_awvalid  <= 1'b0;
            m_axi_awaddr   <= '0;
            m_axi_wvalid   <= 1'b0;
            m_axi_wdata    <= '0;
            m_axi_wlast    <= 1'b0;
            m_axi_bready   <= 1'b0;
            dma_in_wr_en   <= 1'b0;
            dma_w_wr_en    <= 1'b0;
            dma_bias_wr_en <= 1'b0;
            dma_act_rd_en  <= 1'b0;
            dma_in_wr_addr <= '0;
            dma_w_wr_addr  <= '0;
            dma_bias_wr_addr <= '0;
            dma_act_rd_addr  <= '0;
        end else if (ctrl_soft_reset) begin
            state          <= DMA_IDLE;
            busy           <= 1'b0;
            done           <= 1'b0;
            error          <= 1'b0;
            m_axi_arvalid  <= 1'b0;
            m_axi_awvalid  <= 1'b0;
            m_axi_wvalid   <= 1'b0;
        end else begin
            dma_in_wr_en   <= 1'b0;
            dma_w_wr_en    <= 1'b0;
            dma_bias_wr_en <= 1'b0;

            case (state)
                DMA_IDLE: begin
                    done <= 1'b0;
                    if (ctrl_start) begin
                        busy      <= 1'b1;
                        error     <= 1'b0;
                        curr_src  <= src_addr;
                        curr_dst  <= dst_addr;
                        rem_words <= (burst_len == 16'd0) ? 16'd1 : burst_len;

                        // Check 32-bit alignment
                        if (src_addr[1:0] != 2'b00 || dst_addr[1:0] != 2'b00) begin
                            error <= 1'b1;
                            busy  <= 1'b0;
                            state <= DMA_IDLE;
                        end else begin
                            state <= DMA_INIT;
                        end
                    end else begin
                        busy <= 1'b0;
                    end
                end

                DMA_INIT: begin
                    if (direction == 1'b0) begin
                        // Memory -> Accelerator: Issue Memory Read
                        m_axi_araddr  <= curr_src;
                        m_axi_arvalid <= 1'b1;
                        state         <= DMA_READ_REQ;
                    end else begin
                        // Accelerator -> Memory: Read from Activation Unit
                        dma_act_rd_en   <= 1'b1;
                        dma_act_rd_addr <= curr_src[9:2];
                        state           <= DMA_WRITE_REQ;
                    end
                end

                DMA_READ_REQ: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= DMA_READ_DATA;
                    end
                end

                DMA_READ_DATA: begin
                    if (m_axi_rvalid) begin
                        m_axi_rready <= 1'b0;
                        transfer_buf <= m_axi_rdata;

                        // Push word into selected accelerator buffer
                        case (acc_target)
                            2'b00: begin // Input Buffer
                                dma_in_wr_en   <= 1'b1;
                                dma_in_wr_addr <= curr_dst[9:2];
                                dma_in_wr_data <= m_axi_rdata;
                            end
                            2'b01: begin // Weight Buffer
                                dma_w_wr_en   <= 1'b1;
                                dma_w_wr_addr <= curr_dst[11:2];
                                dma_w_wr_data <= m_axi_rdata;
                            end
                            2'b10: begin // Bias Buffer
                                dma_bias_wr_en   <= 1'b1;
                                dma_bias_wr_addr <= curr_dst[9:2];
                                dma_bias_wr_data <= m_axi_rdata;
                            end
                            default: ;
                        endcase

                        curr_src <= curr_src + 32'd4;
                        curr_dst <= curr_dst + 32'd4;

                        if (rem_words == 16'd1) begin
                            state <= DMA_DONE;
                        end else begin
                            rem_words <= rem_words - 1'b1;
                            state     <= DMA_INIT;
                        end
                    end
                end

                DMA_WRITE_REQ: begin
                    // 1 cycle readout from Activation buffer completed
                    m_axi_awaddr  <= curr_dst;
                    m_axi_awvalid <= 1'b1;
                    m_axi_wdata   <= dma_act_rd_data;
                    m_axi_wvalid  <= 1'b1;
                    m_axi_wlast   <= 1'b1;
                    state         <= DMA_WRITE_DATA;
                end

                DMA_WRITE_DATA: begin
                    if (m_axi_awready && m_axi_awvalid) m_axi_awvalid <= 1'b0;
                    if (m_axi_wready  && m_axi_wvalid)  m_axi_wvalid  <= 1'b0;

                    if (!m_axi_awvalid && !m_axi_wvalid) begin
                        m_axi_bready <= 1'b1;
                        state        <= DMA_WRITE_RESP;
                    end
                end

                DMA_WRITE_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        curr_src     <= curr_src + 32'd4;
                        curr_dst     <= curr_dst + 32'd4;

                        if (rem_words == 16'd1) begin
                            state <= DMA_DONE;
                        end else begin
                            rem_words <= rem_words - 1'b1;
                            state     <= DMA_INIT;
                        end
                    end
                end

                DMA_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state<= DMA_IDLE;
                end
            endcase
        end
    end

endmodule
