// ============================================================================
// Module Name: axi4_to_axilite_bridge
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Standalone AXI4 to AXI4-Lite Protocol Converter Bridge.
//              Converts full AXI4 transactions from the RISC-V processor core
//              or DMA master into single-beat AXI4-Lite slave transactions.
//              Decomposes AXI4 bursts (INCR mode) into individual Lite accesses,
//              handles byte strobes, backpressure, and response propagation.
// ============================================================================

`timescale 1ns / 1ps

module axi4_to_axilite_bridge #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // =========================================================================
    // Full AXI4 Slave Interface (Facing RISC-V Processor Core / Master)
    // =========================================================================
    // Write Address Channel
    input  wire [ID_WIDTH-1:0]    s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_awaddr,
    input  wire [7:0]             s_axi_awlen,
    input  wire [2:0]             s_axi_awsize,
    input  wire [1:0]             s_axi_awburst,
    input  wire [2:0]             s_axi_awprot,
    input  wire                   s_axi_awvalid,
    output reg                    s_axi_awready,

    // Write Data Channel
    input  wire [DATA_WIDTH-1:0]  s_axi_wdata,
    input  wire [3:0]             s_axi_wstrb,
    input  wire                   s_axi_wlast,
    input  wire                   s_axi_wvalid,
    output reg                    s_axi_wready,

    // Write Response Channel
    output reg  [ID_WIDTH-1:0]    s_axi_bid,
    output reg  [1:0]             s_axi_bresp,
    output reg                    s_axi_bvalid,
    input  wire                   s_axi_bready,

    // Read Address Channel
    input  wire [ID_WIDTH-1:0]    s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]  s_axi_araddr,
    input  wire [7:0]             s_axi_arlen,
    input  wire [2:0]             s_axi_arsize,
    input  wire [1:0]             s_axi_arburst,
    input  wire [2:0]             s_axi_arprot,
    input  wire                   s_axi_arvalid,
    output reg                    s_axi_arready,

    // Read Data Channel
    output reg  [ID_WIDTH-1:0]    s_axi_rid,
    output reg  [DATA_WIDTH-1:0]  s_axi_rdata,
    output reg  [1:0]             s_axi_rresp,
    output reg                    s_axi_rlast,
    output reg                    s_axi_rvalid,
    input  wire                   s_axi_rready,

    // =========================================================================
    // AXI4-Lite Master Interface (Facing Custom Peripheral Subsystem)
    // =========================================================================
    // Write Address Channel
    output reg  [ADDR_WIDTH-1:0]  m_axil_awaddr,
    output reg  [2:0]             m_axil_awprot,
    output reg                    m_axil_awvalid,
    input  wire                   m_axil_awready,

    // Write Data Channel
    output reg  [DATA_WIDTH-1:0]  m_axil_wdata,
    output reg  [3:0]             m_axil_wstrb,
    output reg                    m_axil_wvalid,
    input  wire                   m_axil_wready,

    // Write Response Channel
    input  wire [1:0]             m_axil_bresp,
    input  wire                   m_axil_bvalid,
    output reg                    m_axil_bready,

    // Read Address Channel
    output reg  [ADDR_WIDTH-1:0]  m_axil_araddr,
    output reg  [2:0]             m_axil_arprot,
    output reg                    m_axil_arvalid,
    input  wire                   m_axil_arready,

    // Read Data Channel
    input  wire [DATA_WIDTH-1:0]  m_axil_rdata,
    input  wire [1:0]             m_axil_rresp,
    input  wire                   m_axil_rvalid,
    output reg                    m_axil_rready
);

    // =========================================================================
    // Write State Machine
    // =========================================================================
    localparam [2:0] W_IDLE     = 3'b000,
                     W_LITE_REQ = 3'b001,
                     W_LITE_WAIT= 3'b010,
                     W_RESP     = 3'b011;

    reg [2:0] w_state;
    reg [ID_WIDTH-1:0]   reg_awid;
    reg [ADDR_WIDTH-1:0] reg_awaddr;
    reg [7:0]            reg_awlen;
    reg [7:0]            w_beat_count;
    reg [1:0]            accum_bresp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state        <= W_IDLE;
            s_axi_awready  <= 1'b0;
            s_axi_wready   <= 1'b0;
            s_axi_bvalid   <= 1'b0;
            s_axi_bid      <= {ID_WIDTH{1'b0}};
            s_axi_bresp    <= 2'b00;
            m_axil_awaddr  <= {ADDR_WIDTH{1'b0}};
            m_axil_awprot  <= 3'b000;
            m_axil_awvalid <= 1'b0;
            m_axil_wdata   <= {DATA_WIDTH{1'b0}};
            m_axil_wstrb   <= 4'h0;
            m_axil_wvalid  <= 1'b0;
            m_axil_bready  <= 1'b0;
            w_beat_count   <= 8'd0;
            accum_bresp    <= 2'b00;
            reg_awid       <= {ID_WIDTH{1'b0}};
            reg_awaddr     <= {ADDR_WIDTH{1'b0}};
            reg_awlen      <= 8'd0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    s_axi_awready <= 1'b1;
                    if (s_axi_awvalid && s_axi_awready) begin
                        s_axi_awready <= 1'b0;
                        reg_awid      <= s_axi_awid;
                        reg_awaddr    <= s_axi_awaddr;
                        reg_awlen     <= s_axi_awlen;
                        w_beat_count  <= 8'd0;
                        accum_bresp   <= 2'b00;
                        s_axi_wready  <= 1'b1;
                        w_state       <= W_LITE_REQ;
                    end
                end

                W_LITE_REQ: begin
                    if (s_axi_wvalid && s_axi_wready) begin
                        s_axi_wready   <= 1'b0;
                        m_axil_awaddr  <= reg_awaddr;
                        m_axil_awprot  <= 3'b000;
                        m_axil_awvalid <= 1'b1;
                        m_axil_wdata   <= s_axi_wdata;
                        m_axil_wstrb   <= s_axi_wstrb;
                        m_axil_wvalid  <= 1'b1;
                        m_axil_bready  <= 1'b1;
                        w_state        <= W_LITE_WAIT;
                    end
                end

                W_LITE_WAIT: begin
                    if (m_axil_awready && m_axil_awvalid) m_axil_awvalid <= 1'b0;
                    if (m_axil_wready && m_axil_wvalid)   m_axil_wvalid  <= 1'b0;

                    if (m_axil_bvalid && m_axil_bready) begin
                        m_axil_bready <= 1'b0;
                        if (m_axil_bresp != 2'b00) accum_bresp <= m_axil_bresp;

                        if (w_beat_count == reg_awlen) begin
                            // Burst complete: send single AXI4 write response
                            s_axi_bid    <= reg_awid;
                            s_axi_bresp  <= (accum_bresp != 2'b00) ? accum_bresp : m_axil_bresp;
                            s_axi_bvalid <= 1'b1;
                            w_state      <= W_RESP;
                        end else begin
                            // Advance to next beat in burst
                            w_beat_count <= w_beat_count + 1'b1;
                            reg_awaddr   <= reg_awaddr + 32'd4;
                            s_axi_wready <= 1'b1;
                            w_state      <= W_LITE_REQ;
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

    // =========================================================================
    // Read State Machine
    // =========================================================================
    localparam [1:0] R_IDLE      = 2'b00,
                     R_LITE_ADDR = 2'b01,
                     R_LITE_DATA = 2'b10;

    reg [1:0] r_state;
    reg [ID_WIDTH-1:0]   reg_arid;
    reg [ADDR_WIDTH-1:0] reg_araddr;
    reg [7:0]            reg_arlen;
    reg [7:0]            r_beat_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state        <= R_IDLE;
            s_axi_arready  <= 1'b0;
            s_axi_rvalid   <= 1'b0;
            s_axi_rid      <= {ID_WIDTH{1'b0}};
            s_axi_rdata    <= {DATA_WIDTH{1'b0}};
            s_axi_rresp    <= 2'b00;
            s_axi_rlast    <= 1'b0;
            m_axil_araddr  <= {ADDR_WIDTH{1'b0}};
            m_axil_arprot  <= 3'b000;
            m_axil_arvalid <= 1'b0;
            m_axil_rready  <= 1'b0;
            r_beat_count   <= 8'd0;
            reg_arid       <= {ID_WIDTH{1'b0}};
            reg_araddr     <= {ADDR_WIDTH{1'b0}};
            reg_arlen      <= 8'd0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    s_axi_arready <= 1'b1;
                    if (s_axi_arvalid && s_axi_arready) begin
                        s_axi_arready  <= 1'b0;
                        reg_arid       <= s_axi_arid;
                        reg_araddr     <= s_axi_araddr;
                        reg_arlen      <= s_axi_arlen;
                        r_beat_count   <= 8'd0;
                        m_axil_araddr  <= s_axi_araddr;
                        m_axil_arprot  <= 3'b000;
                        m_axil_arvalid <= 1'b1;
                        r_state        <= R_LITE_ADDR;
                    end
                end

                R_LITE_ADDR: begin
                    if (m_axil_arready && m_axil_arvalid) begin
                        m_axil_arvalid <= 1'b0;
                        m_axil_rready  <= 1'b1;
                        r_state        <= R_LITE_DATA;
                    end
                end

                R_LITE_DATA: begin
                    if (m_axil_rvalid && m_axil_rready) begin
                        m_axil_rready <= 1'b0;
                        s_axi_rid     <= reg_arid;
                        s_axi_rdata   <= m_axil_rdata;
                        s_axi_rresp   <= m_axil_rresp;
                        s_axi_rvalid  <= 1'b1;
                        s_axi_rlast   <= (r_beat_count == reg_arlen);
                    end

                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        s_axi_rlast  <= 1'b0;

                        if (r_beat_count == reg_arlen) begin
                            s_axi_arready <= 1'b1;
                            r_state       <= R_IDLE;
                        end else begin
                            r_beat_count   <= r_beat_count + 1'b1;
                            reg_araddr     <= reg_araddr + 32'd4;
                            m_axil_araddr  <= reg_araddr + 32'd4;
                            m_axil_arprot  <= 3'b000;
                            m_axil_arvalid <= 1'b1;
                            r_state        <= R_LITE_ADDR;
                        end
                    end
                end
            endcase
        end
    end

endmodule
