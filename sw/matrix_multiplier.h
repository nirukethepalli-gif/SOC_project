// SPDX-License-Identifier: Apache-2.0
// matrix_multiplier.h - Driver for Custom IP 1: Matrix Multiplier
// Base Address: 0x8000_4000

#ifndef MATRIX_MULTIPLIER_H
#define MATRIX_MULTIPLIER_H

#include "soc.h"

// Configuration
void matmult_init(uint8_t m, uint8_t n, uint8_t k);
void matmult_set_dimensions(uint8_t m, uint8_t n, uint8_t k);

// Buffer loading
void matmult_load_inputs(const uint32_t *inputs, uint32_t count);
void matmult_load_weights(const uint32_t *weights, uint32_t count);
void matmult_load_biases(const uint32_t *biases, uint32_t count);

// Execution
void matmult_start(void);
void matmult_wait_done(void);
uint32_t matmult_is_busy(void);
uint32_t matmult_is_done(void);
uint32_t matmult_has_overflow(void);

// Readback
void matmult_read_outputs(uint32_t *outputs, uint32_t count);

#endif // MATRIX_MULTIPLIER_H
