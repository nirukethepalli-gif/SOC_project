// SPDX-License-Identifier: Apache-2.0
// SoC VIP Interface Definitions for Neural Network Accelerator SoC
// Matches all Custom IPs and Baseline Peripherals

`timescale 1ns/1ps

`ifndef SOC_VIP_INTERFACES_SV
`define SOC_VIP_INTERFACES_SV

// =============================================================================
// 1. UART VIP Interface
// =============================================================================
interface uart_vip_if;
    logic        clk;
    logic        rst_n;
    logic        uart_rx = 1'b1;
    logic        uart_tx;
    logic        irq;

    // DUT Probes
    logic [7:0]  dut_rx_data;
    logic [7:0]  dut_last_rx_byte;
    logic        dut_rx_committed;
    logic [4:0]  dut_rx_count;
    logic        dut_rx_empty;
    logic        dut_status_frame_err;
    logic        dut_status_overrun;
    logic [3:0]  dut_rx_wptr;
    logic [3:0]  dut_rx_rptr;
endinterface

// =============================================================================
// 2. GPIO VIP Interface
// =============================================================================
interface gpio_vip_if;
    logic        clk;
    logic        rst_n;
    logic [15:0] gpio_in;
    logic [15:0] gpio_out;
    logic [15:0] gpio_oe;
    logic        irq;

    logic [15:0] drv_val = 16'h0000;
    logic [15:0] drv_en  = 16'h0000;

    logic [15:0] dut_data_out;
    logic [15:0] dut_dir;
endinterface

// =============================================================================
// 3. Timer VIP Interface
// =============================================================================
interface timer_vip_if;
    logic        clk;
    logic        rst_n;
    logic        timer_int;
    logic        irq;

    logic [63:0] dut_mtime;
    logic [63:0] dut_mtimecmp;
    logic        dut_ctrl_en;
endinterface

// =============================================================================
// 4. Matrix Multiplier VIP Interface (Custom IP 1)
// =============================================================================
interface matrix_multiplier_vip_if;
    logic        clk;
    logic        rst_n;
    logic        busy;
    logic        done;
    logic        irq;

    // Direct Accelerator Ports
    logic [31:0] stream_act_data;
    logic        stream_act_valid;
    logic        stream_act_ready;

    // DUT Internal Hardware Probes
    logic [7:0]  dut_dim_m;
    logic [7:0]  dut_dim_n;
    logic [7:0]  dut_dim_k;
    logic        dut_ctrl_start;
    logic        dut_status_overflow;
    logic [31:0] dut_mac_accum;
    logic [9:0]  dut_buf_index;
endinterface

// =============================================================================
// 5. Activation Unit VIP Interface (Custom IP 2)
// =============================================================================
interface activation_vip_if;
    logic        clk;
    logic        rst_n;
    logic        busy;
    logic        done;
    logic        irq;

    // Streaming Handshake
    logic [31:0] stream_in_data;
    logic        stream_in_valid;
    logic        stream_in_ready;

    // DUT Internal Hardware Probes
    logic [1:0]  dut_func_sel; // 00: ReLU, 01: Sigmoid, 10: Tanh
    logic [15:0] dut_vec_len;
    logic [15:0] dut_count;
    logic        dut_ctrl_start;
    logic [7:0]  dut_buf_index;
endinterface

// =============================================================================
// 6. DMA Controller VIP Interface (Custom IP 3)
// =============================================================================
interface dma_vip_if;
    logic        clk;
    logic        rst_n;
    logic        busy;
    logic        done;
    logic        error;
    logic        irq;

    // Memory Master Channel Probes
    logic [31:0] m_araddr;
    logic [7:0]  m_arlen;
    logic        m_arvalid;
    logic        m_arready;
    logic [31:0] m_awaddr;
    logic [7:0]  m_awlen;
    logic        m_awvalid;
    logic        m_awready;

    // DUT Internal Hardware Probes
    logic [31:0] dut_src_addr;
    logic [31:0] dut_dst_addr;
    logic [15:0] dut_burst_len;
    logic        dut_direction;
    logic [1:0]  dut_acc_target;
    logic [2:0]  dut_fsm_state;
endinterface

`endif // SOC_VIP_INTERFACES_SV
