// ============================================================================
// Module Name: matrix_multiplier_top
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Top-Level Module of Custom IP 1: Matrix Multiplier.
//              Integrates MAC Unit, Input Buffer, Weight Buffer, Bias Adder,
//              Output Buffer, Matrix Controller, and AXI4-Lite Register File.
//              Implements Y = W * X + B using Q16.16 signed fixed-point logic.
// ============================================================================

`timescale 1ns / 1ps

module matrix_multiplier_top #(
    parameter DATA_WIDTH = 32,
    parameter FRAC_BITS  = 16,
    parameter IN_ADDR_W  = 8,   // 256 words
    parameter W_ADDR_W   = 10,  // 1024 words
    parameter OUT_ADDR_W = 8    // 256 words
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave Interface (CPU Configuration and Status)
    // -------------------------------------------------------------------------
    input  wire [7:0]             s_axi_awaddr,
    input  wire [2:0]             s_axi_awprot,
    input  wire                   s_axi_awvalid,
    output wire                   s_axi_awready,

    input  wire [31:0]            s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wvalid,
    output wire                   s_axi_wready,

    output wire [1:0]             s_axi_bresp,
    output wire                   s_axi_bvalid,
    input  wire                   s_axi_bready,

    input  wire [7:0]             s_axi_araddr,
    input  wire [2:0]             s_axi_arprot,
    input  wire                   s_axi_arvalid,
    output wire                   s_axi_arready,

    output wire [31:0]            s_axi_rdata,
    output wire [1:0]             s_axi_rresp,
    output wire                   s_axi_rvalid,
    input  wire                   s_axi_rready,

    // -------------------------------------------------------------------------
    // DMA Direct Buffer Access Interface (Fast Memory Staging)
    // -------------------------------------------------------------------------
    input  wire                   dma_in_wr_en,
    input  wire [IN_ADDR_W-1:0]   dma_in_wr_addr,
    input  wire [DATA_WIDTH-1:0]  dma_in_wr_data,

    input  wire                   dma_w_wr_en,
    input  wire [W_ADDR_W-1:0]    dma_w_wr_addr,
    input  wire [DATA_WIDTH-1:0]  dma_w_wr_data,

    input  wire                   dma_bias_wr_en,
    input  wire [OUT_ADDR_W-1:0]  dma_bias_wr_addr,
    input  wire [DATA_WIDTH-1:0]  dma_bias_wr_data,

    input  wire                   dma_out_rd_en,
    input  wire [OUT_ADDR_W-1:0]  dma_out_rd_addr,
    output wire [DATA_WIDTH-1:0]  dma_out_rd_data,

    // -------------------------------------------------------------------------
    // Streaming Output Handshake to Activation Unit IP
    // -------------------------------------------------------------------------
    output wire [DATA_WIDTH-1:0]  stream_act_data,
    output wire                   stream_act_valid,
    input  wire                   stream_act_ready,

    // -------------------------------------------------------------------------
    // Top-Level Status & Interrupt Lines
    // -------------------------------------------------------------------------
    output wire                   busy,
    output wire                   done,
    output wire                   irq
);

    // -------------------------------------------------------------------------
    // Internal Interconnect Wires
    // -------------------------------------------------------------------------
    wire ctrl_start;
    wire ctrl_soft_reset;
    wire [7:0] dim_m, dim_n, dim_k;
    wire [31:0] base_in_addr, base_out_addr;
    wire status_overflow;

    // Direct AXI Register Write Ports
    wire dir_in_wr_en, dir_w_wr_en, dir_bias_wr_en;
    wire [7:0]  dir_in_wr_addr, dir_bias_wr_addr, dir_out_rd_addr;
    wire [9:0]  dir_w_wr_addr;
    wire [31:0] dir_in_wr_data, dir_w_wr_data, dir_bias_wr_data;
    wire [31:0] dir_out_rd_data;

    // Controller <-> Datapath Wires
    wire in_buf_rd_en;
    wire [IN_ADDR_W-1:0] in_buf_rd_addr;
    wire [DATA_WIDTH-1:0] in_operand;

    wire w_buf_rd_en;
    wire [W_ADDR_W-1:0] w_buf_rd_addr;
    wire [DATA_WIDTH-1:0] w_operand;

    wire bias_rd_en;
    wire [OUT_ADDR_W-1:0] bias_rd_addr;
    wire bias_add_en;
    wire [DATA_WIDTH-1:0] y_bias_result;
    wire y_bias_valid;
    wire bias_overflow;

    wire mac_en;
    wire mac_clr_acc;
    wire signed [DATA_WIDTH-1:0] mac_acc_out;
    wire mac_valid_out;
    wire mac_overflow;

    wire out_buf_wr_en;
    wire [OUT_ADDR_W-1:0] out_buf_wr_addr;
    wire [DATA_WIDTH-1:0] out_buf_rd_data_mux;

    assign status_overflow = mac_overflow | bias_overflow;
    assign irq = done;

    // Buffer Write Multiplexers (Priority to DMA over Direct AXI register write)
    wire mux_in_wr_en   = dma_in_wr_en   | dir_in_wr_en;
    wire [IN_ADDR_W-1:0] mux_in_wr_addr  = dma_in_wr_en ? dma_in_wr_addr : dir_in_wr_addr;
    wire [DATA_WIDTH-1:0] mux_in_wr_data = dma_in_wr_en ? dma_in_wr_data : dir_in_wr_data;

    wire mux_w_wr_en    = dma_w_wr_en    | dir_w_wr_en;
    wire [W_ADDR_W-1:0] mux_w_wr_addr    = dma_w_wr_en ? dma_w_wr_addr : dir_w_wr_addr;
    wire [DATA_WIDTH-1:0] mux_w_wr_data  = dma_w_wr_en ? dma_w_wr_data : dir_w_wr_data;

    wire mux_bias_wr_en = dma_bias_wr_en | dir_bias_wr_en;
    wire [OUT_ADDR_W-1:0] mux_bias_wr_addr = dma_bias_wr_en ? dma_bias_wr_addr : dir_bias_wr_addr;
    wire [DATA_WIDTH-1:0] mux_bias_wr_data = dma_bias_wr_en ? dma_bias_wr_data : dir_bias_wr_data;

    // Output buffer read multiplexing
    wire [OUT_ADDR_W-1:0] mux_out_rd_addr = dma_out_rd_en ? dma_out_rd_addr : dir_out_rd_addr;
    assign dma_out_rd_data = out_buf_rd_data_mux;
    assign dir_out_rd_data = out_buf_rd_data_mux;

    // -------------------------------------------------------------------------
    // Submodule 1: AXI4-Lite Register Interface
    // -------------------------------------------------------------------------
    matrix_axi_regs #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(8)
    ) u_axi_regs (
        .s_axi_aclk       (clk),
        .s_axi_aresetn    (rst_n),
        .s_axi_awaddr     (s_axi_awaddr),
        .s_axi_awprot     (s_axi_awprot),
        .s_axi_awvalid    (s_axi_awvalid),
        .s_axi_awready    (s_axi_awready),
        .s_axi_wdata      (s_axi_wdata),
        .s_axi_wstrb      (s_axi_wstrb),
        .s_axi_wvalid     (s_axi_wvalid),
        .s_axi_wready     (s_axi_wready),
        .s_axi_bresp      (s_axi_bresp),
        .s_axi_bvalid     (s_axi_bvalid),
        .s_axi_bready     (s_axi_bready),
        .s_axi_araddr     (s_axi_araddr),
        .s_axi_arprot     (s_axi_arprot),
        .s_axi_arvalid    (s_axi_arvalid),
        .s_axi_arready    (s_axi_arready),
        .s_axi_rdata      (s_axi_rdata),
        .s_axi_rresp      (s_axi_rresp),
        .s_axi_rvalid     (s_axi_rvalid),
        .s_axi_rready     (s_axi_rready),

        .ctrl_start       (ctrl_start),
        .ctrl_soft_reset  (ctrl_soft_reset),
        .dim_m            (dim_m),
        .dim_n            (dim_n),
        .dim_k            (dim_k),
        .base_in_addr     (base_in_addr),
        .base_out_addr    (base_out_addr),

        .status_done      (done),
        .status_busy      (busy),
        .status_overflow  (status_overflow),

        .dir_in_wr_en     (dir_in_wr_en),
        .dir_in_wr_addr   (dir_in_wr_addr),
        .dir_in_wr_data   (dir_in_wr_data),

        .dir_w_wr_en      (dir_w_wr_en),
        .dir_w_wr_addr    (dir_w_wr_addr),
        .dir_w_wr_data    (dir_w_wr_data),

        .dir_bias_wr_en   (dir_bias_wr_en),
        .dir_bias_wr_addr (dir_bias_wr_addr),
        .dir_bias_wr_data (dir_bias_wr_data),

        .dir_out_rd_addr  (dir_out_rd_addr),
        .dir_out_rd_data  (dir_out_rd_data)
    );

    // -------------------------------------------------------------------------
    // Submodule 2: Input Buffer (Holds Vector X)
    // -------------------------------------------------------------------------
    input_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(IN_ADDR_W),
        .DEPTH(256)
    ) u_input_buf (
        .clk       (clk),
        .rst_n     (rst_n),
        .wr_en_a   (mux_in_wr_en),
        .addr_a    (mux_in_wr_addr),
        .wr_data_a (mux_in_wr_data),
        .rd_data_a (),
        .rd_en_b   (in_buf_rd_en),
        .addr_b    (in_buf_rd_addr),
        .rd_data_b (in_operand)
    );

    // -------------------------------------------------------------------------
    // Submodule 3: Weight Buffer (Holds Matrix W)
    // -------------------------------------------------------------------------
    weight_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(W_ADDR_W),
        .DEPTH(1024)
    ) u_weight_buf (
        .clk       (clk),
        .rst_n     (rst_n),
        .wr_en_a   (mux_w_wr_en),
        .addr_a    (mux_w_wr_addr),
        .wr_data_a (mux_w_wr_data),
        .rd_data_a (),
        .rd_en_b   (w_buf_rd_en),
        .addr_b    (w_buf_rd_addr),
        .rd_data_b (w_operand)
    );

    // -------------------------------------------------------------------------
    // Submodule 4: MAC Unit (Q16.16 Multiply-Accumulate Engine)
    // -------------------------------------------------------------------------
    mac_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_BITS(FRAC_BITS)
    ) u_mac (
        .clk       (clk),
        .rst_n     (rst_n),
        .clr_acc   (mac_clr_acc),
        .en        (mac_en),
        .a_in      (in_operand),
        .b_in      (w_operand),
        .acc_out   (mac_acc_out),
        .valid_out (mac_valid_out),
        .overflow  (mac_overflow)
    );

    // -------------------------------------------------------------------------
    // Submodule 5: Bias Adder (Adds B[m] to Dot-Product)
    // -------------------------------------------------------------------------
    bias_adder #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(OUT_ADDR_W),
        .DEPTH(256)
    ) u_bias_adder (
        .clk          (clk),
        .rst_n        (rst_n),
        .bias_wr_en   (mux_bias_wr_en),
        .bias_wr_addr (mux_bias_wr_addr),
        .bias_wr_data (mux_bias_wr_data),
        .add_en       (bias_add_en),
        .bias_rd_addr (bias_rd_addr),
        .dot_prod_in  (mac_acc_out),
        .y_out        (y_bias_result),
        .y_valid      (y_bias_valid),
        .overflow     (bias_overflow)
    );

    // -------------------------------------------------------------------------
    // Submodule 6: Output Buffer (Stores Vector Y)
    // -------------------------------------------------------------------------
    output_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(OUT_ADDR_W),
        .DEPTH(256)
    ) u_output_buf (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (out_buf_wr_en),
        .wr_addr (out_buf_wr_addr),
        .wr_data (y_bias_result),
        .rd_en   (1'b1),
        .rd_addr (mux_out_rd_addr),
        .rd_data (out_buf_rd_data_mux)
    );

    // -------------------------------------------------------------------------
    // Submodule 7: Matrix Controller FSM
    // -------------------------------------------------------------------------
    matrix_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .IN_ADDR_W(IN_ADDR_W),
        .W_ADDR_W(W_ADDR_W),
        .OUT_ADDR_W(OUT_ADDR_W)
    ) u_controller (
        .clk              (clk),
        .rst_n            (rst_n),
        .start            (ctrl_start),
        .soft_reset       (ctrl_soft_reset),
        .dim_m            (dim_m),
        .dim_k            (dim_k),
        .busy             (busy),
        .done             (done),
        .in_buf_rd_en     (in_buf_rd_en),
        .in_buf_rd_addr   (in_buf_rd_addr),
        .w_buf_rd_en      (w_buf_rd_en),
        .w_buf_rd_addr    (w_buf_rd_addr),
        .bias_rd_en       (bias_rd_en),
        .bias_rd_addr     (bias_rd_addr),
        .bias_add_en      (bias_add_en),
        .mac_en           (mac_en),
        .mac_clr_acc      (mac_clr_acc),
        .out_buf_wr_en    (out_buf_wr_en),
        .out_buf_wr_addr  (out_buf_wr_addr),
        .stream_out_data  (stream_act_data),
        .stream_out_valid (stream_act_valid),
        .stream_out_ready (stream_act_ready),
        .y_bias_result    (y_bias_result),
        .y_bias_valid     (y_bias_valid)
    );

endmodule
