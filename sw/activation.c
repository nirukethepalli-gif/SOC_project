// SPDX-License-Identifier: Apache-2.0
// activation.c - Driver Implementation for Activation Unit

#include "activation.h"

void activation_init(activation_func_t func, uint16_t vector_len) {
    ACT_REG_CTRL = ACT_CTRL_RESET;
    activation_set_function(func);
    activation_set_vector_length(vector_len);
}

void activation_set_function(activation_func_t func) {
    uint32_t f_code = 0;
    if (func == ACTIVATION_SIGMOID) f_code = ACT_FUNC_SIGMOID;
    else if (func == ACTIVATION_TANH) f_code = ACT_FUNC_TANH;
    else f_code = ACT_FUNC_RELU;

    ACT_REG_CTRL = f_code;
}

void activation_set_vector_length(uint16_t len) {
    ACT_REG_VEC_LEN = len;
}

void activation_load_vector(const uint32_t *data, uint16_t count) {
    ACT_REG_BUF_INDEX = 0;
    for (uint16_t i = 0; i < count; i++) {
        ACT_REG_IN_DATA = data[i];
    }
}

void activation_start(void) {
    ACT_REG_CTRL |= ACT_CTRL_START;
}

void activation_wait_done(void) {
    while (!(ACT_REG_STATUS & ACT_STATUS_DONE));
}

uint32_t activation_is_busy(void) {
    return (ACT_REG_STATUS & ACT_STATUS_BUSY) ? 1 : 0;
}

uint32_t activation_is_done(void) {
    return (ACT_REG_STATUS & ACT_STATUS_DONE) ? 1 : 0;
}

void activation_read_vector(uint32_t *results, uint16_t count) {
    ACT_REG_BUF_INDEX = 0;
    for (uint16_t i = 0; i < count; i++) {
        results[i] = ACT_REG_OUT_DATA;
    }
}
