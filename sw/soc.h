// SPDX-License-Identifier: Apache-2.0
// soc.h - MMIO Header for VeeR-EL2 Neural Network Acceleration SoC
// Project: RISC-V Based SoC for Lightweight NN Inference Acceleration

#ifndef SOC_H
#define SOC_H

#include <stdint.h>

// =============================================================================
// Memory Map Definitions
// =============================================================================
#define IMEM_BASE_ADDR       0x00000000UL // 32 KB Instruction SRAM
#define DMEM_BASE_ADDR       0x10000000UL // 32 KB Data SRAM

#define UART_BASE_ADDR       0x80000000UL // 8-N-1 UART with 16-deep FIFO
#define TIMER_BASE_ADDR      0x80001000UL // 64-bit Real-time Timer
#define GPIO_BASE_ADDR       0x80002000UL // 16-bit Bi-directional GPIO
#define DMA_BASE_ADDR        0x80003000UL // Custom IP 3: DMA Controller
#define MATMULT_BASE_ADDR    0x80004000UL // Custom IP 1: Matrix Multiplier
#define ACTIVATION_BASE_ADDR 0x80005000UL // Custom IP 2: Activation Unit

// =============================================================================
// Peripheral Register Maps
// =============================================================================

// --- UART Registers ---
#define UART_REG_TXDATA      (*(volatile uint32_t *)(UART_BASE_ADDR + 0x00))
#define UART_REG_RXDATA      (*(volatile uint32_t *)(UART_BASE_ADDR + 0x00))
#define UART_REG_STATUS      (*(volatile uint32_t *)(UART_BASE_ADDR + 0x04))
#define UART_REG_BAUDDIV     (*(volatile uint32_t *)(UART_BASE_ADDR + 0x08))
#define UART_REG_CTRL        (*(volatile uint32_t *)(UART_BASE_ADDR + 0x0C))

#define UART_STATUS_TX_FULL  (1U << 0)
#define UART_STATUS_TX_EMPTY (1U << 1)
#define UART_STATUS_RX_EMPTY (1U << 2)
#define UART_STATUS_RX_FULL  (1U << 3)

// --- Timer Registers ---
#define TIMER_REG_MTIME_LO   (*(volatile uint32_t *)(TIMER_BASE_ADDR + 0x00))
#define TIMER_REG_MTIME_HI   (*(volatile uint32_t *)(TIMER_BASE_ADDR + 0x04))
#define TIMER_REG_MTIMECMP_LO (*(volatile uint32_t *)(TIMER_BASE_ADDR + 0x08))
#define TIMER_REG_MTIMECMP_HI (*(volatile uint32_t *)(TIMER_BASE_ADDR + 0x0C))
#define TIMER_REG_CTRL       (*(volatile uint32_t *)(TIMER_BASE_ADDR + 0x10))

// --- GPIO Registers ---
#define GPIO_REG_DATA_IN     (*(volatile uint32_t *)(GPIO_BASE_ADDR + 0x00))
#define GPIO_REG_DATA_OUT    (*(volatile uint32_t *)(GPIO_BASE_ADDR + 0x04))
#define GPIO_REG_DIR         (*(volatile uint32_t *)(GPIO_BASE_ADDR + 0x08))

// --- DMA Controller (IP 3) Registers ---
#define DMA_REG_CTRL         (*(volatile uint32_t *)(DMA_BASE_ADDR + 0x00))
#define DMA_REG_STATUS       (*(volatile uint32_t *)(DMA_BASE_ADDR + 0x04))
#define DMA_REG_SRC_ADDR     (*(volatile uint32_t *)(DMA_BASE_ADDR + 0x08))
#define DMA_REG_DST_ADDR     (*(volatile uint32_t *)(DMA_BASE_ADDR + 0x0C))
#define DMA_REG_BURST_LEN    (*(volatile uint32_t *)(DMA_BASE_ADDR + 0x10))

