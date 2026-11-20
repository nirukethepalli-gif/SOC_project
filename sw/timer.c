// SPDX-License-Identifier: Apache-2.0
// timer.c - Driver Implementation for Timer

#include "timer.h"

void timer_init(void) {
    TIMER_REG_CTRL = 0x01; // Enable timer counting
}

uint64_t timer_get_cycles(void) {
    uint32_t hi, lo;
    do {
        hi = TIMER_REG_MTIME_HI;
        lo = TIMER_REG_MTIME_LO;
    } while (hi != TIMER_REG_MTIME_HI);
    return (((uint64_t)hi) << 32) | lo;
}

void timer_set_compare(uint64_t cmp_val) {
    TIMER_REG_MTIMECMP_HI = 0xFFFFFFFF; // Avoid spurious interrupt during update
    TIMER_REG_MTIMECMP_LO = (uint32_t)cmp_val;
    TIMER_REG_MTIMECMP_HI = (uint32_t)(cmp_val >> 32);
}

void timer_delay_cycles(uint32_t cycles) {
    uint64_t start = timer_get_cycles();
    while ((timer_get_cycles() - start) < cycles);
}
