// SPDX-License-Identifier: Apache-2.0
// gpio.h - Driver for 16-bit Bi-directional GPIO
// Base Address: 0x8000_2000

#ifndef GPIO_H
#define GPIO_H

#include "soc.h"

void gpio_init(uint16_t direction_mask);
void gpio_write(uint16_t val);
uint16_t gpio_read(void);
void gpio_set_pin(uint8_t pin);
void gpio_clear_pin(uint8_t pin);

#endif // GPIO_H