#define DMA_CTRL_START       (1U << 0)
#define DMA_CTRL_RESET       (1U << 1)
#define DMA_CTRL_DIR_ACC2MEM (1U << 2) // 0: Mem->Acc, 1: Acc->Mem
#define DMA_CTRL_TARGET_IN   (0U << 3)
#define DMA_CTRL_TARGET_W    (1U << 3)
#define DMA_CTRL_TARGET_BIAS (2U << 3)
#define DMA_CTRL_TARGET_ACT  (3U << 3)

#define DMA_STATUS_DONE      (1U << 0)
#define DMA_STATUS_BUSY      (1U << 1)
#define DMA_STATUS_ERROR     (1U << 2)

// --- Matrix Multiplier (IP 1) Registers ---
#define MAT_REG_CTRL         (*(volatile uint32_t *)(MATMULT_BASE_ADDR + 0x00))
#define MAT_REG_STATUS       (*(volatile uint32_t *)(MATMULT_BASE_ADDR + 0x04))
#define MAT_REG_DIM_MNK      (*(volatile uint32_t *)(MATMULT_BASE_ADDR + 0x08))
#define MAT_REG_BUF_INDEX    (*(volatile uint32_t *)(MATMULT_BASE_ADDR + 0x14))
#define MAT_REG_IN_DATA      (*(volatile uint32_t *)(MATMULT_BASE_ADDR + 0x18))
#define MAT_REG_W_DATA       (*(volatile uint32_t *)(MATMULT_BASE_ADDR + 0x1C))
#define MAT_REG_BIAS_DATA    (*(volatile uint32_t *)(MATMULT_BASE_ADDR + 0x20))
#define MAT_REG_OUT_DATA     (*(volatile uint32_t *)(MATMULT_BASE_ADDR + 0x24))

#define MAT_CTRL_START       (1U << 0)
#define MAT_CTRL_RESET       (1U << 1)
#define MAT_STATUS_DONE      (1U << 0)
#define MAT_STATUS_BUSY      (1U << 1)
#define MAT_STATUS_OVERFLOW  (1U << 2)

// --- Activation Unit (IP 2) Registers ---
#define ACT_REG_CTRL         (*(volatile uint32_t *)(ACTIVATION_BASE_ADDR + 0x00))
#define ACT_REG_STATUS       (*(volatile uint32_t *)(ACTIVATION_BASE_ADDR + 0x04))
#define ACT_REG_VEC_LEN      (*(volatile uint32_t *)(ACTIVATION_BASE_ADDR + 0x08))
#define ACT_REG_BUF_INDEX    (*(volatile uint32_t *)(ACTIVATION_BASE_ADDR + 0x10))
#define ACT_REG_IN_DATA      (*(volatile uint32_t *)(ACTIVATION_BASE_ADDR + 0x14))
#define ACT_REG_OUT_DATA     (*(volatile uint32_t *)(ACTIVATION_BASE_ADDR + 0x18))

#define ACT_CTRL_START       (1U << 0)
#define ACT_CTRL_RESET       (1U << 1)
#define ACT_FUNC_RELU        (0U << 2)
#define ACT_FUNC_SIGMOID     (1U << 2)
#define ACT_FUNC_TANH        (2U << 2)

#define ACT_STATUS_DONE      (1U << 0)
#define ACT_STATUS_BUSY      (1U << 1)

// =============================================================================
// Helper Functions
// =============================================================================
static inline void uart_putc(char c) {
    while (UART_REG_STATUS & UART_STATUS_TX_FULL);
    UART_REG_TXDATA = (uint32_t)c;
}

static inline void uart_puts(const char *str) {
    while (*str) {
        uart_putc(*str++);
    }
}

static inline void uart_puthex(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        uart_putc(hex_chars[(val >> (i * 4)) & 0xF]);
    }
}

#endif // SOC_H
