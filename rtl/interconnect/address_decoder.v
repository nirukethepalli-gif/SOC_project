// ============================================================================
// Module Name: address_decoder
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Central AXI4-Lite Address Decoder and Interconnect Crossbar.
//              Routes AXI4-Lite master requests to the addressed peripheral/IP
//              based on the unified 32-bit system memory map:
//                - UART:              0x0002_0000 - 0x0002_00FF
//                - Timer:             0x0002_0100 - 0x0002_01FF
//                - GPIO:              0x0002_0200 - 0x0002_02FF
//                - Matrix Multiplier: 0x0003_0000 - 0x0003_00FF
//                - Activation Unit:   0x0003_0100 - 0x0003_01FF
//                - DMA Controller:    0x0003_0200 - 0x0003_02FF
// ============================================================================

`timescale 1ns / 1ps

module address_decoder #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Upstream AXI4-Lite Master Interface (from AXI Bridge)
    input  wire [ADDR_WIDTH-1:0]  s_axil_awaddr,
    input  wire [2:0]             s_axil_awprot,
    input  wire                   s_axil_awvalid,
    output reg                    s_axil_awready,

    input  wire [DATA_WIDTH-1:0]  s_axil_wdata,
    input  wire [3:0]             s_axil_wstrb,
    input  wire                   s_axil_wvalid,
    output reg                    s_axil_wready,

    output reg  [1:0]             s_axil_bresp,
    output reg                    s_axil_bvalid,
    input  wire                   s_axil_bready,

    input  wire [ADDR_WIDTH-1:0]  s_axil_araddr,
    input  wire [2:0]             s_axil_arprot,
    input  wire                   s_axil_arvalid,
    output reg                    s_axil_arready,

    output reg  [DATA_WIDTH-1:0]  s_axil_rdata,
    output reg  [1:0]             s_axil_rresp,
    output reg                    s_axil_rvalid,
    input  wire                   s_axil_rready,

    // Downstream Slave 0: UART (0x0002_0000)
    output wire [7:0]             m0_awaddr,
    output wire                   m0_awvalid,
    input  wire                   m0_awready,
    output wire [31:0]            m0_wdata,
    output wire [3:0]             m0_wstrb,
    output wire                   m0_wvalid,
    input  wire                   m0_wready,
    input  wire [1:0]             m0_bresp,
    input  wire                   m0_bvalid,
    output wire                   m0_bready,
    output wire [7:0]             m0_araddr,
    output wire                   m0_arvalid,
    input  wire                   m0_arready,
    input  wire [31:0]            m0_rdata,
    input  wire [1:0]             m0_rresp,
    input  wire                   m0_rvalid,
    output wire                   m0_rready,

    // Downstream Slave 1: Timer (0x0002_0100)
    output wire [7:0]             m1_awaddr,
    output wire                   m1_awvalid,
    input  wire                   m1_awready,
    output wire [31:0]            m1_wdata,
    output wire [3:0]             m1_wstrb,
    output wire                   m1_wvalid,
    input  wire                   m1_wready,
    input  wire [1:0]             m1_bresp,
    input  wire                   m1_bvalid,
    output wire                   m1_bready,
    output wire [7:0]             m1_araddr,
    output wire                   m1_arvalid,
    input  wire                   m1_arready,
    input  wire [31:0]            m1_rdata,
    input  wire [1:0]             m1_rresp,
    input  wire                   m1_rvalid,
    output wire                   m1_rready,

    // Downstream Slave 2: GPIO (0x0002_0200)
    output wire [7:0]             m2_awaddr,
    output wire                   m2_awvalid,
    input  wire                   m2_awready,
    output wire [31:0]            m2_wdata,
    output wire [3:0]             m2_wstrb,
    output wire                   m2_wvalid,
    input  wire                   m2_wready,
    input  wire [1:0]             m2_bresp,
    input  wire                   m2_bvalid,
    output wire                   m2_bready,
    output wire [7:0]             m2_araddr,
    output wire                   m2_arvalid,
    input  wire                   m2_arready,
    input  wire [31:0]            m2_rdata,
    input  wire [1:0]             m2_rresp,
    input  wire                   m2_rvalid,
    output wire                   m2_rready,

    // Downstream Slave 3: Matrix Multiplier (0x0003_0000)
    output wire [7:0]             m3_awaddr,
    output wire                   m3_awvalid,
    input  wire                   m3_awready,
    output wire [31:0]            m3_wdata,
    output wire [3:0]             m3_wstrb,
    output wire                   m3_wvalid,
    input  wire                   m3_wready,
    input  wire [1:0]             m3_bresp,
    input  wire                   m3_bvalid,
    output wire                   m3_bready,
    output wire [7:0]             m3_araddr,
    output wire                   m3_arvalid,
    input  wire                   m3_arready,
    input  wire [31:0]            m3_rdata,
    input  wire [1:0]             m3_rresp,
    input  wire                   m3_rvalid,
    output wire                   m3_rready,

    // Downstream Slave 4: Activation Unit (0x0003_0100)
    output wire [7:0]             m4_awaddr,
    output wire                   m4_awvalid,
    input  wire                   m4_awready,
    output wire [31:0]            m4_wdata,
    output wire [3:0]             m4_wstrb,
    output wire                   m4_wvalid,
    input  wire                   m4_wready,
    input  wire [1:0]             m4_bresp,
    input  wire                   m4_bvalid,
    output wire                   m4_bready,
    output wire [7:0]             m4_araddr,
    output wire                   m4_arvalid,
    input  wire                   m4_arready,
    input  wire [31:0]            m4_rdata,
    input  wire [1:0]             m4_rresp,
    input  wire                   m4_rvalid,
    output wire                   m4_rready,

    // Downstream Slave 5: DMA Controller (0x0003_0200)
    output wire [7:0]             m5_awaddr,
    output wire                   m5_awvalid,
    input  wire                   m5_awready,
    output wire [31:0]            m5_wdata,
    output wire [3:0]             m5_wstrb,
    output wire                   m5_wvalid,
    input  wire                   m5_wready,
    input  wire [1:0]             m5_bresp,
    input  wire                   m5_bvalid,
    output wire                   m5_bready,
    output wire [7:0]             m5_araddr,
    output wire                   m5_arvalid,
    input  wire                   m5_arready,
    input  wire [31:0]            m5_rdata,
    input  wire [1:0]             m5_rresp,
    input  wire                   m5_rvalid,
    output wire                   m5_rready
);

    // Decode write address slave select
    function [2:0] get_slave_sel(input [31:0] addr);
        begin
            if      (addr[31:8] == 24'h0002_00) get_slave_sel = 3'd0; // UART
            else if (addr[31:8] == 24'h0002_01) get_slave_sel = 3'd1; // Timer
            else if (addr[31:8] == 24'h0002_02) get_slave_sel = 3'd2; // GPIO
            else if (addr[31:8] == 24'h0003_00) get_slave_sel = 3'd3; // Matrix Mult
            else if (addr[31:8] == 24'h0003_01) get_slave_sel = 3'd4; // Activation
            else if (addr[31:8] == 24'h0003_02) get_slave_sel = 3'd5; // DMA
            else                                get_slave_sel = 3'd7; // Decode Error
        end
    endfunction

    wire [2:0] wr_sel = get_slave_sel(s_axil_awaddr);
    wire [2:0] rd_sel = get_slave_sel(s_axil_araddr);

    // Route write addresses and data to slaves
    assign m0_awaddr  = s_axil_awaddr[7:0]; assign m0_wdata = s_axil_wdata; assign m0_wstrb = s_axil_wstrb;
    assign m1_awaddr  = s_axil_awaddr[7:0]; assign m1_wdata = s_axil_wdata; assign m1_wstrb = s_axil_wstrb;
    assign m2_awaddr  = s_axil_awaddr[7:0]; assign m2_wdata = s_axil_wdata; assign m2_wstrb = s_axil_wstrb;
    assign m3_awaddr  = s_axil_awaddr[7:0]; assign m3_wdata = s_axil_wdata; assign m3_wstrb = s_axil_wstrb;
    assign m4_awaddr  = s_axil_awaddr[7:0]; assign m4_wdata = s_axil_wdata; assign m4_wstrb = s_axil_wstrb;
    assign m5_awaddr  = s_axil_awaddr[7:0]; assign m5_wdata = s_axil_wdata; assign m5_wstrb = s_axil_wstrb;

    assign m0_awvalid = (wr_sel == 3'd0) ? s_axil_awvalid : 1'b0;
    assign m0_wvalid  = (wr_sel == 3'd0) ? s_axil_wvalid  : 1'b0;
    assign m0_bready  = (wr_sel == 3'd0) ? s_axil_bready  : 1'b0;

    assign m1_awvalid = (wr_sel == 3'd1) ? s_axil_awvalid : 1'b0;
    assign m1_wvalid  = (wr_sel == 3'd1) ? s_axil_wvalid  : 1'b0;
    assign m1_bready  = (wr_sel == 3'd1) ? s_axil_bready  : 1'b0;

    assign m2_awvalid = (wr_sel == 3'd2) ? s_axil_awvalid : 1'b0;
    assign m2_wvalid  = (wr_sel == 3'd2) ? s_axil_wvalid  : 1'b0;
    assign m2_bready  = (wr_sel == 3'd2) ? s_axil_bready  : 1'b0;

    assign m3_awvalid = (wr_sel == 3'd3) ? s_axil_awvalid : 1'b0;
    assign m3_wvalid  = (wr_sel == 3'd3) ? s_axil_wvalid  : 1'b0;
    assign m3_bready  = (wr_sel == 3'd3) ? s_axil_bready  : 1'b0;

    assign m4_awvalid = (wr_sel == 3'd4) ? s_axil_awvalid : 1'b0;
    assign m4_wvalid  = (wr_sel == 3'd4) ? s_axil_wvalid  : 1'b0;
    assign m4_bready  = (wr_sel == 3'd4) ? s_axil_bready  : 1'b0;

    assign m5_awvalid = (wr_sel == 3'd5) ? s_axil_awvalid : 1'b0;
    assign m5_wvalid  = (wr_sel == 3'd5) ? s_axil_wvalid  : 1'b0;
    assign m5_bready  = (wr_sel == 3'd5) ? s_axil_bready  : 1'b0;

    // Upstream Write Multiplexing
    always @(*) begin
        case (wr_sel)
            3'd0: begin s_axil_awready = m0_awready; s_axil_wready = m0_wready; s_axil_bvalid = m0_bvalid; s_axil_bresp = m0_bresp; end
            3'd1: begin s_axil_awready = m1_awready; s_axil_wready = m1_wready; s_axil_bvalid = m1_bvalid; s_axil_bresp = m1_bresp; end
            3'd2: begin s_axil_awready = m2_awready; s_axil_wready = m2_wready; s_axil_bvalid = m2_bvalid; s_axil_bresp = m2_bresp; end
            3'd3: begin s_axil_awready = m3_awready; s_axil_wready = m3_wready; s_axil_bvalid = m3_bvalid; s_axil_bresp = m3_bresp; end
            3'd4: begin s_axil_awready = m4_awready; s_axil_wready = m4_wready; s_axil_bvalid = m4_bvalid; s_axil_bresp = m4_bresp; end
            3'd5: begin s_axil_awready = m5_awready; s_axil_wready = m5_wready; s_axil_bvalid = m5_bvalid; s_axil_bresp = m5_bresp; end
            default: begin s_axil_awready = 1'b1; s_axil_wready = 1'b1; s_axil_bvalid = 1'b1; s_axil_bresp = 2'b10; end // DECERR
        endcase
    end

    // Route read addresses to slaves
    assign m0_araddr  = s_axil_araddr[7:0]; assign m0_arvalid = (rd_sel == 3'd0) ? s_axil_arvalid : 1'b0; assign m0_rready = (rd_sel == 3'd0) ? s_axil_rready : 1'b0;
    assign m1_araddr  = s_axil_araddr[7:0]; assign m1_arvalid = (rd_sel == 3'd1) ? s_axil_arvalid : 1'b0; assign m1_rready = (rd_sel == 3'd1) ? s_axil_rready : 1'b0;
    assign m2_araddr  = s_axil_araddr[7:0]; assign m2_arvalid = (rd_sel == 3'd2) ? s_axil_arvalid : 1'b0; assign m2_rready = (rd_sel == 3'd2) ? s_axil_rready : 1'b0;
    assign m3_araddr  = s_axil_araddr[7:0]; assign m3_arvalid = (rd_sel == 3'd3) ? s_axil_arvalid : 1'b0; assign m3_rready = (rd_sel == 3'd3) ? s_axil_rready : 1'b0;
    assign m4_araddr  = s_axil_araddr[7:0]; assign m4_arvalid = (rd_sel == 3'd4) ? s_axil_arvalid : 1'b0; assign m4_rready = (rd_sel == 3'd4) ? s_axil_rready : 1'b0;
    assign m5_araddr  = s_axil_araddr[7:0]; assign m5_arvalid = (rd_sel == 3'd5) ? s_axil_arvalid : 1'b0; assign m5_rready = (rd_sel == 3'd5) ? s_axil_rready : 1'b0;

    // Upstream Read Multiplexing
    always @(*) begin
        case (rd_sel)
            3'd0: begin s_axil_arready = m0_arready; s_axil_rvalid = m0_rvalid; s_axil_rdata = m0_rdata; s_axil_rresp = m0_rresp; end
            3'd1: begin s_axil_arready = m1_arready; s_axil_rvalid = m1_rvalid; s_axil_rdata = m1_rdata; s_axil_rresp = m1_rresp; end
            3'd2: begin s_axil_arready = m2_arready; s_axil_rvalid = m2_rvalid; s_axil_rdata = m2_rdata; s_axil_rresp = m2_rresp; end
            3'd3: begin s_axil_arready = m3_arready; s_axil_rvalid = m3_rvalid; s_axil_rdata = m3_rdata; s_axil_rresp = m3_rresp; end
            3'd4: begin s_axil_arready = m4_arready; s_axil_rvalid = m4_rvalid; s_axil_rdata = m4_rdata; s_axil_rresp = m4_rresp; end
            3'd5: begin s_axil_arready = m5_arready; s_axil_rvalid = m5_rvalid; s_axil_rdata = m5_rdata; s_axil_rresp = m5_rresp; end
            default: begin s_axil_arready = 1'b1; s_axil_rvalid = 1'b1; s_axil_rdata = 32'hDEAD_BEEF; s_axil_rresp = 2'b10; end // DECERR
        endcase
    end

endmodule
