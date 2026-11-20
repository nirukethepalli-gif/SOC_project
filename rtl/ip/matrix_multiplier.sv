// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// Module Name: matrix_multiplier
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Base Addr:   0x8000_4000
// Description: Custom IP 1: Matrix Multiplier Accelerator.
//              Features:
//                - Signed Q16.16 Fixed-Point Arithmetic (Y = W * X + B)
//                - Configurable matrix dimensions M, N, K
//                - Saturated accumulation and product rounding
//                - AXI4-Lite slave interface with register mapping
//                - High-throughput dedicated DMA loading ports
//                - Streaming valid/ready handshake directly to Activation Unit
//                - Vectored interrupt generation on completion
// ============================================================================

`timescale 1ns/1ps

module matrix_multiplier #(
    parameter int DATA_WIDTH = 32,
    parameter int FRAC_BITS  = 16,
    parameter int IN_ADDR_W  = 8,   // 256 words
    parameter int W_ADDR_W   = 10,  // 1024 words
    parameter int OUT_ADDR_W = 8    // 256 words
)(
    input  logic                   aclk,
    input  logic                   aresetn,

    // AXI4-Lite Slave Interface (Base 0x8000_4000)
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

    // High-Throughput DMA Loading Ports
    input  logic                   dma_in_wr_en,
    input  logic [IN_ADDR_W-1:0]   dma_in_wr_addr,
    input  logic [DATA_WIDTH-1:0]  dma_in_wr_data,

    input  logic                   dma_w_wr_en,
    input  logic [W_ADDR_W-1:0]    dma_w_wr_addr,
    input  logic [DATA_WIDTH-1:0]  dma_w_wr_data,

    input  logic                   dma_bias_wr_en,
    input  logic [OUT_ADDR_W-1:0]  dma_bias_wr_addr,
    input  logic [DATA_WIDTH-1:0]  dma_bias_wr_data,

    input  logic                   dma_out_rd_en,
    input  logic [OUT_ADDR_W-1:0]  dma_out_rd_addr,
    output logic [DATA_WIDTH-1:0]  dma_out_rd_data,

    // Streaming Handshake to Activation Unit
    output logic [DATA_WIDTH-1:0]  stream_act_data,
    output logic                   stream_act_valid,
    input  logic                   stream_act_ready,

    // Status & Interrupt
    output logic                   busy,
    output logic                   done,
    output logic                   irq
);

    // Register Offsets (Word aligned)
    localparam [7:0]
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

    // Registers
    logic        ctrl_start;
    logic        ctrl_soft_reset;
    logic [7:0]  dim_m, dim_n, dim_k;
    logic [31:0] base_in_addr, base_out_addr;
    logic [9:0]  reg_buf_index;
    logic        status_overflow;

    // Direct buffer write strobes
    logic        dir_in_wr_en, dir_w_wr_en, dir_bias_wr_en;
    logic [7:0]  dir_in_wr_addr, dir_bias_wr_addr;
    logic [9:0]  dir_w_wr_addr;
    logic [31:0] dir_in_wr_data, dir_w_wr_data, dir_bias_wr_data;
    logic [7:0]  dir_out_rd_addr;
    logic [31:0] dir_out_rd_data;

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
            dim_m           <= 8'd2;
            dim_n           <= 8'd1;
            dim_k           <= 8'd2;
            base_in_addr    <= 32'h1000_0000;
            base_out_addr   <= 32'h1000_0400;
            reg_buf_index   <= 10'd0;
            dir_in_wr_en    <= 1'b0;
            dir_w_wr_en     <= 1'b0;
            dir_bias_wr_en  <= 1'b0;
        end else begin
            ctrl_start     <= 1'b0;
            dir_in_wr_en   <= 1'b0;
            dir_w_wr_en    <= 1'b0;
            dir_bias_wr_en <= 1'b0;

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
                            end
                            REG_DIM_M_N_K: begin
                                dim_k <= s_wdata[7:0];
                                dim_n <= s_wdata[15:8];
                                dim_m <= s_wdata[23:16];
                            end
                            REG_BASE_IN_ADDR:  base_in_addr  <= s_wdata;
                            REG_BASE_OUT_ADDR: base_out_addr <= s_wdata;
                            REG_BUF_INDEX:     reg_buf_index <= s_wdata[9:0];
                            REG_IN_BUF_DATA: begin
                                dir_in_wr_en   <= 1'b1;
                                dir_in_wr_addr <= reg_buf_index[7:0];
                                dir_in_wr_data <= s_wdata;
                                reg_buf_index  <= reg_buf_index + 1'b1;
                            end
                            REG_W_BUF_DATA: begin
                                dir_w_wr_en   <= 1'b1;
                                dir_w_wr_addr <= reg_buf_index;
                                dir_w_wr_data <= s_wdata;
                                reg_buf_index <= reg_buf_index + 1'b1;
                            end
                            REG_BIAS_BUF_DATA: begin
                                dir_bias_wr_en   <= 1'b1;
                                dir_bias_wr_addr <= reg_buf_index[7:0];
                                dir_bias_wr_data <= s_wdata;
                                reg_buf_index    <= reg_buf_index + 1'b1;
                            end
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
                            end
                            REG_DIM_M_N_K: begin
                                dim_k <= s_wdata[7:0];
                                dim_n <= s_wdata[15:8];
                                dim_m <= s_wdata[23:16];
                            end
                            REG_BASE_IN_ADDR:  base_in_addr  <= s_wdata;
                            REG_BASE_OUT_ADDR: base_out_addr <= s_wdata;
                            REG_BUF_INDEX:     reg_buf_index <= s_wdata[9:0];
                            REG_IN_BUF_DATA: begin
                                dir_in_wr_en   <= 1'b1;
                                dir_in_wr_addr <= reg_buf_index[7:0];
                                dir_in_wr_data <= s_wdata;
                                reg_buf_index  <= reg_buf_index + 1'b1;
                            end
                            REG_W_BUF_DATA: begin
                                dir_w_wr_en   <= 1'b1;
                                dir_w_wr_addr <= reg_buf_index;
                                dir_w_wr_data <= s_wdata;
                                reg_buf_index <= reg_buf_index + 1'b1;
                            end
                            REG_BIAS_BUF_DATA: begin
                                dir_bias_wr_en   <= 1'b1;
                                dir_bias_wr_addr <= reg_buf_index[7:0];
                                dir_bias_wr_data <= s_wdata;
                                reg_buf_index    <= reg_buf_index + 1'b1;
                            end
                            default: ;
                        endcase
                    end
                end

                WR_RESP: begin
                    s_awready <= 1'b0;
                    s_wready  <= 1'b0;
                    s_bvalid  <= 1'b1;
                    s_bresp   <= 2'b00; // OKAY
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
            rd_state        <= RD_IDLE;
            s_arready       <= 1'b0;
            s_rvalid        <= 1'b0;
            s_rresp         <= 2'b00;
            s_rdata         <= '0;
            dir_out_rd_addr <= '0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (s_arvalid) begin
                        s_arready       <= 1'b1;
                        rd_state        <= RD_RESP;
                        dir_out_rd_addr <= reg_buf_index[7:0];

                        case (s_araddr[7:0])
                            REG_CTRL:          s_rdata <= {30'd0, ctrl_soft_reset, 1'b0};
                            REG_STATUS:        s_rdata <= {29'd0, status_overflow, busy, done};
                            REG_DIM_M_N_K:     s_rdata <= {8'd0, dim_m, dim_n, dim_k};
                            REG_BASE_IN_ADDR:  s_rdata <= base_in_addr;
                            REG_BASE_OUT_ADDR: s_rdata <= base_out_addr;
                            REG_BUF_INDEX:     s_rdata <= {22'd0, reg_buf_index};
                            REG_OUT_BUF_DATA:  s_rdata <= dir_out_rd_data;
                            default:           s_rdata <= 32'hDEAD_BEEF;
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
    // Internal Memories (Input, Weight, Bias, Output)
    // =========================================================================
    logic [DATA_WIDTH-1:0] in_mem   [0:255];
    logic [DATA_WIDTH-1:0] w_mem    [0:1023];
    logic [DATA_WIDTH-1:0] bias_mem [0:255];
    logic [DATA_WIDTH-1:0] out_mem  [0:255];

    // Write Multiplexers (DMA priority)
    wire mux_in_wr_en   = dma_in_wr_en   | dir_in_wr_en;
    wire [7:0]  mux_in_addr  = dma_in_wr_en ? dma_in_wr_addr : dir_in_wr_addr;
    wire [31:0] mux_in_data  = dma_in_wr_en ? dma_in_wr_data : dir_in_wr_data;

    wire mux_w_wr_en    = dma_w_wr_en    | dir_w_wr_en;
    wire [9:0]  mux_w_addr   = dma_w_wr_en ? dma_w_wr_addr : dir_w_wr_addr;
    wire [31:0] mux_w_data   = dma_w_wr_en ? dma_w_wr_data : dir_w_wr_data;

    wire mux_b_wr_en    = dma_bias_wr_en | dir_bias_wr_en;
    wire [7:0]  mux_b_addr   = dma_bias_wr_en ? dma_bias_wr_addr : dir_bias_wr_addr;
    wire [31:0] mux_b_data   = dma_bias_wr_en ? dma_bias_wr_data : dir_bias_wr_data;

    always_ff @(posedge aclk) begin
        if (mux_in_wr_en) in_mem[mux_in_addr] <= mux_in_data;
        if (mux_w_wr_en)  w_mem[mux_w_addr]   <= mux_w_data;
        if (mux_b_wr_en)  bias_mem[mux_b_addr]<= mux_b_data;
    end

    // Datapath read signals
    logic [IN_ADDR_W-1:0]  ctrl_in_addr;
    logic [W_ADDR_W-1:0]   ctrl_w_addr;
    logic [OUT_ADDR_W-1:0] ctrl_bias_addr;
    logic signed [31:0]    op_in, op_w, op_bias;

    always_ff @(posedge aclk) begin
        op_in   <= $signed(in_mem[ctrl_in_addr]);
        op_w    <= $signed(w_mem[ctrl_w_addr]);
        op_bias <= $signed(bias_mem[ctrl_bias_addr]);
    end

    // =========================================================================
    // MAC Engine & Fixed-Point Arithmetic (Q16.16)
    // =========================================================================
    logic        mac_clr_acc;
    logic        mac_en;
    logic        bias_add_en;
    logic signed [63:0] prod_raw;
    logic signed [63:0] prod_rounded;
    logic signed [31:0] prod_scaled;
    logic signed [47:0] acc_reg;
    logic signed [47:0] next_acc;
    logic signed [31:0] y_with_bias;

    assign prod_raw     = op_in * op_w;
    assign prod_rounded = prod_raw + (64'sh1 <<< (FRAC_BITS - 1));
    assign prod_scaled  = prod_rounded[FRAC_BITS + DATA_WIDTH - 1 : FRAC_BITS];

    wire signed [47:0] ext_prod = {{16{prod_scaled[31]}}, prod_scaled};
    assign next_acc = mac_clr_acc ? ext_prod : (acc_reg + ext_prod);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            acc_reg         <= '0;
            status_overflow <= 1'b0;
        end else if (mac_en) begin
            acc_reg <= next_acc;
            if (next_acc > 48'sh0000_7FFF_FFFF || next_acc < -48'sh0000_8000_0000)
                status_overflow <= 1'b1;
        end
    end

    // Signed Bias Addition with 33-bit extension
    wire signed [32:0] bias_sum_ext = {acc_reg[31], acc_reg[31:0]} + {op_bias[31], op_bias};
    always_comb begin
        if (!acc_reg[31] && !op_bias[31] && bias_sum_ext[31])
            y_with_bias = 32'h7FFF_FFFF; // Saturated max
        else if (acc_reg[31] && op_bias[31] && !bias_sum_ext[31])
            y_with_bias = 32'h8000_0000; // Saturated min
        else
            y_with_bias = bias_sum_ext[31:0];
    end

    // Output buffer write
    logic [OUT_ADDR_W-1:0] out_wr_addr;
    logic                  out_wr_en;

    always_ff @(posedge aclk) begin
        if (out_wr_en) out_mem[out_wr_addr] <= y_with_bias;
    end

    // Output buffer read multiplexing
    wire [7:0] mux_out_rd_addr = dma_out_rd_en ? dma_out_rd_addr : dir_out_rd_addr;
    always_ff @(posedge aclk) begin
        dma_out_rd_data <= out_mem[mux_out_rd_addr];
        dir_out_rd_data <= out_mem[mux_out_rd_addr];
    end

    // =========================================================================
    // Matrix Controller FSM
    // =========================================================================
    typedef enum logic [2:0] {
        S_IDLE, S_FETCH, S_MAC, S_BIAS, S_STREAM, S_DONE
    } fsm_state_t;

    fsm_state_t state;
    logic [7:0] row_m, col_k;
    logic [9:0] w_idx;
    logic [7:0] reg_m_lat, reg_k_lat;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state            <= S_IDLE;
            row_m            <= '0;
            col_k            <= '0;
            w_idx            <= '0;
            reg_m_lat        <= '0;
            reg_k_lat        <= '0;
            busy             <= 1'b0;
            done             <= 1'b0;
            mac_clr_acc      <= 1'b0;
            mac_en           <= 1'b0;
            bias_add_en      <= 1'b0;
            out_wr_en        <= 1'b0;
            out_wr_addr      <= '0;
            stream_act_valid <= 1'b0;
            stream_act_data  <= '0;
            ctrl_in_addr     <= '0;
            ctrl_w_addr      <= '0;
            ctrl_bias_addr   <= '0;
        end else if (ctrl_soft_reset) begin
            state            <= S_IDLE;
            busy             <= 1'b0;
            done             <= 1'b0;
            stream_act_valid <= 1'b0;
        end else begin
            mac_en    <= 1'b0;
            out_wr_en <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (ctrl_start) begin
                        busy      <= 1'b1;
                        reg_m_lat <= (dim_m == 8'd0) ? 8'd1 : dim_m;
                        reg_k_lat <= (dim_k == 8'd0) ? 8'd1 : dim_k;
                        row_m     <= 8'd0;
                        col_k     <= 8'd0;
                        w_idx     <= 10'd0;
                        ctrl_in_addr   <= 8'd0;
                        ctrl_w_addr    <= 10'd0;
                        ctrl_bias_addr <= 8'd0;
                        state     <= S_FETCH;
                    end else begin
                        busy <= 1'b0;
                    end
                end

                S_FETCH: begin
                    // 1 cycle memory latency
                    state <= S_MAC;
                end

                S_MAC: begin
                    mac_en      <= 1'b1;
                    mac_clr_acc <= (col_k == 8'd0);

                    if (col_k == reg_k_lat - 1'b1) begin
                        state <= S_BIAS;
                    end else begin
                        col_k        <= col_k + 1'b1;
                        w_idx        <= w_idx + 1'b1;
                        ctrl_in_addr <= col_k + 1'b1;
                        ctrl_w_addr  <= w_idx + 1'b1;
                        state        <= S_FETCH;
                    end
                end

                S_BIAS: begin
                    out_wr_en        <= 1'b1;
                    out_wr_addr      <= row_m;
                    stream_act_data  <= y_with_bias;
                    stream_act_valid <= 1'b1;
                    state            <= S_STREAM;
                end

                S_STREAM: begin
                    if (stream_act_ready || !stream_act_valid) begin
                        stream_act_valid <= 1'b0;
                        if (row_m == reg_m_lat - 1'b1) begin
                            state <= S_DONE;
                        end else begin
                            row_m          <= row_m + 1'b1;
                            col_k          <= 8'd0;
                            w_idx          <= w_idx + 1'b1;
                            ctrl_in_addr   <= 8'd0;
                            ctrl_w_addr    <= w_idx + 1'b1;
                            ctrl_bias_addr <= row_m + 1'b1;
                            state          <= S_FETCH;
                        end
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state<= S_IDLE;
                end
            endcase
        end
    end

endmodule
