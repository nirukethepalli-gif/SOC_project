// ============================================================================
// Module Name: dma_top
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Top-Level Module of Custom IP 3: DMA Controller.
//              Features:
//                - AXI4-Lite Slave Interface for CPU configuration/status.
//                - AXI4 Master Interface for reading/writing Data Memory.
//                - Direct datapath links to Matrix Multiplier and Activation Unit.
//                - Autonomous block data transfers without CPU intervention.
// ============================================================================

`timescale 1ns / 1ps

module dma_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
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
    // AXI4 Master Memory Interface (Data Memory Read/Write)
    // -------------------------------------------------------------------------
    // Read Address Channel
    output wire [ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]             m_axi_arlen,
    output wire [2:0]             m_axi_arsize,
    output wire [1:0]             m_axi_arburst,
    output wire                   m_axi_arvalid,
    input  wire                   m_axi_arready,

    // Read Data Channel
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rlast,
    input  wire                   m_axi_rvalid,
    output wire                   m_axi_rready,

    // Write Address Channel
    output wire [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]             m_axi_awlen,
    output wire [2:0]             m_axi_awsize,
    output wire [1:0]             m_axi_awburst,
    output wire                   m_axi_awvalid,
    input  wire                   m_axi_awready,

    // Write Data Channel
    output wire [DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [3:0]             m_axi_wstrb,
    output wire                   m_axi_wlast,
    output wire                   m_axi_wvalid,
    input  wire                   m_axi_wready,

    // Write Response Channel
    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output wire                   m_axi_bready,

    // -------------------------------------------------------------------------
    // Direct Dedicated Links to Matrix Multiplier Buffers
    // -------------------------------------------------------------------------
    output wire                   dma_in_wr_en,
    output wire [7:0]             dma_in_wr_addr,
    output wire [DATA_WIDTH-1:0]  dma_in_wr_data,

    output wire                   dma_w_wr_en,
    output wire [9:0]             dma_w_wr_addr,
    output wire [DATA_WIDTH-1:0]  dma_w_wr_data,

    output wire                   dma_bias_wr_en,
    output wire [7:0]             dma_bias_wr_addr,
    output wire [DATA_WIDTH-1:0]  dma_bias_wr_data,

    // -------------------------------------------------------------------------
    // Direct Dedicated Link from Activation Unit Output Buffer
    // -------------------------------------------------------------------------
    output wire                   dma_act_rd_en,
    output wire [7:0]             dma_act_rd_addr,
    input  wire [DATA_WIDTH-1:0]  dma_act_rd_data,

    // -------------------------------------------------------------------------
    // Status & Interrupt
    // -------------------------------------------------------------------------
    output wire                   busy,
    output wire                   done,
    output wire                   error,
    output wire                   irq
);

    // Internal Control Signals
    wire ctrl_start;
    wire ctrl_soft_reset;
    wire direction;
    wire [1:0] acc_target;
    wire [ADDR_WIDTH-1:0] reg_src_addr;
    wire [ADDR_WIDTH-1:0] reg_dst_addr;
    wire [15:0] reg_burst_len;

    // Address Generator Wires
    wire load_init;
    wire step_src;
    wire step_dst;
    wire [ADDR_WIDTH-1:0] curr_src_addr;
    wire [ADDR_WIDTH-1:0] curr_dst_addr;
    wire [15:0] words_remaining;
    wire transfer_complete;
    wire align_error;

    // Read Controller Wires
    wire start_read;
    wire read_busy;
    wire read_done;
    wire read_error;
    wire [DATA_WIDTH-1:0] fifo_read_data;
    wire fifo_read_valid;

    // Write Controller Wires
    wire start_write;
    wire write_busy;
    wire write_done;
    wire write_error;
    wire [DATA_WIDTH-1:0] fifo_write_data;
    wire fifo_write_valid;
    wire fifo_write_rd_en;

    // Stage control
    wire stage_data_en;

    assign irq = done;

    // -------------------------------------------------------------------------
    // Submodule 1: AXI4-Lite Register File
    // -------------------------------------------------------------------------
    dma_registers #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(8)
    ) u_regs (
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
        .direction        (direction),
        .acc_target       (acc_target),
        .src_addr         (reg_src_addr),
        .dst_addr         (reg_dst_addr),
        .burst_len        (reg_burst_len),

        .status_done      (done),
        .status_busy      (busy),
        .status_error     (error)
    );

    // -------------------------------------------------------------------------
    // Submodule 2: Address Generator & Counter
    // -------------------------------------------------------------------------
    address_generator #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_addr_gen (
        .clk               (clk),
        .rst_n             (rst_n),
        .load_init         (load_init),
        .init_src_addr     (reg_src_addr),
        .init_dst_addr     (reg_dst_addr),
        .init_transfer_len (reg_burst_len),
        .step_src          (step_src),
        .step_dst          (step_dst),
        .curr_src_addr     (curr_src_addr),
        .curr_dst_addr     (curr_dst_addr),
        .words_remaining   (words_remaining),
        .transfer_complete (transfer_complete),
        .align_error       (align_error)
    );

    // -------------------------------------------------------------------------
    // Submodule 3: AXI4 Master Read Controller
    // -------------------------------------------------------------------------
    dma_read_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_read_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),
        .start_read    (start_read),
        .read_addr     (curr_src_addr),
        .burst_len_axi (8'd0), // Single word beat per transaction step
        .read_busy     (read_busy),
        .read_done     (read_done),
        .read_error    (read_error),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen   (m_axi_arlen),
        .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst (m_axi_arburst),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arready (m_axi_arready),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rlast   (m_axi_rlast),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rready  (m_axi_rready),
        .fifo_wr_data  (fifo_read_data),
        .fifo_wr_en    (fifo_read_valid)
    );

    // -------------------------------------------------------------------------
    // Submodule 4: AXI4 Master Write Controller
    // -------------------------------------------------------------------------
    dma_write_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_write_ctrl (
        .clk           (clk),
        .rst_n         (rst_n),
        .start_write   (start_write),
        .write_addr    (curr_dst_addr),
        .burst_len_axi (8'd0),
        .write_busy    (write_busy),
        .write_done    (write_done),
        .write_error   (write_error),
        .fifo_rd_data  (fifo_write_data),
        .fifo_empty    (!fifo_write_valid),
        .fifo_rd_en    (fifo_write_rd_en),
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awlen   (m_axi_awlen),
        .m_axi_awsize  (m_axi_awsize),
        .m_axi_awburst (m_axi_awburst),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awready (m_axi_awready),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wlast   (m_axi_wlast),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wready  (m_axi_wready),
        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready)
    );

    // -------------------------------------------------------------------------
    // Submodule 5: Transfer Engine & Data Routing
    // -------------------------------------------------------------------------
    dma_transfer_engine #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_transfer_engine (
        .clk              (clk),
        .rst_n            (rst_n),
        .direction        (direction),
        .acc_target       (acc_target),
        .curr_dst_addr    (curr_dst_addr),
        .curr_src_addr    (curr_src_addr),
        .mem_rd_data      (fifo_read_data),
        .mem_rd_valid     (fifo_read_valid),
        .mem_wr_data      (fifo_write_data),
        .mem_wr_valid     (fifo_write_valid),
        .mem_wr_rd_en     (fifo_write_rd_en),
        .dma_in_wr_en     (dma_in_wr_en),
        .dma_in_wr_addr   (dma_in_wr_addr),
        .dma_in_wr_data   (dma_in_wr_data),
        .dma_w_wr_en      (dma_w_wr_en),
        .dma_w_wr_addr    (dma_w_wr_addr),
        .dma_w_wr_data    (dma_w_wr_data),
        .dma_bias_wr_en   (dma_bias_wr_en),
        .dma_bias_wr_addr (dma_bias_wr_addr),
        .dma_bias_wr_data (dma_bias_wr_data),
        .dma_act_rd_en    (dma_act_rd_en),
        .dma_act_rd_addr  (dma_act_rd_addr),
        .dma_act_rd_data  (dma_act_rd_data)
    );

    // -------------------------------------------------------------------------
    // Submodule 6: Main DMA FSM
    // -------------------------------------------------------------------------
    dma_fsm u_dma_fsm (
        .clk               (clk),
        .rst_n             (rst_n),
        .ctrl_start        (ctrl_start),
        .ctrl_soft_reset   (ctrl_soft_reset),
        .direction         (direction),
        .acc_target        (acc_target),
        .status_busy       (busy),
        .status_done       (done),
        .status_error      (error),
        .load_init         (load_init),
        .step_src          (step_src),
        .step_dst          (step_dst),
        .transfer_complete (transfer_complete),
        .align_error       (align_error),
        .start_read        (start_read),
        .read_busy         (read_busy),
        .read_done         (read_done),
        .read_error        (read_error),
        .start_write       (start_write),
        .write_busy        (write_busy),
        .write_done        (write_done),
        .write_error       (write_error),
        .stage_data_en     (stage_data_en),
        .stage_busy        (1'b0)
    );

endmodule
