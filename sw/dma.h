// SPDX-License-Identifier: Apache-2.0
// dma.h - Driver for Custom IP 3: DMA Controller
// Base Address: 0x8000_3000

#ifndef DMA_H
#define DMA_H

#include "soc.h"

typedef enum {
    DMA_TARGET_INPUT_BUF  = 0,
    DMA_TARGET_WEIGHT_BUF = 1,
    DMA_TARGET_BIAS_BUF   = 2,
    DMA_TARGET_ACTIVATION = 3
} dma_target_t;

typedef enum {
    DMA_DIR_MEM_TO_ACCEL = 0,
    DMA_DIR_ACCEL_TO_MEM = 1
} dma_direction_t;

// Configuration and Execution
void dma_init(void);
void dma_start_transfer(uint32_t src_addr, uint32_t dst_addr, uint16_t burst_len,
                        dma_direction_t dir, dma_target_t target);
void dma_wait_done(void);
uint32_t dma_is_busy(void);
uint32_t dma_is_done(void);
uint32_t dma_has_error(void);

#endif // DMA_H
