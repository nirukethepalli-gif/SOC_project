// ============================================================================
// Module Name: gpio
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: General Purpose I/O with AXI4-Lite Slave Interface (0x0002_0200).
//              Provides direction, input, and output registers.
// ============================================================================

`timescale 1ns / 1ps

module gpio #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 8,
    parameter GPIO_WIDTH = 8
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

    // External GPIO Pins
    output reg  [GPIO_WIDTH-1:0]  gpio_out,
    input  wire [GPIO_WIDTH-1:0]  gpio_in
);

    localparam [ADDR_WIDTH-1:0]
        REG_DIR = 8'h00,
        REG_IN  = 8'h04,
        REG_OUT = 8'h08;

    reg [GPIO_WIDTH-1:0] gpio_dir;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_dir      <= {GPIO_WIDTH{1'b0}};
            gpio_out      <= {GPIO_WIDTH{1'b0}};
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
        end else begin
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_awready) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00;

                case (s_axi_awaddr)
                    REG_DIR: gpio_dir <= s_axi_wdata[GPIO_WIDTH-1:0];
                    REG_OUT: gpio_out <= s_axi_wdata[GPIO_WIDTH-1:0];
                    default: ;
                endcase
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

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
                    REG_DIR: s_axi_rdata <= {24'd0, gpio_dir};
                    REG_IN:  s_axi_rdata <= {24'd0, gpio_in};
                    REG_OUT: s_axi_rdata <= {24'd0, gpio_out};
                    default: s_axi_rdata <= 32'd0;
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
