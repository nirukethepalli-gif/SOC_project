// ============================================================================
// Module Name: data_memory
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: 64 KB Shared Data Memory with AXI4 Slave Interface.
//              Address Range: 0x0001_0000 - 0x0001_FFFF.
//              Holds input vectors, weight matrices, bias values, and output
//              activations. Accessible by both the RISC-V CPU and DMA Master.
// ============================================================================

`timescale 1ns / 1ps

module data_memory #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DEPTH      = 16384 // 64 KB (16384 x 32-bit words)
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // AXI4 Write Address Channel
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire                   s_axi_awvalid,
    output reg                    s_axi_awready,

    // AXI4 Write Data Channel
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output reg                    s_axi_wready,

    // AXI4 Write Response Channel
    output reg  [1:0]             s_axi_bresp,
    output reg                    s_axi_bvalid,
    input  wire                   s_axi_bready,

    // AXI4 Read Address Channel
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,

    // AXI4 Read Data Channel
    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]             s_axi_rresp,
    output reg                    s_axi_rlast,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Local word address (mapped within 64 KB segment)
    reg [13:0] wr_word_addr;
    reg [7:0]  wr_burst_rem;

    // Write Channel Logic
    localparam [1:0] W_IDLE = 2'b00, W_DATA = 2'b01, W_RESP = 2'b10;
    reg [1:0] w_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state       <= W_IDLE;
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            wr_word_addr  <= 14'd0;
            wr_burst_rem  <= 8'd0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    s_axi_awready <= 1'b1;
                    if (s_axi_awvalid && s_axi_awready) begin
                        s_axi_awready <= 1'b0;
                        wr_word_addr  <= s_axi_awaddr[15:2];
                        wr_burst_rem  <= s_axi_awlen;
                        s_axi_wready  <= 1'b1;
                        w_state       <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        // Byte-enable write
                        if (s_axi_wstrb[0]) mem[wr_word_addr][7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) mem[wr_word_addr][15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) mem[wr_word_addr][23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) mem[wr_word_addr][31:24] <= s_axi_wdata[31:24];

                        wr_word_addr <= wr_word_addr + 1'b1;

                        if (s_axi_wlast || wr_burst_rem == 8'd0) begin
                            s_axi_wready <= 1'b0;
                            s_axi_bvalid <= 1'b1;
                            s_axi_bresp  <= 2'b00; // OKAY
                            w_state      <= W_RESP;
                        end else begin
                            wr_burst_rem <= wr_burst_rem - 1'b1;
                        end
                    end
                end

                W_RESP: begin
                    if (s_axi_bready && s_axi_bvalid) begin
                        s_axi_bvalid  <= 1'b0;
                        s_axi_awready <= 1'b1;
                        w_state       <= W_IDLE;
                    end
                end
            endcase
        end
    end

    // Read Channel Logic
    localparam [1:0] R_IDLE = 2'b00, R_DATA = 2'b01;
    reg [1:0] r_state;
    reg [13:0] rd_word_addr;
    reg [7:0]  rd_burst_rem;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state       <= R_IDLE;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rlast   <= 1'b0;
            s_axi_rdata   <= {DATA_WIDTH{1'b0}};
            rd_word_addr  <= 14'd0;
            rd_burst_rem  <= 8'd0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arready <= 1'b0;
                        rd_word_addr  <= s_axi_araddr[15:2];
                        rd_burst_rem  <= s_axi_arlen;
                        s_axi_rvalid  <= 1'b1;
                        s_axi_rdata   <= mem[s_axi_araddr[15:2]];
                        s_axi_rlast   <= (s_axi_arlen == 8'd0);
                        r_state       <= R_DATA;
                    end
                end

                R_DATA: begin
                    if (s_axi_rready && s_axi_rvalid) begin
                        if (rd_burst_rem == 8'd0) begin
                            s_axi_rvalid  <= 1'b0;
                            s_axi_rlast   <= 1'b0;
                            s_axi_arready <= 1'b1;
                            r_state       <= R_IDLE;
                        end else begin
                            rd_word_addr <= rd_word_addr + 1'b1;
                            rd_burst_rem <= rd_burst_rem - 1'b1;
                            s_axi_rdata  <= mem[rd_word_addr + 1'b1];
                            s_axi_rlast  <= (rd_burst_rem == 8'd1);
                        end
                    end
                end
            endcase
        end
    end

endmodule
