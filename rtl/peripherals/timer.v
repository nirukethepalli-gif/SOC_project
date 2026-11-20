// ============================================================================
// Module Name: timer
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: System Timer with AXI4-Lite Slave Interface (0x0002_0100).
//              Provides free-running counter, compare register, and interrupt.
// ============================================================================

`timescale 1ns / 1ps

module timer #(
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

    output reg                    timer_tick,
    output reg                    timer_irq
);

    localparam [ADDR_WIDTH-1:0]
        REG_CTRL    = 8'h00,
        REG_COUNT   = 8'h04,
        REG_COMPARE = 8'h08;

    reg [31:0] counter;
    reg [31:0] compare;
    reg        timer_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter       <= 32'd0;
            compare       <= 32'hFFFF_FFFF;
            timer_en      <= 1'b1;
            timer_tick    <= 1'b0;
            timer_irq     <= 1'b0;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
        end else begin
            // Free running counter
            if (timer_en) begin
                if (counter >= compare) begin
                    counter    <= 32'd0;
                    timer_tick <= 1'b1;
                    timer_irq  <= 1'b1;
                end else begin
                    counter    <= counter + 1'b1;
                    timer_tick <= 1'b0;
                end
            end

            // AXI Write
            if (s_axi_awvalid && s_axi_wvalid && !s_axi_awready) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                s_axi_bvalid  <= 1'b1;
                s_axi_bresp   <= 2'b00;

                case (s_axi_awaddr)
                    REG_CTRL:    timer_en <= s_axi_wdata[0];
                    REG_COUNT:   counter  <= s_axi_wdata;
                    REG_COMPARE: compare  <= s_axi_wdata;
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

    // AXI Read
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
                    REG_CTRL:    s_axi_rdata <= {31'd0, timer_en};
                    REG_COUNT:   s_axi_rdata <= counter;
                    REG_COMPARE: s_axi_rdata <= compare;
                    default:     s_axi_rdata <= 32'd0;
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
