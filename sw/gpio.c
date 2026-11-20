// SPDX-License-Identifier: Apache-2.0
// gpio.c - Driver Implementation for GPIO

#include "gpio.h"

void gpio_init(uint16_t direction_mask) {
    GPIO_REG_DIR = (uint32_t)direction_mask;
}

void gpio_write(uint16_t val) {
    GPIO_REG_DATA_OUT = (uint32_t)val;
}

uint16_t gpio_read(void) {
    return (uint16_t)(GPIO_REG_DATA_IN & 0xFFFF);
}

void gpio_set_pin(uint8_t pin) {
    if (pin < 16) {
        GPIO_REG_DATA_OUT |= (1U << pin);
    }
}

void gpio_clear_pin(uint8_t pin) {
    if (pin < 16) {
        GPIO_REG_DATA_OUT &= ~(1U << pin);
    }
}
