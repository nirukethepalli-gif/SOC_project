// SPDX-License-Identifier: Apache-2.0
// Top-Level SoC Integration (soc_top)
// Project: RISC-V Based SoC for Lightweight Neural Network Inference Acceleration
// Integrates:
//   - CHIPS Alliance VeeR EL2 Core (el2_veer_wrapper, RV32IMC)
//   - 64-bit to 32-bit AXI4 to AXI4-Lite LSU & IFU Bridges
//   - 1-to-9 AXI4-Lite Interconnect Crossbar & Decoder
//   - Dual-Port IMEM (32 KB @ 0x0000_0000) & Single-Port DMEM (32 KB @ 0x1000_0000)
//   - UART (0x8000_0000), Timer (0x8000_1000), GPIO (0x8000_2000)
//   - Custom IP 1: Matrix Multiplier IP (0x8000_4000)
//   - Custom IP 2: Activation Unit IP   (0x8000_5000)
//   - Custom IP 3: DMA Controller IP    (0x8000_3000)
//   - Default DECERR Error Slave

`timescale 1ns/1ps

`include "common_defines.vh"
`include "el2_pdef.vh"

module soc_top
import el2_pkg::*;
#(
`include "el2_param.vh",
    parameter int NGPIO      = 16,
    parameter int IMEM_DEPTH = 8192, // 32 KB (8192 x 32-bit)
    parameter int DMEM_DEPTH = 8192  // 32 KB
)(
    input  logic              clk,
    input  logic              rst_n,

    // UART
    output logic              uart_tx,
    input  logic              uart_rx,

    // GPIO (Bi-directional)
    inout  wire  [NGPIO-1:0]  gpio,

    // Accelerator Top-Level Status Flags
    output logic              acc_busy,
    output logic              acc_done
);

    // =========================================================================
    // 2-FF Synchronous Reset Deassertion
    // =========================================================================
    logic rst_sync1, rst_sync2;
    wire  aresetn = rst_sync2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_sync1 <= 1'b0;
            rst_sync2 <= 1'b0;
        end else begin
            rst_sync1 <= 1'b1;
            rst_sync2 <= rst_sync1;
        end
    end

    // =========================================================================
    // VeeR EL2 Core Bus Wires
    // =========================================================================
    // IFU AXI4 Read Channel (64-bit)
    logic [pt.IFU_BUS_TAG-1:0] ifu_axi_arid;
    logic [31:0]               ifu_axi_araddr;
    logic [7:0]                ifu_axi_arlen;
    logic [2:0]                ifu_axi_arsize;
    logic [1:0]                ifu_axi_arburst;
    logic [2:0]                ifu_axi_arprot;
    logic                      ifu_axi_arvalid;
    logic                      ifu_axi_arready;
    logic [pt.IFU_BUS_TAG-1:0] ifu_axi_rid;
    logic [63:0]               ifu_axi_rdata;
    logic [1:0]                ifu_axi_rresp;
    logic                      ifu_axi_rlast;
    logic                      ifu_axi_rvalid;
    logic                      ifu_axi_rready;

    // LSU AXI4 Full Channel (64-bit)
    logic [pt.LSU_BUS_TAG-1:0] lsu_axi_awid;
    logic [31:0]               lsu_axi_awaddr;
    logic [7:0]                lsu_axi_awlen;
    logic [2:0]                lsu_axi_awsize;
    logic [1:0]                lsu_axi_awburst;
    logic [2:0]                lsu_axi_awprot;
    logic                      lsu_axi_awvalid;
    logic                      lsu_axi_awready;
    logic [63:0]               lsu_axi_wdata;
    logic [7:0]                lsu_axi_wstrb;
    logic                      lsu_axi_wlast;
    logic                      lsu_axi_wvalid;
    logic                      lsu_axi_wready;
    logic [pt.LSU_BUS_TAG-1:0] lsu_axi_bid;
    logic [1:0]                lsu_axi_bresp;
    logic                      lsu_axi_bvalid;
    logic                      lsu_axi_bready;
    logic [pt.LSU_BUS_TAG-1:0] lsu_axi_arid;
    logic [31:0]               lsu_axi_araddr;
    logic [7:0]                lsu_axi_arlen;
    logic [2:0]                lsu_axi_arsize;
    logic [1:0]                lsu_axi_arburst;
    logic [2:0]                lsu_axi_arprot;
    logic                      lsu_axi_arvalid;
    logic                      lsu_axi_arready;
    logic [pt.LSU_BUS_TAG-1:0] lsu_axi_rid;
    logic [63:0]               lsu_axi_rdata;
    logic [1:0]                lsu_axi_rresp;
    logic                      lsu_axi_rlast;
    logic                      lsu_axi_rvalid;
    logic                      lsu_axi_rready;

    // Interrupts (Routed to VeeR EL2 PIC)
    logic [pt.PIC_TOTAL_INT:1] extintsrc_req;
    logic                      irq_uart, irq_timer, irq_gpio, irq_dma, irq_mat, irq_act;

    assign extintsrc_req[1] = irq_uart;
    assign extintsrc_req[2] = irq_timer;
    assign extintsrc_req[3] = irq_dma;
    assign extintsrc_req[4] = irq_mat;
    assign extintsrc_req[5] = irq_act;
    assign extintsrc_req[6] = irq_gpio;
    assign extintsrc_req[7] = 1'b0;
    assign extintsrc_req[8] = 1'b0;

    // Dummy core export interfaces
    el2_mem_if el2_mem_export ();
    el2_mem_if el2_icache_export ();

    // =========================================================================
    // VeeR EL2 Core Instance
    // =========================================================================
    el2_veer_wrapper u_core (
        .clk             (clk),
        .rst_l           (aresetn),
        .dbg_rst_l       (aresetn),
        .rst_vec         (31'h0000_0000), // Reset vector: 0x0000_0000 (IMEM base)
        .nmi_int         (1'b0),
        .nmi_vec         (31'h1111_0000),
        .jtag_id         (31'h0),
        .core_id         (28'h0),

        // Trace ports
        .trace_rv_i_insn_ip     (),
        .trace_rv_i_address_ip  (),
        .trace_rv_i_valid_ip    (),
        .trace_rv_i_exception_ip(),
        .trace_rv_i_ecause_ip   (),
        .trace_rv_i_interrupt_ip(),
        .trace_rv_i_tval_ip     (),

        // IFU AXI4 Read Channel
        .ifu_axi_arvalid (ifu_axi_arvalid),
        .ifu_axi_arready (ifu_axi_arready),
        .ifu_axi_arid    (ifu_axi_arid),
        .ifu_axi_araddr  (ifu_axi_araddr),
        .ifu_axi_arlen   (ifu_axi_arlen),
        .ifu_axi_arsize  (ifu_axi_arsize),
        .ifu_axi_arburst (ifu_axi_arburst),
        .ifu_axi_arcache (),
        .ifu_axi_arprot  (ifu_axi_arprot),
        .ifu_axi_arqos   (),
        .ifu_axi_arregion(),
        .ifu_axi_arlock  (),
        .ifu_axi_rvalid  (ifu_axi_rvalid),
        .ifu_axi_rready  (ifu_axi_rready),
        .ifu_axi_rid     (ifu_axi_rid),
        .ifu_axi_rdata   (ifu_axi_rdata),
        .ifu_axi_rresp   (ifu_axi_rresp),
        .ifu_axi_rlast   (ifu_axi_rlast),

        // Unused IFU Write Channel tied off per Section 7.2
        .ifu_axi_awvalid (),
        .ifu_axi_awready (1'b0),
        .ifu_axi_awid    (),
        .ifu_axi_awaddr  (),
        .ifu_axi_awregion(),
        .ifu_axi_awlen   (),
        .ifu_axi_awsize  (),
        .ifu_axi_awburst (),
        .ifu_axi_awlock  (),
        .ifu_axi_awcache (),
        .ifu_axi_awprot  (),
        .ifu_axi_awqos   (),
        .ifu_axi_wvalid  (),
        .ifu_axi_wready  (1'b0),
        .ifu_axi_wdata   (),
        .ifu_axi_wstrb   (),
        .ifu_axi_wlast   (),
        .ifu_axi_bvalid  (1'b0),
        .ifu_axi_bready  (),
        .ifu_axi_bresp   (2'b00),
        .ifu_axi_bid     ({pt.IFU_BUS_TAG{1'b0}}),

        // LSU AXI4 Full Channel
        .lsu_axi_awvalid (lsu_axi_awvalid),
        .lsu_axi_awready (lsu_axi_awready),
        .lsu_axi_awid    (lsu_axi_awid),
        .lsu_axi_awaddr  (lsu_axi_awaddr),
        .lsu_axi_awregion(),
        .lsu_axi_awlen   (lsu_axi_awlen),
        .lsu_axi_awsize  (lsu_axi_awsize),
        .lsu_axi_awburst (lsu_axi_awburst),
        .lsu_axi_awlock  (),
        .lsu_axi_awcache (),
        .lsu_axi_awprot  (lsu_axi_awprot),
        .lsu_axi_awqos   (),
        .lsu_axi_wvalid  (lsu_axi_wvalid),
        .lsu_axi_wready  (lsu_axi_wready),
        .lsu_axi_wdata   (lsu_axi_wdata),
        .lsu_axi_wstrb   (lsu_axi_wstrb),
        .lsu_axi_wlast   (lsu_axi_wlast),
        .lsu_axi_bvalid  (lsu_axi_bvalid),
        .lsu_axi_bready  (lsu_axi_bready),
        .lsu_axi_bresp   (lsu_axi_bresp),
        .lsu_axi_bid     (lsu_axi_bid),
        .lsu_axi_arvalid (lsu_axi_arvalid),
        .lsu_axi_arready (lsu_axi_arready),
        .lsu_axi_arid    (lsu_axi_arid),
        .lsu_axi_araddr  (lsu_axi_araddr),
        .lsu_axi_arregion(),
        .lsu_axi_arlen   (lsu_axi_arlen),
        .lsu_axi_arsize  (lsu_axi_arsize),
        .lsu_axi_arburst (lsu_axi_arburst),
        .lsu_axi_arlock  (),
        .lsu_axi_arcache (),
        .lsu_axi_arprot  (lsu_axi_arprot),
        .lsu_axi_arqos   (),
        .lsu_axi_rvalid  (lsu_axi_rvalid),
        .lsu_axi_rready  (lsu_axi_rready),
        .lsu_axi_rid     (lsu_axi_rid),
        .lsu_axi_rdata   (lsu_axi_rdata),
        .lsu_axi_rresp   (lsu_axi_rresp),
        .lsu_axi_rlast   (lsu_axi_rlast),

        // System Bus (Debug) tied off as idle slave per Section 7.2
        .sb_axi_awvalid  (),
        .sb_axi_awready  (1'b0),
        .sb_axi_awid     (),
        .sb_axi_awaddr   (),
        .sb_axi_awregion (),
        .sb_axi_awlen    (),
        .sb_axi_awsize   (),
        .sb_axi_awburst  (),
        .sb_axi_awlock   (),
        .sb_axi_awcache  (),
        .sb_axi_awprot   (),
        .sb_axi_awqos    (),
        .sb_axi_wvalid   (),
        .sb_axi_wready   (1'b0),
        .sb_axi_wdata    (),
        .sb_axi_wstrb    (),
        .sb_axi_wlast    (),
        .sb_axi_bvalid   (1'b0),
        .sb_axi_bready   (),
        .sb_axi_bresp    (2'b00),
        .sb_axi_bid      ({pt.SB_BUS_TAG{1'b0}}),
        .sb_axi_arvalid  (),
        .sb_axi_arready  (1'b0),
        .sb_axi_arid     (),
        .sb_axi_araddr   (),
        .sb_axi_arregion (),
        .sb_axi_arlen    (),
        .sb_axi_arsize   (),
        .sb_axi_arburst  (),
        .sb_axi_arlock   (),
        .sb_axi_arcache  (),
        .sb_axi_arprot   (),
        .sb_axi_arqos    (),
        .sb_axi_rvalid   (1'b0),
        .sb_axi_rready   (),
        .sb_axi_rid      ({pt.SB_BUS_TAG{1'b0}}),
        .sb_axi_rdata    (64'h0),
        .sb_axi_rresp    (2'b00),
        .sb_axi_rlast    (1'b0),

        // DMA Slave Port tied off as idle master per Section 7.2
        .dma_axi_awvalid (1'b0),
        .dma_axi_awready (),
        .dma_axi_awid    ({pt.DMA_BUS_TAG{1'b0}}),
        .dma_axi_awaddr  (32'h0),
        .dma_axi_awsize  (3'b0),
        .dma_axi_awprot  (3'b0),
        .dma_axi_awlen   (8'h0),
        .dma_axi_awburst (2'b0),
        .dma_axi_wvalid  (1'b0),
        .dma_axi_wready  (),
        .dma_axi_wdata   (64'h0),
        .dma_axi_wstrb   (8'h0),
        .dma_axi_wlast   (1'b0),
        .dma_axi_bvalid  (),
        .dma_axi_bready  (1'b1),
        .dma_axi_bresp   (),
        .dma_axi_bid     (),
        .dma_axi_arvalid (1'b0),
        .dma_axi_arready (),
        .dma_axi_arid    ({pt.DMA_BUS_TAG{1'b0}}),
        .dma_axi_araddr  (32'h0),
        .dma_axi_arsize  (3'b0),
        .dma_axi_arprot  (3'b0),
        .dma_axi_arlen   (8'h0),
        .dma_axi_arburst (2'b0),
        .dma_axi_rvalid  (),
        .dma_axi_rready  (1'b1),
        .dma_axi_rid     (),
        .dma_axi_rdata   (),
        .dma_axi_rresp   (),
        .dma_axi_rlast   (),

        // Clock enables
        .lsu_bus_clk_en  (1'b1),
        .ifu_bus_clk_en  (1'b1),
        .dbg_bus_clk_en  (1'b1),
        .dma_bus_clk_en  (1'b1),

        // ECC errors
        .iccm_ecc_single_error(),
        .iccm_ecc_double_error(),
        .dccm_ecc_single_error(),
        .dccm_ecc_double_error(),
        .dccm_write_readback_error(),

        // Interrupts
        .timer_int       (irq_timer),
        .soft_int        (1'b0),
        .extintsrc_req   (extintsrc_req),

        // Perf counters
        .dec_tlu_perfcnt0(),
        .dec_tlu_perfcnt1(),
        .dec_tlu_perfcnt2(),
        .dec_tlu_perfcnt3(),

        // JTAG tied inactive
        .jtag_tck        (1'b0),
        .jtag_tms        (1'b1),
        .jtag_tdi        (1'b0),
        .jtag_trst_n     (1'b0),
        .jtag_tdo        (),
        .jtag_tdoEn      (),

        // MPC debug
        .mpc_debug_halt_req(1'b0),
        .mpc_debug_run_req (1'b0),
        .mpc_reset_run_req (1'b1),
        .mpc_debug_halt_ack(),
        .mpc_debug_run_ack (),
        .debug_brkpt_status(),
        .i_cpu_halt_req    (1'b0),
        .o_cpu_halt_ack    (),
        .o_cpu_halt_status (),
        .o_debug_mode_status(),
        .i_cpu_run_req     (1'b0),
        .o_cpu_run_ack     (),

        // Test mode
        .scan_mode       (1'b0),
        .mbist_mode      (1'b0),

        // DMI
        .dmi_core_enable (1'b1),
        .dmi_uncore_enable(1'b0),
        .dmi_uncore_en   (),
        .dmi_uncore_wr_en(),
        .dmi_uncore_addr (),
        .dmi_uncore_wdata(),
        .dmi_uncore_rdata(32'h0),
        .dmi_active      (),

        // Memory & Cache export interfaces
        .el2_icache_export(el2_icache_export),
        .el2_mem_export   (el2_mem_export)
    );

    // =========================================================================
    // IFU Read-Only Bridge to IMEM Port A
    // =========================================================================
    logic [31:0] ifu_lite_araddr;
    logic [2:0]  ifu_lite_arprot;
    logic        ifu_lite_arvalid;
    logic        ifu_lite_arready;
    logic [31:0] ifu_lite_rdata;
    logic [1:0]  ifu_lite_rresp;
    logic        ifu_lite_rvalid;
    logic        ifu_lite_rready;

    axi4_to_axi4lite_ro #(
        .ID_WIDTH(pt.IFU_BUS_TAG)
    ) u_ifu_bridge (
        .aclk     (clk),
        .aresetn  (aresetn),
        .s_arid   (ifu_axi_arid),
        .s_araddr (ifu_axi_araddr),
        .s_arlen  (ifu_axi_arlen),
        .s_arsize (ifu_axi_arsize),
        .s_arburst(ifu_axi_arburst),
        .s_arprot (ifu_axi_arprot),
        .s_arvalid(ifu_axi_arvalid),
        .s_arready(ifu_axi_arready),
        .s_rid    (ifu_axi_rid),
        .s_rdata  (ifu_axi_rdata),
        .s_rresp  (ifu_axi_rresp),
        .s_rlast  (ifu_axi_rlast),
        .s_rvalid (ifu_axi_rvalid),
        .s_rready (ifu_axi_rready),
        .m_araddr (ifu_lite_araddr),
        .m_arprot (ifu_lite_arprot),
        .m_arvalid(ifu_lite_arvalid),
        .m_arready(ifu_lite_arready),
        .m_rdata  (ifu_lite_rdata),
        .m_rresp  (ifu_lite_rresp),
        .m_rvalid (ifu_lite_rvalid),
        .m_rready (ifu_lite_rready)
    );

    // =========================================================================
    // LSU Full AXI4 to AXI4-Lite Bridge
    // =========================================================================
    logic [31:0] lsu_lite_awaddr;
    logic [2:0]  lsu_lite_awprot;
    logic        lsu_lite_awvalid;
    logic        lsu_lite_awready;
    logic [31:0] lsu_lite_wdata;
    logic [3:0]  lsu_lite_wstrb;
    logic        lsu_lite_wvalid;
    logic        lsu_lite_wready;
    logic [1:0]  lsu_lite_bresp;
    logic        lsu_lite_bvalid;
    logic        lsu_lite_bready;
    logic [31:0] lsu_lite_araddr;
    logic [2:0]  lsu_lite_arprot;
    logic        lsu_lite_arvalid;
    logic        lsu_lite_arready;
    logic [31:0] lsu_lite_rdata;
    logic [1:0]  lsu_lite_rresp;
    logic        lsu_lite_rvalid;
    logic        lsu_lite_rready;

    axi4_to_axi4lite #(
        .ID_WIDTH(pt.LSU_BUS_TAG)
    ) u_lsu_bridge (
        .aclk     (clk),
        .aresetn  (aresetn),
        .s_awid   (lsu_axi_awid),
        .s_awaddr (lsu_axi_awaddr),
        .s_awlen  (lsu_axi_awlen),
        .s_awsize (lsu_axi_awsize),
        .s_awburst(lsu_axi_awburst),
        .s_awprot (lsu_axi_awprot),
        .s_awvalid(lsu_axi_awvalid),
        .s_awready(lsu_axi_awready),
        .s_wdata  (lsu_axi_wdata),
        .s_wstrb  (lsu_axi_wstrb),
        .s_wlast  (lsu_axi_wlast),
        .s_wvalid (lsu_axi_wvalid),
        .s_wready (lsu_axi_wready),
        .s_bid    (lsu_axi_bid),
        .s_bresp  (lsu_axi_bresp),
        .s_bvalid (lsu_axi_bvalid),
        .s_bready (lsu_axi_bready),
        .s_arid   (lsu_axi_arid),
        .s_araddr (lsu_axi_araddr),
        .s_arlen  (lsu_axi_arlen),
        .s_arsize (lsu_axi_arsize),
        .s_arburst(lsu_axi_arburst),
        .s_arprot (lsu_axi_arprot),
        .s_arvalid(lsu_axi_arvalid),
        .s_arready(lsu_axi_arready),
        .s_rid    (lsu_axi_rid),
        .s_rdata  (lsu_axi_rdata),
        .s_rresp  (lsu_axi_rresp),
        .s_rlast  (lsu_axi_rlast),
        .s_rvalid (lsu_axi_rvalid),
        .s_rready (lsu_axi_rready),
        .m_awaddr (lsu_lite_awaddr),
        .m_awprot (lsu_lite_awprot),
        .m_awvalid(lsu_lite_awvalid),
        .m_awready(lsu_lite_awready),
        .m_wdata  (lsu_lite_wdata),
        .m_wstrb  (lsu_lite_wstrb),
        .m_wvalid (lsu_lite_wvalid),
        .m_wready (lsu_lite_wready),
        .m_bresp  (lsu_lite_bresp),
        .m_bvalid (lsu_lite_bvalid),
        .m_bready (lsu_lite_bready),
        .m_araddr (lsu_lite_araddr),
        .m_arprot (lsu_lite_arprot),
        .m_arvalid(lsu_lite_arvalid),
        .m_arready(lsu_lite_arready),
        .m_rdata  (lsu_lite_rdata),
        .m_rresp  (lsu_lite_rresp),
        .m_rvalid (lsu_lite_rvalid),
        .m_rready (lsu_lite_rready)
    );

    // =========================================================================
    // 1-to-9 AXI4-Lite Interconnect Crossbar
    // =========================================================================
    localparam int NSLV = 9;
    logic [NSLV-1:0][31:0] s_awaddr;
    logic [NSLV-1:0][2:0]  s_awprot;
    logic [NSLV-1:0]       s_awvalid;
    logic [NSLV-1:0]       s_awready;
    logic [NSLV-1:0][31:0] s_wdata;
    logic [NSLV-1:0][3:0]  s_wstrb;
    logic [NSLV-1:0]       s_wvalid;
    logic [NSLV-1:0]       s_wready;
    logic [NSLV-1:0][1:0]  s_bresp;
    logic [NSLV-1:0]       s_bvalid;
    logic [NSLV-1:0]       s_bready;
    logic [NSLV-1:0][31:0] s_araddr;
    logic [NSLV-1:0][2:0]  s_arprot;
    logic [NSLV-1:0]       s_arvalid;
    logic [NSLV-1:0]       s_arready;
    logic [NSLV-1:0][31:0] s_rdata;
    logic [NSLV-1:0][1:0]  s_rresp;
    logic [NSLV-1:0]       s_rvalid;
    logic [NSLV-1:0]       s_rready;

    axi4lite_interconnect #(
        .NSLV(NSLV)
    ) u_interconnect (
        .aclk     (clk),
        .aresetn  (aresetn),
        .m_awaddr (lsu_lite_awaddr),
        .m_awprot (lsu_lite_awprot),
        .m_awvalid(lsu_lite_awvalid),
        .m_awready(lsu_lite_awready),
        .m_wdata  (lsu_lite_wdata),
        .m_wstrb  (lsu_lite_wstrb),
        .m_wvalid (lsu_lite_wvalid),
        .m_wready (lsu_lite_wready),
        .m_bresp  (lsu_lite_bresp),
        .m_bvalid (lsu_lite_bvalid),
        .m_bready (lsu_lite_bready),
        .m_araddr (lsu_lite_araddr),
        .m_arprot (lsu_lite_arprot),
        .m_arvalid(lsu_lite_arvalid),
        .m_arready(lsu_lite_arready),
        .m_rdata  (lsu_lite_rdata),
        .m_rresp  (lsu_lite_rresp),
        .m_rvalid (lsu_lite_rvalid),
        .m_rready (lsu_lite_rready),
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
        .s_rready (s_rready)
    );

    // =========================================================================
    // Slave 0: Dual-Port Instruction Memory (32 KB @ 0x0000_0000)
    // =========================================================================
    axi4lite_sram_dp #(
        .DEPTH_WORDS(IMEM_DEPTH)
    ) u_imem (
        .aclk       (clk),
        .aresetn    (aresetn),
        .s_a_araddr (ifu_lite_araddr),
        .s_a_arprot (ifu_lite_arprot),
        .s_a_arvalid(ifu_lite_arvalid),
        .s_a_arready(ifu_lite_arready),
        .s_a_rdata  (ifu_lite_rdata),
        .s_a_rresp  (ifu_lite_rresp),
        .s_a_rvalid (ifu_lite_rvalid),
        .s_a_rready (ifu_lite_rready),
        .s_b_awaddr (s_awaddr[0]),
        .s_b_awprot (s_awprot[0]),
        .s_b_awvalid(s_awvalid[0]),
        .s_b_awready(s_awready[0]),
        .s_b_wdata  (s_wdata[0]),
        .s_b_wstrb  (s_wstrb[0]),
        .s_b_wvalid (s_wvalid[0]),
        .s_b_wready (s_wready[0]),
        .s_b_bresp  (s_bresp[0]),
        .s_b_bvalid (s_bvalid[0]),
        .s_b_bready (s_bready[0]),
        .s_b_araddr (s_araddr[0]),
        .s_b_arprot (s_arprot[0]),
        .s_b_arvalid(s_arvalid[0]),
        .s_b_arready(s_arready[0]),
        .s_b_rdata  (s_rdata[0]),
        .s_b_rresp  (s_rresp[0]),
        .s_b_rvalid (s_rvalid[0]),
        .s_b_rready (s_rready[0])
    );

    // =========================================================================
    // DMA Master Memory Bus & Data Memory Mux
    // =========================================================================
    logic [31:0] dma_m_araddr;
    logic [7:0]  dma_m_arlen;
    logic [2:0]  dma_m_arsize;
    logic [1:0]  dma_m_arburst;
    logic        dma_m_arvalid;
    logic        dma_m_arready;
    logic [31:0] dma_m_rdata;
    logic [1:0]  dma_m_rresp;
    logic        dma_m_rlast;
    logic        dma_m_rvalid;
    logic        dma_m_rready;

    logic [31:0] dma_m_awaddr;
    logic [7:0]  dma_m_awlen;
    logic [2:0]  dma_m_awsize;
    logic [1:0]  dma_m_awburst;
    logic        dma_m_awvalid;
    logic        dma_m_awready;
    logic [31:0] dma_m_wdata;
    logic [3:0]  dma_m_wstrb;
    logic        dma_m_wlast;
    logic        dma_m_wvalid;
    logic        dma_m_wready;
    logic [1:0]  dma_m_bresp;
    logic        dma_m_bvalid;
    logic        dma_m_bready;

    // Arbiter between LSU Slave 1 and DMA Master for DMEM
    wire dma_accessing_dmem = dma_m_arvalid | dma_m_awvalid;

    wire [31:0] dmem_awaddr  = dma_accessing_dmem ? dma_m_awaddr  : s_awaddr[1];
    wire [2:0]  dmem_awprot  = dma_accessing_dmem ? 3'b000        : s_awprot[1];
    wire        dmem_awvalid = dma_accessing_dmem ? dma_m_awvalid : s_awvalid[1];
    wire        dmem_awready;

    wire [31:0] dmem_wdata   = dma_accessing_dmem ? dma_m_wdata   : s_wdata[1];
    wire [3:0]  dmem_wstrb   = dma_accessing_dmem ? dma_m_wstrb   : s_wstrb[1];
    wire        dmem_wvalid  = dma_accessing_dmem ? dma_m_wvalid  : s_wvalid[1];
    wire        dmem_wready;

    wire [1:0]  dmem_bresp;
    wire        dmem_bvalid;
    wire        dmem_bready  = dma_accessing_dmem ? dma_m_bready  : s_bready[1];

    wire [31:0] dmem_araddr  = dma_accessing_dmem ? dma_m_araddr  : s_araddr[1];
    wire [2:0]  dmem_arprot  = dma_accessing_dmem ? 3'b000        : s_arprot[1];
    wire        dmem_arvalid = dma_accessing_dmem ? dma_m_arvalid : s_arvalid[1];
    wire        dmem_arready;

    wire [31:0] dmem_rdata;
    wire [1:0]  dmem_rresp;
    wire        dmem_rvalid;
    wire        dmem_rready  = dma_accessing_dmem ? dma_m_rready  : s_rready[1];

    assign dma_m_awready = dma_accessing_dmem ? dmem_awready : 1'b0;
    assign dma_m_wready  = dma_accessing_dmem ? dmem_wready  : 1'b0;
    assign dma_m_bresp   = dmem_bresp;
    assign dma_m_bvalid  = dma_accessing_dmem ? dmem_bvalid  : 1'b0;
    assign dma_m_arready = dma_accessing_dmem ? dmem_arready : 1'b0;
    assign dma_m_rdata   = dmem_rdata;
    assign dma_m_rresp   = dmem_rresp;
    assign dma_m_rlast   = 1'b1;
    assign dma_m_rvalid  = dma_accessing_dmem ? dmem_rvalid  : 1'b0;

    assign s_awready[1]  = dma_accessing_dmem ? 1'b0 : dmem_awready;
    assign s_wready[1]   = dma_accessing_dmem ? 1'b0 : dmem_wready;
    assign s_bresp[1]    = dmem_bresp;
    assign s_bvalid[1]   = dma_accessing_dmem ? 1'b0 : dmem_bvalid;
    assign s_arready[1]  = dma_accessing_dmem ? 1'b0 : dmem_arready;
    assign s_rdata[1]    = dmem_rdata;
    assign s_rresp[1]    = dmem_rresp;
    assign s_rvalid[1]   = dma_accessing_dmem ? 1'b0 : dmem_rvalid;

    // Slave 1: Single-Port Data Memory (32 KB @ 0x1000_0000)
    axi4lite_sram #(
        .DEPTH_WORDS(DMEM_DEPTH)
    ) u_dmem (
        .aclk     (clk),
        .aresetn  (aresetn),
        .s_awaddr (dmem_awaddr),
        .s_awprot (dmem_awprot),
        .s_awvalid(dmem_awvalid),
        .s_awready(dmem_awready),
        .s_wdata  (dmem_wdata),
        .s_wstrb  (dmem_wstrb),
        .s_wvalid (dmem_wvalid),
        .s_wready (dmem_wready),
        .s_bresp  (dmem_bresp),
        .s_bvalid (dmem_bvalid),
        .s_bready (dmem_bready),
        .s_araddr (dmem_araddr),
        .s_arprot (dmem_arprot),
        .s_arvalid(dmem_arvalid),
        .s_arready(dmem_arready),
        .s_rdata  (dmem_rdata),
        .s_rresp  (dmem_rresp),
        .s_rvalid (dmem_rvalid),
        .s_rready (dmem_rready)
    );

    // =========================================================================
    // Slave 2: UART (Base 0x8000_0000)
    // =========================================================================
    uart u_uart (
        .aclk     (clk),
        .aresetn  (aresetn),
        .s_awaddr (s_awaddr[2]),
        .s_awprot (s_awprot[2]),
        .s_awvalid(s_awvalid[2]),
        .s_awready(s_awready[2]),
        .s_wdata  (s_wdata[2]),
        .s_wstrb  (s_wstrb[2]),
        .s_wvalid (s_wvalid[2]),
        .s_wready (s_wready[2]),
        .s_bresp  (s_bresp[2]),
        .s_bvalid (s_bvalid[2]),
        .s_bready (s_bready[2]),
        .s_araddr (s_araddr[2]),
        .s_arprot (s_arprot[2]),
        .s_arvalid(s_arvalid[2]),
        .s_arready(s_arready[2]),
        .s_rdata  (s_rdata[2]),
        .s_rresp  (s_rresp[2]),
        .s_rvalid (s_rvalid[2]),
        .s_rready (s_rready[2]),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .irq      (irq_uart)
    );

    // =========================================================================
    // Slave 3: Timer (Base 0x8000_1000)
    // =========================================================================
    timer u_timer (
        .aclk     (clk),
        .aresetn  (aresetn),
        .s_awaddr (s_awaddr[3]),
        .s_awprot (s_awprot[3]),
        .s_awvalid(s_awvalid[3]),
        .s_awready(s_awready[3]),
        .s_wdata  (s_wdata[3]),
        .s_wstrb  (s_wstrb[3]),
        .s_wvalid (s_wvalid[3]),
        .s_wready (s_wready[3]),
        .s_bresp  (s_bresp[3]),
        .s_bvalid (s_bvalid[3]),
        .s_bready (s_bready[3]),
        .s_araddr (s_araddr[3]),
        .s_arprot (s_arprot[3]),
        .s_arvalid(s_arvalid[3]),
        .s_arready(s_arready[3]),
        .s_rdata  (s_rdata[3]),
        .s_rresp  (s_rresp[3]),
        .s_rvalid (s_rvalid[3]),
        .s_rready (s_rready[3]),
        .irq      (irq_timer)
    );

    // =========================================================================
    // Slave 4: GPIO (Base 0x8000_2000)
    // =========================================================================
    logic [NGPIO-1:0] gpio_in, gpio_out, gpio_oe;

    gpio #(
        .NGPIO(NGPIO)
    ) u_gpio (
        .aclk     (clk),
        .aresetn  (aresetn),
        .s_awaddr (s_awaddr[4]),
        .s_awprot (s_awprot[4]),
        .s_awvalid(s_awvalid[4]),
        .s_awready(s_awready[4]),
        .s_wdata  (s_wdata[4]),
        .s_wstrb  (s_wstrb[4]),
        .s_wvalid (s_wvalid[4]),
        .s_wready (s_wready[4]),
        .s_bresp  (s_bresp[4]),
        .s_bvalid (s_bvalid[4]),
        .s_bready (s_bready[4]),
        .s_araddr (s_araddr[4]),
        .s_arprot (s_arprot[4]),
        .s_arvalid(s_arvalid[4]),
        .s_arready(s_arready[4]),
        .s_rdata  (s_rdata[4]),
        .s_rresp  (s_rresp[4]),
        .s_rvalid (s_rvalid[4]),
        .s_rready (s_rready[4]),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .gpio_oe  (gpio_oe),
        .irq      (irq_gpio)
    );

    genvar gi;
    generate
        for (gi = 0; gi < NGPIO; gi++) begin : gen_gpio_tri
            assign gpio[gi]    = gpio_oe[gi] ? gpio_out[gi] : 1'bz;
            assign gpio_in[gi] = gpio[gi];
        end
    endgenerate

    // =========================================================================
    // Dedicated Accelerator Connections
    // =========================================================================
    logic        dma_in_wr_en, dma_w_wr_en, dma_bias_wr_en, dma_out_rd_en, dma_act_rd_en;
    logic [7:0]  dma_in_wr_addr, dma_bias_wr_addr, dma_out_rd_addr, dma_act_rd_addr;
    logic [9:0]  dma_w_wr_addr;
    logic [31:0] dma_in_wr_data, dma_w_wr_data, dma_bias_wr_data, dma_out_rd_data, dma_act_rd_data;

    logic [31:0] stream_act_data;
    logic        stream_act_valid;
    logic        stream_act_ready;

    logic mat_busy, mat_done, act_busy, act_done, dma_busy, dma_done, dma_error;

    assign acc_busy = mat_busy | act_busy | dma_busy;
    assign acc_done = act_done;

    // =========================================================================
    // Slave 5: DMA Controller IP (Base 0x8000_3000)
    // =========================================================================
    dma_controller u_dma (
        .aclk             (clk),
        .aresetn          (aresetn),
        .s_awaddr         (s_awaddr[5]),
        .s_awprot         (s_awprot[5]),
        .s_awvalid        (s_awvalid[5]),
        .s_awready        (s_awready[5]),
        .s_wdata          (s_wdata[5]),
        .s_wstrb          (s_wstrb[5]),
        .s_wvalid         (s_wvalid[5]),
        .s_wready         (s_wready[5]),
        .s_bresp          (s_bresp[5]),
        .s_bvalid         (s_bvalid[5]),
        .s_bready         (s_bready[5]),
        .s_araddr         (s_araddr[5]),
        .s_arprot         (s_arprot[5]),
        .s_arvalid        (s_arvalid[5]),
        .s_arready        (s_arready[5]),
        .s_rdata          (s_rdata[5]),
        .s_rresp          (s_rresp[5]),
        .s_rvalid         (s_rvalid[5]),
        .s_rready         (s_rready[5]),
        .m_axi_araddr     (dma_m_araddr),
        .m_axi_arlen      (dma_m_arlen),
        .m_axi_arsize     (dma_m_arsize),
        .m_axi_arburst    (dma_m_arburst),
        .m_axi_arvalid    (dma_m_arvalid),
        .m_axi_arready    (dma_m_arready),
        .m_axi_rdata      (dma_m_rdata),
        .m_axi_rresp      (dma_m_rresp),
        .m_axi_rlast      (dma_m_rlast),
        .m_axi_rvalid     (dma_m_rvalid),
        .m_axi_rready     (dma_m_rready),
        .m_axi_awaddr     (dma_m_awaddr),
        .m_axi_awlen      (dma_m_awlen),
        .m_axi_awsize     (dma_m_awsize),
        .m_axi_awburst    (dma_m_awburst),
        .m_axi_awvalid    (dma_m_awvalid),
        .m_axi_awready    (dma_m_awready),
        .m_axi_wdata      (dma_m_wdata),
        .m_axi_wstrb      (dma_m_wstrb),
        .m_axi_wlast      (dma_m_wlast),
        .m_axi_wvalid     (dma_m_wvalid),
        .m_axi_wready     (dma_m_wready),
        .m_axi_bresp      (dma_m_bresp),
        .m_axi_bvalid     (dma_m_bvalid),
        .m_axi_bready     (dma_m_bready),
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
        .dma_act_rd_data  (dma_act_rd_data),
        .busy             (dma_busy),
        .done             (dma_done),
        .error            (dma_error),
        .irq              (irq_dma)
    );

    // =========================================================================
    // Slave 6: Matrix Multiplier IP (Base 0x8000_4000)
    // =========================================================================
    matrix_multiplier u_mat_mult (
        .aclk             (clk),
        .aresetn          (aresetn),
        .s_awaddr         (s_awaddr[6]),
        .s_awprot         (s_awprot[6]),
        .s_awvalid        (s_awvalid[6]),
        .s_awready        (s_awready[6]),
        .s_wdata          (s_wdata[6]),
        .s_wstrb          (s_wstrb[6]),
        .s_wvalid         (s_wvalid[6]),
        .s_wready         (s_wready[6]),
        .s_bresp          (s_bresp[6]),
        .s_bvalid         (s_bvalid[6]),
        .s_bready         (s_bready[6]),
        .s_araddr         (s_araddr[6]),
        .s_arprot         (s_arprot[6]),
        .s_arvalid        (s_arvalid[6]),
        .s_arready        (s_arready[6]),
        .s_rdata          (s_rdata[6]),
        .s_rresp          (s_rresp[6]),
        .s_rvalid         (s_rvalid[6]),
        .s_rready         (s_rready[6]),
        .dma_in_wr_en     (dma_in_wr_en),
        .dma_in_wr_addr   (dma_in_wr_addr),
        .dma_in_wr_data   (dma_in_wr_data),
        .dma_w_wr_en      (dma_w_wr_en),
        .dma_w_wr_addr    (dma_w_wr_addr),
        .dma_w_wr_data    (dma_w_wr_data),
        .dma_bias_wr_en   (dma_bias_wr_en),
        .dma_bias_wr_addr (dma_bias_wr_addr),
        .dma_bias_wr_data (dma_bias_wr_data),
        .dma_out_rd_en    (dma_out_rd_en),
        .dma_out_rd_addr  (dma_out_rd_addr),
        .dma_out_rd_data  (dma_out_rd_data),
        .stream_act_data  (stream_act_data),
        .stream_act_valid (stream_act_valid),
        .stream_act_ready (stream_act_ready),
        .busy             (mat_busy),
        .done             (mat_done),
        .irq              (irq_mat)
    );

    // =========================================================================
    // Slave 7: Activation Unit IP (Base 0x8000_5000)
    // =========================================================================
    activation_unit u_activation (
        .aclk             (clk),
        .aresetn          (aresetn),
        .s_awaddr         (s_awaddr[7]),
        .s_awprot         (s_awprot[7]),
        .s_awvalid        (s_awvalid[7]),
        .s_awready        (s_awready[7]),
        .s_wdata          (s_wdata[7]),
        .s_wstrb          (s_wstrb[7]),
        .s_wvalid         (s_wvalid[7]),
        .s_wready         (s_wready[7]),
        .s_bresp          (s_bresp[7]),
        .s_bvalid         (s_bvalid[7]),
        .s_bready         (s_bready[7]),
        .s_araddr         (s_araddr[7]),
        .s_arprot         (s_arprot[7]),
        .s_arvalid        (s_arvalid[7]),
        .s_arready        (s_arready[7]),
        .s_rdata          (s_rdata[7]),
        .s_rresp          (s_rresp[7]),
        .s_rvalid         (s_rvalid[7]),
        .s_rready         (s_rready[7]),
        .stream_in_data   (stream_act_data),
        .stream_in_valid  (stream_act_valid),
        .stream_in_ready  (stream_act_ready),
        .dma_out_rd_en    (dma_act_rd_en),
        .dma_out_rd_addr  (dma_act_rd_addr),
        .dma_out_rd_data  (dma_act_rd_data),
        .busy             (act_busy),
        .done             (act_done),
        .irq              (irq_act)
    );

    // =========================================================================
    // Slave 8: Decode Error Slave (DECERR on unmapped addresses)
    // =========================================================================
    axi4lite_err_slave u_err_slave (
        .aclk     (clk),
        .aresetn  (aresetn),
        .s_awaddr (s_awaddr[8]),
        .s_awprot (s_awprot[8]),
        .s_awvalid(s_awvalid[8]),
        .s_awready(s_awready[8]),
        .s_wdata  (s_wdata[8]),
        .s_wstrb  (s_wstrb[8]),
        .s_wvalid (s_wvalid[8]),
        .s_wready (s_wready[8]),
        .s_bresp  (s_bresp[8]),
        .s_bvalid (s_bvalid[8]),
        .s_bready (s_bready[8]),
        .s_araddr (s_araddr[8]),
        .s_arprot (s_arprot[8]),
        .s_arvalid(s_arvalid[8]),
        .s_arready(s_arready[8]),
        .s_rdata  (s_rdata[8]),
        .s_rresp  (s_rresp[8]),
        .s_rvalid (s_rvalid[8]),
        .s_rready (s_rready[8])
    );

endmodule
