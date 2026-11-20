// SPDX-License-Identifier: Apache-2.0
// matrix_multiplier.c - Driver Implementation for Matrix Multiplier

#include "matrix_multiplier.h"

void matmult_init(uint8_t m, uint8_t n, uint8_t k) {
    // Soft reset
    MAT_REG_CTRL = MAT_CTRL_RESET;
    matmult_set_dimensions(m, n, k);
}

void matmult_set_dimensions(uint8_t m, uint8_t n, uint8_t k) {
    MAT_REG_DIM_MNK = ((uint32_t)m << 16) | ((uint32_t)n << 8) | (uint32_t)k;
}

void matmult_load_inputs(const uint32_t *inputs, uint32_t count) {
    MAT_REG_BUF_INDEX = 0;
    for (uint32_t i = 0; i < count; i++) {
        MAT_REG_IN_DATA = inputs[i];
    }
}

void matmult_load_weights(const uint32_t *weights, uint32_t count) {
    MAT_REG_BUF_INDEX = 0;
    for (uint32_t i = 0; i < count; i++) {
        MAT_REG_W_DATA = weights[i];
    }
}

void matmult_load_biases(const uint32_t *biases, uint32_t count) {
    MAT_REG_BUF_INDEX = 0;
    for (uint32_t i = 0; i < count; i++) {
        MAT_REG_BIAS_DATA = biases[i];
    }
}

void matmult_start(void) {
    MAT_REG_CTRL = MAT_CTRL_START;
}

void matmult_wait_done(void) {
    while (!(MAT_REG_STATUS & MAT_STATUS_DONE));
}

uint32_t matmult_is_busy(void) {
    return (MAT_REG_STATUS & MAT_STATUS_BUSY) ? 1 : 0;
}

uint32_t matmult_is_done(void) {
    return (MAT_REG_STATUS & MAT_STATUS_DONE) ? 1 : 0;
}

uint32_t matmult_has_overflow(void) {
    return (MAT_REG_STATUS & MAT_STATUS_OVERFLOW) ? 1 : 0;
}

void matmult_read_outputs(uint32_t *outputs, uint32_t count) {
    MAT_REG_BUF_INDEX = 0;
    for (uint32_t i = 0; i < count; i++) {
        outputs[i] = MAT_REG_OUT_DATA;
    }
}
