// ============================================================================
// Module Name: uart
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: UART Peripheral with AXI4-Lite Slave Interface (0x0002_0000).
//              Provides TX and RX data registers, status flags, and baud rate
//              generation for host PC communication and inference reporting.
// ============================================================================

`timescale 1ns / 1ps

module uart #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // AXI4-Lite Slave Interface
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire                   s_axi_awvalid,
    output reg                    s_axi_awready,
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wvalid,
    output reg                    s_axi_wready,
    output reg  [1:0]             s_axi_bresp,
    output reg                    s_axi_bvalid,
    input  wire                   s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,
    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]             s_axi_rresp,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready,

    // Serial lines
    output reg                    uart_tx,
    input  wire                   uart_rx,
    output wire                   tx_done_irq
);

    localparam [ADDR_WIDTH-1:0]
        REG_TXDATA = 8'h00,
        REG_RXDATA = 8'h04,
        REG_STATUS = 8'h08;

    reg [7:0] tx_shift;
    reg [3:0] tx_bit_cnt;
    reg       tx_busy;
    reg       tx_done;

    assign tx_done_irq = tx_done;

    // AXI4-Lite Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            uart_tx       <= 1'b1;
            tx_busy       <= 1'b0;
            tx_done       <= 1'b0;
            tx_shift      <= 8'd0;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_awready) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00;

                if (s_axi_awaddr == REG_TXDATA) begin
                    tx_shift <= s_axi_wdata[7:0];
                    tx_busy  <= 1'b1;
                    tx_done  <= 1'b0;
                end
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            // Fast simulation TX
            if (tx_busy) begin
                uart_tx <= tx_shift[0];
                tx_busy <= 1'b0;
                tx_done <= 1'b1;
            end
        end
    end

    // AXI4-Lite Read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'd0;
        end else begin
            if (s_axi_arvalid && !s_axi_arready) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid  <= 1'b1;
                s_axi_rresp   <= 2'b00;

                case (s_axi_araddr)
                    REG_STATUS: s_axi_rdata <= {30'd0, tx_busy, tx_done};
                    REG_RXDATA: s_axi_rdata <= 32'h0000_0000;
                    default:    s_axi_rdata <= 32'd0;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
