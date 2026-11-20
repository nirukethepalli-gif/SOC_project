// SPDX-License-Identifier: Apache-2.0
// activation.h - Driver for Custom IP 2: Activation Unit
// Base Address: 0x8000_5000

#ifndef ACTIVATION_H
#define ACTIVATION_H

#include "soc.h"

typedef enum {
    ACTIVATION_RELU    = 0,
    ACTIVATION_SIGMOID = 1,
    ACTIVATION_TANH    = 2
} activation_func_t;

// Configuration
void activation_init(activation_func_t func, uint16_t vector_len);
void activation_set_function(activation_func_t func);
void activation_set_vector_length(uint16_t len);

// Data loading
void activation_load_vector(const uint32_t *data, uint16_t count);

// Execution
void activation_start(void);
void activation_wait_done(void);
uint32_t activation_is_busy(void);
uint32_t activation_is_done(void);

// Readback
void activation_read_vector(uint32_t *results, uint16_t count);

#endif // ACTIVATION_H
