// ============================================================================
// Module Name: soc_top
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Top-Level Integration of the complete RISC-V Neural Network SoC.
//              Integrates:
//                1. RISC-V Processor Core (RV32I / VeeR-EL2 compatible)
//                2. 64 KB Instruction Memory (0x0000_0000)
//                3. 64 KB Shared Data Memory (0x0001_0000)
//                4. AXI4 to AXI4-Lite Bridge
//                5. System Address Decoder & Interconnect Crossbar
//                6. Custom IP 1: Matrix Multiplier (0x0003_0000)
//                7. Custom IP 2: Activation Unit (0x0003_0100)
//                8. Custom IP 3: DMA Controller (0x0003_0200)
//                9. Peripherals: UART (0x0002_0000), Timer (0x0002_0100), GPIO
// ============================================================================

`timescale 1ns / 1ps

module soc_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // External UART Pins
    output wire                   uart_tx,
    input  wire                   uart_rx,

    // External GPIO Pins
    output wire [7:0]             gpio_out,
    input  wire [7:0]             gpio_in,

    // External Top-Level Status Flags
    output wire                   acc_busy,
    output wire                   acc_done
);

    // =========================================================================
    // Core Instruction & Data Bus Wires
    // =========================================================================
    wire [ADDR_WIDTH-1:0] core_imem_addr;
    wire [DATA_WIDTH-1:0] core_imem_data;

    // Core AXI4 Master
    wire [ADDR_WIDTH-1:0] core_m_awaddr;
    wire [7:0]            core_m_awlen;
    wire [2:0]            core_m_awsize;
    wire [1:0]            core_m_awburst;
    wire [2:0]            core_m_awprot;
    wire                  core_m_awvalid;
    wire                  core_m_awready;
    wire [DATA_WIDTH-1:0] core_m_wdata;
    wire [3:0]            core_m_wstrb;
    wire                  core_m_wlast;
    wire                  core_m_wvalid;
    wire                  core_m_wready;
    wire [1:0]            core_m_bresp;
    wire                  core_m_bvalid;
    wire                  core_m_bready;
    wire [ADDR_WIDTH-1:0] core_m_araddr;
    wire [7:0]            core_m_arlen;
    wire [2:0]            core_m_arsize;
    wire [1:0]            core_m_arburst;
    wire [2:0]            core_m_arprot;
    wire                  core_m_arvalid;
    wire                  core_m_arready;
    wire [DATA_WIDTH-1:0] core_m_rdata;
    wire [1:0]            core_m_rresp;
    wire                  core_m_rlast;
    wire                  core_m_rvalid;
    wire                  core_m_rready;

    // Interrupts
    wire timer_irq, uart_irq, dma_irq, mat_irq, act_irq;
    wire core_irq = timer_irq | uart_irq | dma_irq | mat_irq | act_irq;

    // =========================================================================
    // DMA Master AXI4 Memory Interface Wires
    // =========================================================================
    wire [ADDR_WIDTH-1:0] dma_m_araddr;
    wire [7:0]            dma_m_arlen;
    wire [2:0]            dma_m_arsize;
    wire [1:0]            dma_m_arburst;
    wire                  dma_m_arvalid;
    wire                  dma_m_arready;
    wire [DATA_WIDTH-1:0] dma_m_rdata;
    wire [1:0]            dma_m_rresp;
    wire                  dma_m_rlast;
    wire                  dma_m_rvalid;
    wire                  dma_m_rready;

    wire [ADDR_WIDTH-1:0] dma_m_awaddr;
    wire [7:0]            dma_m_awlen;
    wire [2:0]            dma_m_awsize;
    wire [1:0]            dma_m_awburst;
    wire                  dma_m_awvalid;
    wire                  dma_m_awready;
    wire [DATA_WIDTH-1:0] dma_m_wdata;
    wire [3:0]            dma_m_wstrb;
    wire                  dma_m_wlast;
    wire                  dma_m_wvalid;
    wire                  dma_m_wready;
    wire [1:0]            dma_m_bresp;
    wire                  dma_m_bvalid;
    wire                  dma_m_bready;

    // =========================================================================
    // Data Memory Bus Arbiter (Multiplexing CPU & DMA access to Data Memory)
    // =========================================================================
    wire dma_owns_bus = dma_m_arvalid | dma_m_awvalid;

    wire [ADDR_WIDTH-1:0] dmem_awaddr  = dma_owns_bus ? dma_m_awaddr  : core_m_awaddr;
    wire [7:0]            dmem_awlen   = dma_owns_bus ? dma_m_awlen   : core_m_awlen;
    wire [2:0]            dmem_awsize  = dma_owns_bus ? dma_m_awsize  : core_m_awsize;
    wire [1:0]            dmem_awburst = dma_owns_bus ? dma_m_awburst : core_m_awburst;
    wire                  dmem_awvalid = dma_owns_bus ? dma_m_awvalid : (core_m_awvalid & (core_m_awaddr[31:16] == 16'h0001));
    wire                  dmem_awready;

    wire [DATA_WIDTH-1:0] dmem_wdata  = dma_owns_bus ? dma_m_wdata  : core_m_wdata;
    wire [3:0]            dmem_wstrb  = dma_owns_bus ? dma_m_wstrb  : core_m_wstrb;
    wire                  dmem_wlast  = dma_owns_bus ? dma_m_wlast  : core_m_wlast;
    wire                  dmem_wvalid = dma_owns_bus ? dma_m_wvalid : (core_m_wvalid & (core_m_awaddr[31:16] == 16'h0001));
    wire                  dmem_wready;

    wire [1:0]            dmem_bresp;
    wire                  dmem_bvalid;
    wire                  dmem_bready = dma_owns_bus ? dma_m_bready : core_m_bready;

    wire [ADDR_WIDTH-1:0] dmem_araddr  = dma_owns_bus ? dma_m_araddr  : core_m_araddr;
    wire [7:0]            dmem_arlen   = dma_owns_bus ? dma_m_arlen   : core_m_arlen;
    wire [2:0]            dmem_arsize  = dma_owns_bus ? dma_m_arsize  : core_m_arsize;
    wire [1:0]            dmem_arburst = dma_owns_bus ? dma_m_arburst : core_m_arburst;
    wire                  dmem_arvalid = dma_owns_bus ? dma_m_arvalid : (core_m_arvalid & (core_m_araddr[31:16] == 16'h0001));
    wire                  dmem_arready;

    wire [DATA_WIDTH-1:0] dmem_rdata;
    wire [1:0]            dmem_rresp;
    wire                  dmem_rlast;
    wire                  dmem_rvalid;
    wire                  dmem_rready = dma_owns_bus ? dma_m_rready : core_m_rready;

    assign dma_m_awready = dma_owns_bus ? dmem_awready : 1'b0;
    assign dma_m_wready  = dma_owns_bus ? dmem_wready  : 1'b0;
    assign dma_m_bresp   = dmem_bresp;
    assign dma_m_bvalid  = dma_owns_bus ? dmem_bvalid  : 1'b0;
    assign dma_m_arready = dma_owns_bus ? dmem_arready : 1'b0;
    assign dma_m_rdata   = dmem_rdata;
    assign dma_m_rresp   = dmem_rresp;
    assign dma_m_rlast   = dmem_rlast;
    assign dma_m_rvalid  = dma_owns_bus ? dmem_rvalid  : 1'b0;

    // =========================================================================
    // AXI4-to-AXI4-Lite Bridge Wires
    // =========================================================================
    wire bridge_awvalid = (!dma_owns_bus) && core_m_awvalid && (core_m_awaddr[31:16] != 16'h0001);
    wire bridge_arvalid = (!dma_owns_bus) && core_m_arvalid && (core_m_araddr[31:16] != 16'h0001);

    wire bridge_awready, bridge_wready, bridge_bvalid, bridge_arready, bridge_rvalid, bridge_rlast;
    wire [1:0] bridge_bresp, bridge_rresp;
    wire [DATA_WIDTH-1:0] bridge_rdata;

    // Multiplex CPU ready/data responses between Data Memory and AXI Bridge
    assign core_m_awready = (core_m_awaddr[31:16] == 16'h0001) ? dmem_awready : bridge_awready;
    assign core_m_wready  = (core_m_awaddr[31:16] == 16'h0001) ? dmem_wready  : bridge_wready;
    assign core_m_bvalid  = (core_m_awaddr[31:16] == 16'h0001) ? dmem_bvalid  : bridge_bvalid;
    assign core_m_bresp   = (core_m_awaddr[31:16] == 16'h0001) ? dmem_bresp   : bridge_bresp;

    assign core_m_arready = (core_m_araddr[31:16] == 16'h0001) ? dmem_arready : bridge_arready;
    assign core_m_rvalid  = (core_m_araddr[31:16] == 16'h0001) ? dmem_rvalid  : bridge_rvalid;
    assign core_m_rdata   = (core_m_araddr[31:16] == 16'h0001) ? dmem_rdata   : bridge_rdata;
    assign core_m_rresp   = (core_m_araddr[31:16] == 16'h0001) ? dmem_rresp   : bridge_rresp;
    assign core_m_rlast   = (core_m_araddr[31:16] == 16'h0001) ? dmem_rlast   : bridge_rlast;

    // Bridge AXI4-Lite Master Channels
    wire [ADDR_WIDTH-1:0] axil_awaddr;
    wire [2:0]            axil_awprot;
    wire                  axil_awvalid;
    wire                  axil_awready;
    wire [DATA_WIDTH-1:0] axil_wdata;
    wire [3:0]            axil_wstrb;
    wire                  axil_wvalid;
    wire                  axil_wready;
    wire [1:0]            axil_bresp;
    wire                  axil_bvalid;
    wire                  axil_bready;
    wire [ADDR_WIDTH-1:0] axil_araddr;
    wire [2:0]            axil_arprot;
    wire                  axil_arvalid;
    wire                  axil_arready;
    wire [DATA_WIDTH-1:0] axil_rdata;
    wire [1:0]            axil_rresp;
    wire                  axil_rvalid;
    wire                  axil_rready;

    // =========================================================================
    // Decoder Downstream Slave Channels
    // =========================================================================
    // UART
    wire [7:0] uart_awaddr, uart_araddr; wire uart_awvalid, uart_awready, uart_wvalid, uart_wready, uart_bvalid, uart_bready;
    wire uart_arvalid, uart_arready, uart_rvalid, uart_rready; wire [31:0] uart_wdata, uart_rdata; wire [3:0] uart_wstrb; wire [1:0] uart_bresp, uart_rresp;

    // Timer
    wire [7:0] tmr_awaddr, tmr_araddr; wire tmr_awvalid, tmr_awready, tmr_wvalid, tmr_wready, tmr_bvalid, tmr_bready;
    wire tmr_arvalid, tmr_arready, tmr_rvalid, tmr_rready; wire [31:0] tmr_wdata, tmr_rdata; wire [3:0] tmr_wstrb; wire [1:0] tmr_bresp, tmr_rresp;

    // GPIO
    wire [7:0] gpio_awaddr, gpio_araddr; wire gpio_awvalid, gpio_awready, gpio_wvalid, gpio_wready, gpio_bvalid, gpio_bready;
    wire gpio_arvalid, gpio_arready, gpio_rvalid, gpio_rready; wire [31:0] gpio_wdata, gpio_rdata; wire [3:0] gpio_wstrb; wire [1:0] gpio_bresp, gpio_rresp;

    // Matrix Multiplier
    wire [7:0] mat_awaddr, mat_araddr; wire mat_awvalid, mat_awready, mat_wvalid, mat_wready, mat_bvalid, mat_bready;
    wire mat_arvalid, mat_arready, mat_rvalid, mat_rready; wire [31:0] mat_wdata, mat_rdata; wire [3:0] mat_wstrb; wire [1:0] mat_bresp, mat_rresp;

    // Activation Unit
    wire [7:0] act_awaddr, act_araddr; wire act_awvalid, act_awready, act_wvalid, act_wready, act_bvalid, act_bready;
    wire act_arvalid, act_arready, act_rvalid, act_rready; wire [31:0] act_wdata, act_rdata; wire [3:0] act_wstrb; wire [1:0] act_bresp, act_rresp;

    // DMA Controller
    wire [7:0] dma_awaddr, dma_araddr; wire dma_awvalid, dma_awready, dma_wvalid, dma_wready, dma_bvalid, dma_bready;
    wire dma_arvalid, dma_arready, dma_rvalid, dma_rready; wire [31:0] dma_wdata, dma_rdata; wire [3:0] dma_wstrb; wire [1:0] dma_bresp, dma_rresp;

    // =========================================================================
    // Dedicated Accelerator Inter-IP Data Connections
    // =========================================================================
    // DMA -> Matrix Multiplier Buffers
    wire        dma_in_wr_en;
    wire [7:0]  dma_in_wr_addr;
    wire [31:0] dma_in_wr_data;
    wire        dma_w_wr_en;
    wire [9:0]  dma_w_wr_addr;
    wire [31:0] dma_w_wr_data;
    wire        dma_bias_wr_en;
    wire [7:0]  dma_bias_wr_addr;
    wire [31:0] dma_bias_wr_data;
    wire        mat_out_rd_en;
    wire [7:0]  mat_out_rd_addr;
    wire [31:0] mat_out_rd_data;

    // Matrix Multiplier -> Activation Unit Streaming
    wire [31:0] stream_act_data;
    wire        stream_act_valid;
    wire        stream_act_ready;

    // Activation Unit -> DMA Readout
    wire        dma_act_rd_en;
    wire [7:0]  dma_act_rd_addr;
    wire [31:0] dma_act_rd_data;

    // Accelerator Status
    wire mat_busy, mat_done;
    wire act_busy, act_done;
    wire dma_busy, dma_done, dma_error;

    assign acc_busy = mat_busy | act_busy | dma_busy;
    assign acc_done = act_done;

    // =========================================================================
    // Module Instantiations
    // =========================================================================

    // 1. RISC-V Processor Core
    riscv_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_core (
        .clk          (clk),
        .rst_n        (rst_n),
        .imem_addr    (core_imem_addr),
        .imem_data    (core_imem_data),
        .m_axi_awaddr (core_m_awaddr),
        .m_axi_awlen  (core_m_awlen),
        .m_axi_awsize (core_m_awsize),
        .m_axi_awburst(core_m_awburst),
        .m_axi_awprot (core_m_awprot),
        .m_axi_awvalid(core_m_awvalid),
        .m_axi_awready(core_m_awready),
        .m_axi_wdata  (core_m_wdata),
        .m_axi_wstrb  (core_m_wstrb),
        .m_axi_wlast  (core_m_wlast),
        .m_axi_wvalid (core_m_wvalid),
        .m_axi_wready (core_m_wready),
        .m_axi_bresp  (core_m_bresp),
        .m_axi_bvalid (core_m_bvalid),
        .m_axi_bready (core_m_bready),
        .m_axi_araddr (core_m_araddr),
        .m_axi_arlen  (core_m_arlen),
        .m_axi_arsize (core_m_arsize),
        .m_axi_arburst(core_m_arburst),
        .m_axi_arprot (core_m_arprot),
        .m_axi_arvalid(core_m_arvalid),
        .m_axi_arready(core_m_arready),
        .m_axi_rdata  (core_m_rdata),
        .m_axi_rresp  (core_m_rresp),
        .m_axi_rlast  (core_m_rlast),
        .m_axi_rvalid (core_m_rvalid),
        .m_axi_rready (core_m_rready),
        .irq          (core_irq)
    );

    // 2. 64 KB Instruction Memory (0x0000_0000)
    instruction_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(16),
        .DEPTH(16384)
    ) u_imem (
        .clk       (clk),
        .rst_n     (rst_n),
        .imem_addr (core_imem_addr[15:0]),
        .imem_data (core_imem_data)
    );

    // 3. 64 KB Shared Data Memory (0x0001_0000)
    data_memory #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DEPTH(16384)
    ) u_dmem (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awaddr (dmem_awaddr),
        .s_axi_awlen  (dmem_awlen),
        .s_axi_awsize (dmem_awsize),
        .s_axi_awburst(dmem_awburst),
        .s_axi_awvalid(dmem_awvalid),
        .s_axi_awready(dmem_awready),
        .s_axi_wdata  (dmem_wdata),
        .s_axi_wstrb  (dmem_wstrb),
        .s_axi_wlast  (dmem_wlast),
        .s_axi_wvalid (dmem_wvalid),
        .s_axi_wready (dmem_wready),
        .s_axi_bresp  (dmem_bresp),
        .s_axi_bvalid (dmem_bvalid),
        .s_axi_bready (dmem_bready),
        .s_axi_araddr (dmem_araddr),
        .s_axi_arlen  (dmem_arlen),
        .s_axi_arsize (dmem_arsize),
        .s_axi_arburst(dmem_arburst),
        .s_axi_arvalid(dmem_arvalid),
        .s_axi_arready(dmem_arready),
        .s_axi_rdata  (dmem_rdata),
        .s_axi_rresp  (dmem_rresp),
        .s_axi_rlast  (dmem_rlast),
        .s_axi_rvalid (dmem_rvalid),
        .s_axi_rready (dmem_rready)
    );

    // 4. AXI4 to AXI4-Lite Protocol Converter Bridge
    axi4_to_axilite_bridge #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ID_WIDTH(4)
    ) u_axi_bridge (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axi_awid     (4'd0),
        .s_axi_awaddr   (core_m_awaddr),
        .s_axi_awlen    (core_m_awlen),
        .s_axi_awsize   (core_m_awsize),
        .s_axi_awburst  (core_m_awburst),
        .s_axi_awprot   (core_m_awprot),
        .s_axi_awvalid  (bridge_awvalid),
        .s_axi_awready  (bridge_awready),
        .s_axi_wdata    (core_m_wdata),
        .s_axi_wstrb    (core_m_wstrb),
        .s_axi_wlast    (core_m_wlast),
        .s_axi_wvalid   (core_m_wvalid),
        .s_axi_wready   (bridge_wready),
        .s_axi_bid      (),
        .s_axi_bresp    (bridge_bresp),
        .s_axi_bvalid   (bridge_bvalid),
        .s_axi_bready   (core_m_bready),
        .s_axi_arid     (4'd0),
        .s_axi_araddr   (core_m_araddr),
        .s_axi_arlen    (core_m_arlen),
        .s_axi_arsize   (core_m_arsize),
        .s_axi_arburst  (core_m_arburst),
        .s_axi_arprot   (core_m_arprot),
        .s_axi_arvalid  (bridge_arvalid),
        .s_axi_arready  (bridge_arready),
        .s_axi_rid      (),
        .s_axi_rdata    (bridge_rdata),
        .s_axi_rresp    (bridge_rresp),
        .s_axi_rlast    (bridge_rlast),
        .s_axi_rvalid   (bridge_rvalid),
        .s_axi_rready   (core_m_rready),
        .m_axil_awaddr  (axil_awaddr),
        .m_axil_awprot  (axil_awprot),
        .m_axil_awvalid (axil_awvalid),
        .m_axil_awready (axil_awready),
        .m_axil_wdata   (axil_wdata),
        .m_axil_wstrb   (axil_wstrb),
        .m_axil_wvalid  (axil_wvalid),
        .m_axil_wready  (axil_wready),
        .m_axil_bresp   (axil_bresp),
        .m_axil_bvalid  (axil_bvalid),
        .m_axil_bready  (axil_bready),
        .m_axil_araddr  (axil_araddr),
        .m_axil_arprot  (axil_arprot),
        .m_axil_arvalid (axil_arvalid),
        .m_axil_arready (axil_arready),
        .m_axil_rdata   (axil_rdata),
        .m_axil_rresp   (axil_rresp),
        .m_axil_rvalid  (axil_rvalid),
        .m_axil_rready  (axil_rready)
    );

    // 5. System Address Decoder Crossbar (Peripheral Interconnect)
    address_decoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_addr_decoder (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_axil_awaddr (axil_awaddr),
        .s_axil_awprot (axil_awprot),
        .s_axil_awvalid(axil_awvalid),
        .s_axil_awready(axil_awready),
        .s_axil_wdata  (axil_wdata),
        .s_axil_wstrb  (axil_wstrb),
        .s_axil_wvalid (axil_wvalid),
        .s_axil_wready (axil_wready),
        .s_axil_bresp  (axil_bresp),
        .s_axil_bvalid (axil_bvalid),
        .s_axil_bready (axil_bready),
        .s_axil_araddr (axil_araddr),
        .s_axil_arprot (axil_arprot),
        .s_axil_arvalid(axil_arvalid),
        .s_axil_arready(axil_arready),
        .s_axil_rdata  (axil_rdata),
        .s_axil_rresp  (axil_rresp),
        .s_axil_rvalid (axil_rvalid),
        .s_axil_rready (axil_rready),
        .m0_awaddr     (uart_awaddr), .m0_awvalid(uart_awvalid), .m0_awready(uart_awready),
        .m0_wdata      (uart_wdata),  .m0_wstrb(uart_wstrb),     .m0_wvalid(uart_wvalid),   .m0_wready(uart_wready),
        .m0_bresp      (uart_bresp),  .m0_bvalid(uart_bvalid),   .m0_bready(uart_bready),
        .m0_araddr     (uart_araddr), .m0_arvalid(uart_arvalid), .m0_arready(uart_arready),
        .m0_rdata      (uart_rdata),  .m0_rresp(uart_rresp),     .m0_rvalid(uart_rvalid),   .m0_rready(uart_rready),
        .m1_awaddr     (tmr_awaddr),  .m1_awvalid(tmr_awvalid),  .m1_awready(tmr_awready),
        .m1_wdata      (tmr_wdata),   .m1_wstrb(tmr_wstrb),      .m1_wvalid(tmr_wvalid),    .m1_wready(tmr_wready),
        .m1_bresp      (tmr_bresp),   .m1_bvalid(tmr_bvalid),    .m1_bready(tmr_bready),
        .m1_araddr     (tmr_araddr),  .m1_arvalid(tmr_arvalid),  .m1_arready(tmr_arready),
        .m1_rdata      (tmr_rdata),   .m1_rresp(tmr_rresp),      .m1_rvalid(tmr_rvalid),    .m1_rready(tmr_rready),
        .m2_awaddr     (gpio_awaddr), .m2_awvalid(gpio_awvalid), .m2_awready(gpio_awready),
        .m2_wdata      (gpio_wdata),  .m2_wstrb(gpio_wstrb),     .m2_wvalid(gpio_wvalid),   .m2_wready(gpio_wready),
        .m2_bresp      (gpio_bresp),  .m2_bvalid(gpio_bvalid),   .m2_bready(gpio_bready),
        .m2_araddr     (gpio_araddr), .m2_arvalid(gpio_arvalid), .m2_arready(gpio_arready),
        .m2_rdata      (gpio_rdata),  .m2_rresp(gpio_rresp),     .m2_rvalid(gpio_rvalid),   .m2_rready(gpio_rready),
        .m3_awaddr     (mat_awaddr),  .m3_awvalid(mat_awvalid),  .m3_awready(mat_awready),
        .m3_wdata      (mat_wdata),   .m3_wstrb(mat_wstrb),      .m3_wvalid(mat_wvalid),    .m3_wready(mat_wready),
        .m3_bresp      (mat_bresp),   .m3_bvalid(mat_bvalid),    .m3_bready(mat_bready),
        .m3_araddr     (mat_araddr),  .m3_arvalid(mat_arvalid),  .m3_arready(mat_arready),
        .m3_rdata      (mat_rdata),   .m3_rresp(mat_rresp),      .m3_rvalid(mat_rvalid),    .m3_rready(mat_rready),
        .m4_awaddr     (act_awaddr),  .m4_awvalid(act_awvalid),  .m4_awready(act_awready),
        .m4_wdata      (act_wdata),   .m4_wstrb(act_wstrb),      .m4_wvalid(act_wvalid),    .m4_wready(act_wready),
        .m4_bresp      (act_bresp),   .m4_bvalid(act_bvalid),    .m4_bready(act_bready),
        .m4_araddr     (act_araddr),  .m4_arvalid(act_arvalid),  .m4_arready(act_arready),
        .m4_rdata      (act_rdata),   .m4_rresp(act_rresp),      .m4_rvalid(act_rvalid),    .m4_rready(act_rready),
        .m5_awaddr     (dma_awaddr),  .m5_awvalid(dma_awvalid),  .m5_awready(dma_awready),
        .m5_wdata      (dma_wdata),   .m5_wstrb(dma_wstrb),      .m5_wvalid(dma_wvalid),    .m5_wready(dma_wready),
        .m5_bresp      (dma_bresp),   .m5_bvalid(dma_bvalid),    .m5_bready(dma_bready),
        .m5_araddr     (dma_araddr),  .m5_arvalid(dma_arvalid),  .m5_arready(dma_arready),
        .m5_rdata      (dma_rdata),   .m5_rresp(dma_rresp),      .m5_rvalid(dma_rvalid),    .m5_rready(dma_rready)
    );

    // 6. Custom IP 1: Matrix Multiplier (0x0003_0000)
    matrix_multiplier_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .FRAC_BITS(16)
    ) u_matrix_multiplier (
        .clk              (clk),
        .rst_n            (rst_n),
        .s_axi_awaddr     (mat_awaddr),
        .s_axi_awprot     (3'b000),
        .s_axi_awvalid    (mat_awvalid),
        .s_axi_awready    (mat_awready),
        .s_axi_wdata      (mat_wdata),
        .s_axi_wstrb      (mat_wstrb),
        .s_axi_wvalid     (mat_wvalid),
        .s_axi_wready     (mat_wready),
        .s_axi_bresp      (mat_bresp),
        .s_axi_bvalid     (mat_bvalid),
        .s_axi_bready     (mat_bready),
        .s_axi_araddr     (mat_araddr),
        .s_axi_arprot     (3'b000),
        .s_axi_arvalid    (mat_arvalid),
        .s_axi_arready    (mat_arready),
        .s_axi_rdata      (mat_rdata),
        .s_axi_rresp      (mat_rresp),
        .s_axi_rvalid     (mat_rvalid),
        .s_axi_rready     (mat_rready),
        .dma_in_wr_en     (dma_in_wr_en),
        .dma_in_wr_addr   (dma_in_wr_addr),
        .dma_in_wr_data   (dma_in_wr_data),
        .dma_w_wr_en      (dma_w_wr_en),
        .dma_w_wr_addr    (dma_w_wr_addr),
        .dma_w_wr_data    (dma_w_wr_data),
        .dma_bias_wr_en   (dma_bias_wr_en),
        .dma_bias_wr_addr (dma_bias_wr_addr),
        .dma_bias_wr_data (dma_bias_wr_data),
        .dma_out_rd_en    (mat_out_rd_en),
        .dma_out_rd_addr  (mat_out_rd_addr),
        .dma_out_rd_data  (mat_out_rd_data),
        .stream_act_data  (stream_act_data),
        .stream_act_valid (stream_act_valid),
        .stream_act_ready (stream_act_ready),
        .busy             (mat_busy),
        .done             (mat_done),
        .irq              (mat_irq)
    );

    // 7. Custom IP 2: Activation Unit (0x0003_0100)
    activation_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .BUF_ADDR_W(8)
    ) u_activation_unit (
        .clk             (clk),
        .rst_n           (rst_n),
        .s_axi_awaddr    (act_awaddr),
        .s_axi_awprot    (3'b000),
        .s_axi_awvalid   (act_awvalid),
        .s_axi_awready   (act_awready),
        .s_axi_wdata     (act_wdata),
        .s_axi_wstrb     (act_wstrb),
        .s_axi_wvalid    (act_wvalid),
        .s_axi_wready    (act_wready),
        .s_axi_bresp     (act_bresp),
        .s_axi_bvalid    (act_bvalid),
        .s_axi_bready    (act_bready),
        .s_axi_araddr    (act_araddr),
        .s_axi_arprot    (3'b000),
        .s_axi_arvalid   (act_arvalid),
        .s_axi_arready   (act_arready),
        .s_axi_rdata     (act_rdata),
        .s_axi_rresp     (act_rresp),
        .s_axi_rvalid    (act_rvalid),
        .s_axi_rready    (act_rready),
        .stream_in_data  (stream_act_data),
        .stream_in_valid (stream_act_valid),
        .stream_in_ready (stream_act_ready),
        .dma_out_rd_en   (dma_act_rd_en),
        .dma_out_rd_addr (dma_act_rd_addr),
        .dma_out_rd_data (dma_act_rd_data),
        .busy            (act_busy),
        .done            (act_done),
        .irq             (act_irq)
    );

    // 8. Custom IP 3: DMA Controller (0x0003_0200)
    dma_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_dma_controller (
        .clk              (clk),
        .rst_n            (rst_n),
        .s_axi_awaddr     (dma_awaddr),
        .s_axi_awprot     (3'b000),
        .s_axi_awvalid    (dma_awvalid),
        .s_axi_awready    (dma_awready),
        .s_axi_wdata      (dma_wdata),
        .s_axi_wstrb      (dma_wstrb),
        .s_axi_wvalid     (dma_wvalid),
        .s_axi_wready     (dma_wready),
        .s_axi_bresp      (dma_bresp),
        .s_axi_bvalid     (dma_bvalid),
        .s_axi_bready     (dma_bready),
        .s_axi_araddr     (dma_araddr),
        .s_axi_arprot     (3'b000),
        .s_axi_arvalid    (dma_arvalid),
        .s_axi_arready    (dma_arready),
        .s_axi_rdata      (dma_rdata),
        .s_axi_rresp      (dma_rresp),
        .s_axi_rvalid     (dma_rvalid),
        .s_axi_rready     (dma_rready),
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
        .irq              (dma_irq)
    );

    // 9. UART Peripheral (0x0002_0000)
    uart #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(8)
    ) u_uart (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awaddr (uart_awaddr),
        .s_axi_awvalid(uart_awvalid),
        .s_axi_awready(uart_awready),
        .s_axi_wdata  (uart_wdata),
        .s_axi_wstrb  (uart_wstrb),
        .s_axi_wvalid (uart_wvalid),
        .s_axi_wready (uart_wready),
        .s_axi_bresp  (uart_bresp),
        .s_axi_bvalid (uart_bvalid),
        .s_axi_bready (uart_bready),
        .s_axi_araddr (uart_araddr),
        .s_axi_arvalid(uart_arvalid),
        .s_axi_arready(uart_arready),
        .s_axi_rdata  (uart_rdata),
        .s_axi_rresp  (uart_rresp),
        .s_axi_rvalid (uart_rvalid),
        .s_axi_rready (uart_rready),
        .uart_tx      (uart_tx),
        .uart_rx      (uart_rx),
        .tx_done_irq  (uart_irq)
    );

    // 10. Timer Peripheral (0x0002_0100)
    timer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(8)
    ) u_timer (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awaddr (tmr_awaddr),
        .s_axi_awvalid(tmr_awvalid),
        .s_axi_awready(tmr_awready),
        .s_axi_wdata  (tmr_wdata),
        .s_axi_wstrb  (tmr_wstrb),
        .s_axi_wvalid (tmr_wvalid),
        .s_axi_wready (tmr_wready),
        .s_axi_bresp  (tmr_bresp),
        .s_axi_bvalid (tmr_bvalid),
        .s_axi_bready (tmr_bready),
        .s_axi_araddr (tmr_araddr),
        .s_axi_arvalid(tmr_arvalid),
        .s_axi_arready(tmr_arready),
        .s_axi_rdata  (tmr_rdata),
        .s_axi_rresp  (tmr_rresp),
        .s_axi_rvalid (tmr_rvalid),
        .s_axi_rready (tmr_rready),
        .timer_tick   (),
        .timer_irq    (timer_irq)
    );

    // 11. GPIO Peripheral (0x0002_0200)
    gpio #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(8),
        .GPIO_WIDTH(8)
    ) u_gpio (
        .clk          (clk),
        .rst_n        (rst_n),
        .s_axi_awaddr (gpio_awaddr),
        .s_axi_awvalid(gpio_awvalid),
        .s_axi_awready(gpio_awready),
        .s_axi_wdata  (gpio_wdata),
        .s_axi_wstrb  (gpio_wstrb),
        .s_axi_wvalid (gpio_wvalid),
        .s_axi_wready (gpio_wready),
        .s_axi_bresp  (gpio_bresp),
        .s_axi_bvalid (gpio_bvalid),
        .s_axi_bready (gpio_bready),
        .s_axi_araddr (gpio_araddr),
        .s_axi_arvalid(gpio_arvalid),
        .s_axi_arready(gpio_arready),
        .s_axi_rdata  (gpio_rdata),
        .s_axi_rresp  (gpio_rresp),
        .s_axi_rvalid (gpio_rvalid),
        .s_axi_rready (gpio_rready),
        .gpio_out     (gpio_out),
        .gpio_in      (gpio_in)
    );

endmodule
