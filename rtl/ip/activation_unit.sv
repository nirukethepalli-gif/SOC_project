// SPDX-License-Identifier: Apache-2.0
// ============================================================================
// Module Name: activation_unit
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Base Addr:   0x8000_5000
// Description: Custom IP 2: Activation Unit Accelerator.
//              Applies element-wise non-linear activation functions (ReLU,
//              Sigmoid PLAN, Tanh PLAN) on Q16.16 signed fixed-point vectors.
//              Features:
//                - AXI4-Lite slave interface (0x8000_5000)
//                - Streaming input handshake with Matrix Multiplier
//                - Configurable vector length and runtime function select
//                - Zero-multiplier PWL logic for Sigmoid & Tanh
//                - Dedicated DMA readout port
// ============================================================================

`timescale 1ns/1ps

module activation_unit #(
    parameter int DATA_WIDTH = 32,
    parameter int BUF_ADDR_W = 8   // 256 words
)(
    input  logic                   aclk,
    input  logic                   aresetn,

    // AXI4-Lite Slave Interface (Base 0x8000_5000)
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

    // Streaming Input Handshake from Matrix Multiplier
    input  logic [DATA_WIDTH-1:0]  stream_in_data,
    input  logic                   stream_in_valid,
    output logic                   stream_in_ready,

    // Dedicated DMA Readout Port
    input  logic                   dma_out_rd_en,
    input  logic [BUF_ADDR_W-1:0]  dma_out_rd_addr,
    output logic [DATA_WIDTH-1:0]  dma_out_rd_data,

    // Status & Interrupt
    output logic                   busy,
    output logic                   done,
    output logic                   irq
);

    // Register Offsets
    localparam [7:0]
        REG_CTRL      = 8'h00,
        REG_STATUS    = 8'h04,
        REG_VEC_LEN   = 8'h08,
        REG_OUT_ADDR  = 8'h0C,
        REG_BUF_INDEX = 8'h14,
        REG_IN_DATA   = 8'h20,
        REG_OUT_DATA  = 8'h24;

    logic        ctrl_start;
    logic        ctrl_soft_reset;
    logic [1:0]  func_sel;
    logic [15:0] vec_len;
    logic [31:0] out_addr;
    logic [7:0]  reg_buf_index;

    // Direct interface
    logic        dir_in_wr_en;
    logic [7:0]  dir_in_wr_addr;
    logic [31:0] dir_in_wr_data;
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
            func_sel        <= 2'b00; // ReLU default
            vec_len         <= 16'd2;
            out_addr        <= 32'h1000_0400;
            reg_buf_index   <= 8'd0;
            dir_in_wr_en    <= 1'b0;
        end else begin
            ctrl_start   <= 1'b0;
            dir_in_wr_en <= 1'b0;

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
                                func_sel        <= s_wdata[3:2];
                            end
                            REG_VEC_LEN:   vec_len       <= s_wdata[15:0];
                            REG_OUT_ADDR:  out_addr      <= s_wdata;
                            REG_BUF_INDEX: reg_buf_index <= s_wdata[7:0];
                            REG_IN_DATA: begin
                                dir_in_wr_en   <= 1'b1;
                                dir_in_wr_addr <= reg_buf_index;
                                dir_in_wr_data <= s_wdata;
                                reg_buf_index  <= reg_buf_index + 1'b1;
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
                                func_sel        <= s_wdata[3:2];
                            end
                            REG_VEC_LEN:   vec_len       <= s_wdata[15:0];
                            REG_OUT_ADDR:  out_addr      <= s_wdata;
                            REG_BUF_INDEX: reg_buf_index <= s_wdata[7:0];
                            REG_IN_DATA: begin
                                dir_in_wr_en   <= 1'b1;
                                dir_in_wr_addr <= reg_buf_index;
                                dir_in_wr_data <= s_wdata;
                                reg_buf_index  <= reg_buf_index + 1'b1;
                            end
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
                        dir_out_rd_addr <= reg_buf_index;

                        case (s_araddr[7:0])
                            REG_CTRL:      s_rdata <= {28'd0, func_sel, ctrl_soft_reset, 1'b0};
                            REG_STATUS:    s_rdata <= {30'd0, busy, done};
                            REG_VEC_LEN:   s_rdata <= {16'd0, vec_len};
                            REG_OUT_ADDR:  s_rdata <= out_addr;
                            REG_BUF_INDEX: s_rdata <= {24'd0, reg_buf_index};
                            REG_OUT_DATA:  s_rdata <= dir_out_rd_data;
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
    // Activation Computation Logic (ReLU, Sigmoid PWL, Tanh PWL)
    // =========================================================================
    wire [DATA_WIDTH-1:0] act_in_val   = stream_in_valid ? stream_in_data : dir_in_wr_data;
    wire                  act_in_valid = stream_in_valid | dir_in_wr_en;

    // 1. ReLU
    wire signed [31:0] relu_res = (act_in_val[31] == 1'b1) ? 32'd0 : act_in_val;

    // 2. Sigmoid (PWL PLAN)
    localparam signed [31:0] Q_ONE     = 32'h0001_0000;
    localparam signed [31:0] Q_HALF    = 32'h0000_8000;
    localparam signed [31:0] Q_FIVE    = 32'h0005_0000;
    localparam signed [31:0] Q_2_375   = 32'h0002_6000;
    localparam signed [31:0] Q_0_625   = 32'h0000_A000;
    localparam signed [31:0] Q_0_84375 = 32'h0000_D800;

    wire signed [31:0] abs_x_sig = act_in_val[31] ? (-$signed(act_in_val)) : $signed(act_in_val);
    logic signed [31:0] y_pos_sig;
    always_comb begin
        if (abs_x_sig >= Q_FIVE)
            y_pos_sig = Q_ONE;
        else if (abs_x_sig >= Q_2_375)
            y_pos_sig = Q_0_84375 + (abs_x_sig >>> 5);
        else if (abs_x_sig >= Q_ONE)
            y_pos_sig = Q_0_625 + (abs_x_sig >>> 3);
        else
            y_pos_sig = Q_HALF + (abs_x_sig >>> 2);
    end
    wire signed [31:0] sigmoid_res = act_in_val[31] ? (Q_ONE - y_pos_sig) : y_pos_sig;

    // 3. Tanh (PWL PLAN)
    localparam signed [31:0] Q_THREE   = 32'h0003_0000;
    localparam signed [31:0] Q_1_5     = 32'h0001_8000;
    localparam signed [31:0] Q_QUARTER = 32'h0000_4000;
    localparam signed [31:0] Q_0_8125  = 32'h0000_D000;

    wire signed [31:0] abs_x_tanh = act_in_val[31] ? (-$signed(act_in_val)) : $signed(act_in_val);
    logic signed [31:0] y_pos_tanh;
    always_comb begin
        if (abs_x_tanh >= Q_THREE)
            y_pos_tanh = Q_ONE;
        else if (abs_x_tanh >= Q_1_5)
            y_pos_tanh = Q_0_8125 + (abs_x_tanh >>> 3);
        else if (abs_x_tanh >= Q_HALF)
            y_pos_tanh = Q_QUARTER + (abs_x_tanh >>> 1);
        else
            y_pos_tanh = abs_x_tanh;
    end
    wire signed [31:0] tanh_res = act_in_val[31] ? (-y_pos_tanh) : y_pos_tanh;

    // Multiplexed Output
    logic signed [31:0] computed_act;
    always_comb begin
        case (func_sel)
            2'b00:   computed_act = relu_res;
            2'b01:   computed_act = sigmoid_res;
            2'b10:   computed_act = tanh_res;
            default: computed_act = act_in_val; // 2'b11 Bypass
        endcase
    end

    // =========================================================================
    // Output Buffer & Streaming Controller
    // =========================================================================
    logic [DATA_WIDTH-1:0] out_mem [0:(1<<BUF_ADDR_W)-1];
    logic [15:0] processed_count;
    logic [15:0] reg_vec_len_lat;

    assign stream_in_ready = busy && (processed_count < reg_vec_len_lat);

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            busy            <= 1'b0;
            done            <= 1'b0;
            processed_count <= '0;
            reg_vec_len_lat <= '0;
        end else if (ctrl_soft_reset) begin
            busy            <= 1'b0;
            done            <= 1'b0;
            processed_count <= '0;
        end else begin
            if (ctrl_start) begin
                busy            <= 1'b1;
                done            <= 1'b0;
                processed_count <= '0;
                reg_vec_len_lat <= (vec_len == 16'd0) ? 16'd1 : vec_len;
            end else if (busy && act_in_valid && stream_in_ready) begin
                out_mem[processed_count[BUF_ADDR_W-1:0]] <= computed_act;
                processed_count <= processed_count + 1'b1;

                if (processed_count + 1'b1 == reg_vec_len_lat) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end

    // Output Memory Readout
    wire [BUF_ADDR_W-1:0] mux_rd_addr = dma_out_rd_en ? dma_out_rd_addr : dir_out_rd_addr;
    always_ff @(posedge aclk) begin
        dma_out_rd_data <= out_mem[mux_rd_addr];
        dir_out_rd_data <= out_mem[mux_rd_addr];
    end

endmodule
