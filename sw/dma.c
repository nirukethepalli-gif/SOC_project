// SPDX-License-Identifier: Apache-2.0
// dma.c - Driver Implementation for DMA Controller

#include "dma.h"

void dma_init(void) {
    DMA_REG_CTRL = DMA_CTRL_RESET;
}

void dma_start_transfer(uint32_t src_addr, uint32_t dst_addr, uint16_t burst_len,
                        dma_direction_t dir, dma_target_t target) {
    DMA_REG_SRC_ADDR  = src_addr;
    DMA_REG_DST_ADDR  = dst_addr;
    DMA_REG_BURST_LEN = (uint32_t)burst_len;

    uint32_t ctrl_val = DMA_CTRL_START;
    if (dir == DMA_DIR_ACCEL_TO_MEM) {
        ctrl_val |= DMA_CTRL_DIR_ACC2MEM;
    }
    ctrl_val |= ((uint32_t)target << 3);

    DMA_REG_CTRL = ctrl_val;
}

void dma_wait_done(void) {
    while (!(DMA_REG_STATUS & DMA_STATUS_DONE));
}

uint32_t dma_is_busy(void) {
    return (DMA_REG_STATUS & DMA_STATUS_BUSY) ? 1 : 0;
}

uint32_t dma_is_done(void) {
    return (DMA_REG_STATUS & DMA_STATUS_DONE) ? 1 : 0;
}

uint32_t dma_has_error(void) {
    return (DMA_REG_STATUS & DMA_STATUS_ERROR) ? 1 : 0;
}
