// ============================================================================
// Module Name: dma_write_controller
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: AXI4 Master Write Channel Controller for DMA.
//              Generates AXI4 write address requests (AW channel), drives write
//              data beats (W channel), and processes write responses (B channel).
// ============================================================================

`timescale 1ns / 1ps

module dma_write_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Control from DMA Engine
    input  wire                   start_write,
    input  wire [ADDR_WIDTH-1:0]  write_addr,
    input  wire [7:0]             burst_len_axi, // AWLEN = beats - 1
    output reg                    write_busy,
    output reg                    write_done,
    output reg                    write_error,

    // Interface from Transfer Engine / FIFO
    input  wire [DATA_WIDTH-1:0]  fifo_rd_data,
    input  wire                   fifo_empty,
    output reg                    fifo_rd_en,

    // AXI4 Master Write Address Channel
    output reg  [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output reg  [7:0]             m_axi_awlen,
    output reg  [2:0]             m_axi_awsize,
    output reg  [1:0]             m_axi_awburst,
    output reg                    m_axi_awvalid,
    input  wire                   m_axi_awready,

    // AXI4 Master Write Data Channel
    output reg  [DATA_WIDTH-1:0]  m_axi_wdata,
    output reg  [3:0]             m_axi_wstrb,
    output reg                    m_axi_wlast,
    output reg                    m_axi_wvalid,
    input  wire                   m_axi_wready,

    // AXI4 Master Write Response Channel
    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output reg                    m_axi_bready
);

    localparam [2:0] W_IDLE = 3'b000,
                     W_ADDR = 3'b001,
                     W_DATA = 3'b010,
                     W_RESP = 3'b011,
                     W_DONE = 3'b100;

    reg [2:0] state;
    reg [7:0] beat_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= W_IDLE;
            write_busy    <= 1'b0;
            write_done    <= 1'b0;
            write_error   <= 1'b0;
            beat_count    <= 8'd0;
            m_axi_awaddr  <= {ADDR_WIDTH{1'b0}};
            m_axi_awlen   <= 8'd0;
            m_axi_awsize  <= 3'b010;
            m_axi_awburst <= 2'b01;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata   <= {DATA_WIDTH{1'b0}};
            m_axi_wstrb   <= 4'hF;
            m_axi_wlast   <= 1'b0;
            m_axi_wvalid  <= 1'b0;
            m_axi_bready  <= 1'b0;
            fifo_rd_en    <= 1'b0;
        end else begin
            write_done <= 1'b0;
            fifo_rd_en <= 1'b0;

            case (state)
                W_IDLE: begin
                    if (start_write) begin
                        write_busy    <= 1'b1;
                        write_error   <= 1'b0;
                        beat_count    <= 8'd0;
                        m_axi_awaddr  <= write_addr;
                        m_axi_awlen   <= burst_len_axi;
                        m_axi_awsize  <= 3'b010;
                        m_axi_awburst <= 2'b01;
                        m_axi_awvalid <= 1'b1;
                        state         <= W_ADDR;
                    end else begin
                        write_busy <= 1'b0;
                    end
                end

                W_ADDR: begin
                    if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        // Prepare first write beat
                        m_axi_wdata   <= fifo_rd_data;
                        m_axi_wstrb   <= 4'hF;
                        m_axi_wvalid  <= 1'b1;
                        m_axi_wlast   <= (burst_len_axi == 8'd0);
                        fifo_rd_en    <= 1'b1;
                        state         <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (m_axi_wready && m_axi_wvalid) begin
                        if (beat_count == m_axi_awlen) begin
                            m_axi_wvalid <= 1'b0;
                            m_axi_wlast  <= 1'b0;
                            m_axi_bready <= 1'b1;
                            state        <= W_RESP;
                        end else begin
                            beat_count   <= beat_count + 1'b1;
                            m_axi_wdata  <= fifo_rd_data;
                            m_axi_wlast  <= (beat_count + 1'b1 == m_axi_awlen);
                            fifo_rd_en   <= 1'b1;
                        end
                    end
                end

                W_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        if (m_axi_bresp != 2'b00) begin
                            write_error <= 1'b1;
                        end
                        state <= W_DONE;
                    end
                end

                W_DONE: begin
                    write_busy <= 1'b0;
                    write_done <= 1'b1;
                    state      <= W_IDLE;
                end
            endcase
        end
    end

endmodule
