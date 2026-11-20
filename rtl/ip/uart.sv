// SPDX-License-Identifier: Apache-2.0
// 8-N-1 UART with 16-deep TX/RX FIFOs (uart)
// Compliant with Section 8.4 of VeeR EL2 SoC Specification v2.0

`timescale 1ns/1ps

module uart #(
    parameter int FIFO_DEPTH = 16
)(
    input  logic                 aclk,
    input  logic                 aresetn,

    // AXI4-Lite Slave Port
    input  logic [31:0]          s_awaddr,
    input  logic [2:0]           s_awprot,
    input  logic                 s_awvalid,
    output logic                 s_awready,

    input  logic [31:0]          s_wdata,
    input  logic [3:0]           s_wstrb,
    input  logic                 s_wvalid,
    output logic                 s_wready,

    output logic [1:0]           s_bresp,
    output logic                 s_bvalid,
    input  logic                 s_bready,

    input  logic [31:0]          s_araddr,
    input  logic [2:0]           s_arprot,
    input  logic                 s_arvalid,
    output logic                 s_arready,

    output logic [31:0]          s_rdata,
    output logic [1:0]           s_rresp,
    output logic                 s_rvalid,
    input  logic                 s_rready,

    // Pins
    output logic                 uart_tx,
    input  logic                 uart_rx,
    output logic                 irq
);

    // Register interface signals from shim
    logic [5:0]  reg_waddr;
    logic [31:0] reg_wdata;
    logic        reg_wen;
    logic [5:0]  reg_raddr;
    logic        reg_ren;
    logic [31:0] reg_rdata;
    logic        reg_err;

    assign reg_err = 1'b0;

    axi4lite_regif #(
        .ADDR_LSB(2),
        .REG_BITS(6)
    ) u_regif (
        .aclk     (aclk),
        .aresetn  (aresetn),
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
        .s_rready (s_rready),
        .reg_waddr(reg_waddr),
        .reg_wdata(reg_wdata),
        .reg_wen  (reg_wen),
        .reg_raddr(reg_raddr),
        .reg_ren  (reg_ren),
        .reg_rdata(reg_rdata),
        .reg_err  (reg_err)
    );

    // Registers
    logic [15:0] bauddiv; // default 434
    logic        ctrl_tx_en;
    logic        ctrl_rx_en;
    logic        ctrl_tx_irq_en;
    logic        ctrl_rx_irq_en;
    logic        status_overrun;
    logic        status_frame_err;

    // 16-deep FIFOs
    logic [7:0] tx_fifo [0:FIFO_DEPTH-1];
    logic [3:0] tx_wptr, tx_rptr;
    logic [4:0] tx_count;

    logic [7:0] rx_fifo [0:FIFO_DEPTH-1];
    logic [3:0] rx_wptr, rx_rptr;
    logic [4:0] rx_count;

    wire tx_full  = (tx_count == FIFO_DEPTH);
    wire tx_empty = (tx_count == 0);
    wire rx_full  = (rx_count == FIFO_DEPTH);
    wire rx_empty = (rx_count == 0);

    assign irq = (ctrl_tx_irq_en && tx_empty) || (ctrl_rx_irq_en && !rx_empty);

    // TX FIFO push (on write to 0x00)
    wire tx_push = reg_wen && (reg_waddr == 6'd0) && !tx_full;

    // RX FIFO pop (on read from 0x00)
    wire rx_pop  = reg_ren && (reg_raddr == 6'd0) && !rx_empty;

    // =========================================================================
    // Transmitter FSM
    // =========================================================================
    typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_t;
    tx_state_t tx_state;

    logic [15:0] tx_baud_cnt;
    logic [2:0]  tx_bit_idx;
    logic [7:0]  tx_shift_reg;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            tx_state     <= TX_IDLE;
            uart_tx      <= 1'b1;
            tx_baud_cnt  <= '0;
            tx_bit_idx   <= '0;
            tx_shift_reg <= '0;
            tx_rptr      <= '0;
            tx_wptr      <= '0;
            tx_count     <= '0;
        end else begin
            // TX FIFO Push
            if (tx_push) begin
                tx_fifo[tx_wptr] <= reg_wdata[7:0];
                tx_wptr <= tx_wptr + 1;
            end

            // TX State Machine
            case (tx_state)
                TX_IDLE: begin
                    uart_tx <= 1'b1;
                    if (!tx_empty && ctrl_tx_en) begin
                        tx_shift_reg <= tx_fifo[tx_rptr];
                        tx_rptr      <= tx_rptr + 1;
                        tx_count     <= tx_push ? tx_count : tx_count - 1;
                        tx_baud_cnt  <= '0;
                        tx_state     <= TX_START;
                    end else if (tx_push) begin
                        tx_count <= tx_count + 1;
                    end
                end

                TX_START: begin
                    uart_tx <= 1'b0; // Start bit
                    if (tx_baud_cnt >= (bauddiv > 0 ? bauddiv - 1 : 0)) begin
                        tx_baud_cnt <= '0;
                        tx_bit_idx  <= '0;
                        tx_state    <= TX_DATA;
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 1;
                    end
                    if (tx_push) tx_count <= tx_count + 1;
                end

                TX_DATA: begin
                    uart_tx <= tx_shift_reg[tx_bit_idx];
                    if (tx_baud_cnt >= (bauddiv > 0 ? bauddiv - 1 : 0)) begin
                        tx_baud_cnt <= '0;
                        if (tx_bit_idx == 3'd7) begin
                            tx_state <= TX_STOP;
                        end else begin
                            tx_bit_idx <= tx_bit_idx + 1;
                        end
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 1;
                    end
                    if (tx_push) tx_count <= tx_count + 1;
                end

                TX_STOP: begin
                    uart_tx <= 1'b1; // Stop bit
                    if (tx_baud_cnt >= (bauddiv > 0 ? bauddiv - 1 : 0)) begin
                        tx_baud_cnt <= '0;
                        tx_state    <= TX_IDLE;
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 1;
                    end
                    if (tx_push) tx_count <= tx_count + 1;
                end
            endcase
        end
    end

    // =========================================================================
    // Receiver FSM (16x oversampling)
    // =========================================================================
    // 2-FF input synchronizer
    logic rx_sync1, rx_sync2;
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= uart_rx;
            rx_sync2 <= rx_sync1;
        end
    end

    typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;
    rx_state_t rx_state;

    logic [15:0] rx_baud_cnt;
    logic [3:0]  rx_sample_cnt;
    logic [2:0]  rx_bit_idx;
    logic [7:0]  rx_shift_reg;
    wire  [15:0] sample_period = (bauddiv >= 16) ? (bauddiv >> 4) : 16'd1;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            rx_state         <= RX_IDLE;
            rx_baud_cnt      <= '0;
            rx_sample_cnt    <= '0;
            rx_bit_idx       <= '0;
            rx_shift_reg     <= '0;
            rx_wptr          <= '0;
            rx_rptr          <= '0;
            rx_count         <= '0;
            status_overrun   <= 1'b0;
            status_frame_err <= 1'b0;
        end else begin
            // RX FIFO Pop
            if (rx_pop) begin
                rx_rptr  <= rx_rptr + 1;
                rx_count <= rx_count - 1;
            end

            // Receiver FSM
            case (rx_state)
                RX_IDLE: begin
                    rx_baud_cnt   <= '0;
                    rx_sample_cnt <= '0;
                    if (!rx_sync2 && ctrl_rx_en) begin // Falling edge detection
                        rx_state <= RX_START;
                    end
                end

                RX_START: begin
                    if (rx_baud_cnt >= (sample_period > 0 ? sample_period - 1 : 0)) begin
                        rx_baud_cnt <= '0;
                        if (rx_sample_cnt == 4'd7) begin
                            if (!rx_sync2) begin // Valid start bit sampled at midpoint
                                rx_sample_cnt <= '0;
                                rx_bit_idx    <= '0;
                                rx_state      <= RX_DATA;
                            end else begin
                                rx_state <= RX_IDLE; // False start glitch
                            end
                        end else begin
                            rx_sample_cnt <= rx_sample_cnt + 1;
                        end
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt + 1;
                    end
                end

                RX_DATA: begin
                    if (rx_baud_cnt >= (sample_period > 0 ? sample_period - 1 : 0)) begin
                        rx_baud_cnt <= '0;
                        if (rx_sample_cnt == 4'd15) begin
                            rx_sample_cnt              <= '0;
                            rx_shift_reg[rx_bit_idx]   <= rx_sync2;
                            if (rx_bit_idx == 3'd7) begin
                                rx_state <= RX_STOP;
                            end else begin
                                rx_bit_idx <= rx_bit_idx + 1;
                            end
                        end else begin
                            rx_sample_cnt <= rx_sample_cnt + 1;
                        end
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt + 1;
                    end
                end

                RX_STOP: begin
                    if (rx_baud_cnt >= (sample_period > 0 ? sample_period - 1 : 0)) begin
                        rx_baud_cnt <= '0;
                        if (rx_sample_cnt == 4'd15) begin
                            if (rx_sync2) begin // Valid stop bit
                                if (!rx_full) begin
                                    rx_fifo[rx_wptr] <= rx_shift_reg;
                                    rx_wptr          <= rx_wptr + 1;
                                    rx_count         <= rx_pop ? rx_count : rx_count + 1;
                                end else begin
                                    status_overrun <= 1'b1;
                                end
                            end else begin
                                status_frame_err <= 1'b1;
                            end
                            rx_state <= RX_IDLE;
                        end else begin
                            rx_sample_cnt <= rx_sample_cnt + 1;
                        end
                    end else begin
                        rx_baud_cnt <= rx_baud_cnt + 1;
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // Control & Status Register Writes & Reads
    // =========================================================================
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            bauddiv        <= 16'd434;
            ctrl_tx_en     <= 1'b1;
            ctrl_rx_en     <= 1'b1;
            ctrl_tx_irq_en <= 1'b0;
            ctrl_rx_irq_en <= 1'b0;
        end else if (reg_wen) begin
            case (reg_waddr)
                6'd2: bauddiv <= reg_wdata[15:0]; // 0x08
                6'd3: begin // 0x0C
                    ctrl_tx_en     <= reg_wdata[0];
                    ctrl_rx_en     <= reg_wdata[1];
                    ctrl_tx_irq_en <= reg_wdata[2];
                    ctrl_rx_irq_en <= reg_wdata[3];
                end
                default: ;
            endcase
        end
    end

    // Read mux
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            reg_rdata <= 32'h0;
        end else if (reg_ren) begin
            case (reg_raddr)
                6'd0: reg_rdata <= {24'b0, rx_fifo[rx_rptr]}; // RXDATA
                6'd1: reg_rdata <= {26'b0, status_frame_err, status_overrun, rx_full, rx_empty, tx_empty, tx_full}; // 0x04
                6'd2: reg_rdata <= {16'b0, bauddiv}; // 0x08
                6'd3: reg_rdata <= {28'b0, ctrl_rx_irq_en, ctrl_tx_irq_en, ctrl_rx_en, ctrl_tx_en}; // 0x0C
                default: reg_rdata <= 32'h0;
            endcase
        end
    end

endmodule

