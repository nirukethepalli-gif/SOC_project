// ============================================================================
// Module Name: activation_top
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Top-Level Module of Custom IP 2: Activation Unit.
//              Applies nonlinear activation functions (ReLU, Sigmoid, Tanh)
//              element-wise to vectors from Matrix Multiplier or Memory.
//              Integrates ReLU, Sigmoid PWL, Tanh PWL, Function Selector,
//              Activation Controller, Output Buffer, and AXI4-Lite Register File.
// ============================================================================

`timescale 1ns / 1ps

module activation_top #(
    parameter DATA_WIDTH = 32,
    parameter BUF_ADDR_W = 8   // 256 words
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
    // Streaming Input Handshake from Matrix Multiplier IP
    // -------------------------------------------------------------------------
    input  wire [DATA_WIDTH-1:0]  stream_in_data,
    input  wire                   stream_in_valid,
    output wire                   stream_in_ready,

    // -------------------------------------------------------------------------
    // DMA Readout Interface (Transferring Activated Vector to Data Memory)
    // -------------------------------------------------------------------------
    input  wire                   dma_out_rd_en,
    input  wire [BUF_ADDR_W-1:0]  dma_out_rd_addr,
    output wire [DATA_WIDTH-1:0]  dma_out_rd_data,

    // -------------------------------------------------------------------------
    // Top-Level Status Outputs
    // -------------------------------------------------------------------------
    output wire                   busy,
    output wire                   done,
    output wire                   irq
);

    // Internal Control / Configuration Signals
    wire ctrl_start;
    wire ctrl_soft_reset;
    wire [1:0] func_sel;
    wire [15:0] vec_len;
    wire [31:0] out_addr;

    // Direct AXI Register Write / Read Ports
    wire dir_in_wr_en;
    wire [7:0] dir_in_wr_addr;
    wire [31:0] dir_in_wr_data;
    wire [7:0] dir_out_rd_addr;
    wire [31:0] dir_out_rd_data;

    // Controller <-> Datapath Wires
    wire in_ready_internal;
    wire act_en;
    wire out_buf_wr_en;
    wire [BUF_ADDR_W-1:0] out_buf_wr_addr;

    // Activation Submodule Outputs
    wire signed [DATA_WIDTH-1:0] relu_out;
    wire relu_valid;

    wire signed [DATA_WIDTH-1:0] sigmoid_out;
    wire sigmoid_valid;

    wire signed [DATA_WIDTH-1:0] tanh_out;
    wire tanh_valid;

    wire signed [DATA_WIDTH-1:0] final_act_data;
    wire final_act_valid;

    assign stream_in_ready = in_ready_internal;
    assign irq = done;

    // Mux input between streaming port and direct AXI write
    wire [DATA_WIDTH-1:0] active_data_in = stream_in_valid ? stream_in_data : dir_in_wr_data;
    wire active_valid_in = stream_in_valid | dir_in_wr_en;

    // -------------------------------------------------------------------------
    // Submodule 1: AXI4-Lite Register File
    // -------------------------------------------------------------------------
    activation_axi_regs #(
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
        .func_sel         (func_sel),
        .vec_len          (vec_len),
        .out_addr         (out_addr),

        .status_done      (done),
        .status_busy      (busy),

        .dir_in_wr_en     (dir_in_wr_en),
        .dir_in_wr_addr   (dir_in_wr_addr),
        .dir_in_wr_data   (dir_in_wr_data),

        .dir_out_rd_addr  (dir_out_rd_addr),
        .dir_out_rd_data  (dir_out_rd_data)
    );

    // -------------------------------------------------------------------------
    // Submodule 2: Activation Controller
    // -------------------------------------------------------------------------
    activation_controller #(
        .ADDR_WIDTH(BUF_ADDR_W)
    ) u_controller (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (ctrl_start),
        .soft_reset      (ctrl_soft_reset),
        .vec_len         (vec_len),
        .busy            (busy),
        .done            (done),
        .in_valid        (active_valid_in),
        .in_ready        (in_ready_internal),
        .act_en          (act_en),
        .act_valid_in    (final_act_valid),
        .out_buf_wr_en   (out_buf_wr_en),
        .out_buf_wr_addr (out_buf_wr_addr)
    );

    // -------------------------------------------------------------------------
    // Submodule 3: ReLU Implementation
    // -------------------------------------------------------------------------
    relu #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_relu (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (act_en),
        .data_in   (active_data_in),
        .data_out  (relu_out),
        .valid_out (relu_valid)
    );

    // -------------------------------------------------------------------------
    // Submodule 4: Sigmoid PWL Implementation
    // -------------------------------------------------------------------------
    sigmoid #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_sigmoid (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (act_en),
        .data_in   (active_data_in),
        .data_out  (sigmoid_out),
        .valid_out (sigmoid_valid)
    );

    // -------------------------------------------------------------------------
    // Submodule 5: Tanh PWL Implementation
    // -------------------------------------------------------------------------
    tanh #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_tanh (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (act_en),
        .data_in   (active_data_in),
        .data_out  (tanh_out),
        .valid_out (tanh_valid)
    );

    // -------------------------------------------------------------------------
    // Submodule 6: Function Selector Multiplexer
    // -------------------------------------------------------------------------
    function_selector #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_func_sel (
        .func_sel       (func_sel),
        .relu_data      (relu_out),
        .relu_valid     (relu_valid),
        .sigmoid_data   (sigmoid_out),
        .sigmoid_valid  (sigmoid_valid),
        .tanh_data      (tanh_out),
        .tanh_valid     (tanh_valid),
        .bypass_data    (active_data_in),
        .bypass_valid   (act_en),
        .selected_data  (final_act_data),
        .selected_valid (final_act_valid)
    );

    // -------------------------------------------------------------------------
    // Submodule 7: Output Storage Buffer
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] out_mem [0:(1<<BUF_ADDR_W)-1];
    wire [BUF_ADDR_W-1:0] mux_rd_addr = dma_out_rd_en ? dma_out_rd_addr : dir_out_rd_addr;

    always @(posedge clk) begin
        if (out_buf_wr_en) begin
            out_mem[out_buf_wr_addr] <= final_act_data;
        end
    end

    reg [DATA_WIDTH-1:0] out_mem_rd_reg;
    always @(posedge clk) begin
        out_mem_rd_reg <= out_mem[mux_rd_addr];
    end

    assign dma_out_rd_data = out_mem_rd_reg;
    assign dir_out_rd_data = out_mem_rd_reg;

endmodule
