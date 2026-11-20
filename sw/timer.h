// SPDX-License-Identifier: Apache-2.0
// timer.h - Driver for 64-bit Real-Time Timer
// Base Address: 0x8000_1000

#ifndef TIMER_H
#define TIMER_H

#include "soc.h"

void timer_init(void);
uint64_t timer_get_cycles(void);
void timer_set_compare(uint64_t cmp_val);
void timer_delay_cycles(uint32_t cycles);

#endif // TIMER_H
