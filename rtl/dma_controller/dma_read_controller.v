// ============================================================================
// Module Name: dma_read_controller
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: AXI4 Master Read Channel Controller for DMA.
//              Generates AXI4 read address requests (AR channel) and captures
//              read data (R channel) to supply the transfer engine.
// ============================================================================

`timescale 1ns / 1ps

module dma_read_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Control from DMA Engine
    input  wire                   start_read,
    input  wire [ADDR_WIDTH-1:0]  read_addr,
    input  wire [7:0]             burst_len_axi, // ARLEN = beats - 1
    output reg                    read_busy,
    output reg                    read_done,
    output reg                    read_error,

    // AXI4 Master Read Address Channel
    output reg  [ADDR_WIDTH-1:0]  m_axi_araddr,
    output reg  [7:0]             m_axi_arlen,
    output reg  [2:0]             m_axi_arsize,
    output reg  [1:0]             m_axi_arburst,
    output reg                    m_axi_arvalid,
    input  wire                   m_axi_arready,

    // AXI4 Master Read Data Channel
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rlast,
    input  wire                   m_axi_rvalid,
    output reg                    m_axi_rready,

    // Data passed to Transfer Engine / Internal FIFO
    output reg  [DATA_WIDTH-1:0]  fifo_wr_data,
    output reg                    fifo_wr_en
);

    localparam [1:0] R_IDLE = 2'b00, R_ADDR = 2'b01, R_DATA = 2'b10, R_DONE = 2'b11;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= R_IDLE;
            read_busy     <= 1'b0;
            read_done     <= 1'b0;
            read_error    <= 1'b0;
            m_axi_araddr  <= {ADDR_WIDTH{1'b0}};
            m_axi_arlen   <= 8'd0;
            m_axi_arsize  <= 3'b010; // 4 bytes (32-bit word)
            m_axi_arburst <= 2'b01;  // INCR burst
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            fifo_wr_en    <= 1'b0;
            fifo_wr_data  <= {DATA_WIDTH{1'b0}};
        end else begin
            fifo_wr_en <= 1'b0;
            read_done  <= 1'b0;

            case (state)
                R_IDLE: begin
                    if (start_read) begin
                        read_busy     <= 1'b1;
                        read_error    <= 1'b0;
                        m_axi_araddr  <= read_addr;
                        m_axi_arlen   <= burst_len_axi;
                        m_axi_arsize  <= 3'b010;
                        m_axi_arburst <= 2'b01;
                        m_axi_arvalid <= 1'b1;
                        state         <= R_ADDR;
                    end else begin
                        read_busy <= 1'b0;
                    end
                end

                R_ADDR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= R_DATA;
                    end
                end

                R_DATA: begin
                    if (m_axi_rvalid) begin
                        fifo_wr_data <= m_axi_rdata;
                        fifo_wr_en   <= 1'b1;

                        if (m_axi_rresp != 2'b00) begin
                            read_error <= 1'b1;
                        end

                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0;
                            state        <= R_DONE;
                        end
                    end
                end

                R_DONE: begin
                    read_busy <= 1'b0;
                    read_done <= 1'b1;
                    state     <= R_IDLE;
                end
            endcase
        end
    end

endmodule
