// SPDX-License-Identifier: Apache-2.0
// uart.c - Driver Implementation for UART

#include "uart.h"

void uart_init(uint16_t bauddiv) {
    UART_REG_BAUDDIV = (uint32_t)bauddiv;
    UART_REG_CTRL    = 0x03; // Enable TX & RX
}

void uart_write_char(char c) {
    while (UART_REG_STATUS & UART_STATUS_TX_FULL);
    UART_REG_TXDATA = (uint32_t)c;
}

char uart_read_char(void) {
    while (UART_REG_STATUS & UART_STATUS_RX_EMPTY);
    return (char)(UART_REG_RXDATA & 0xFF);
}

void uart_write_string(const char *str) {
    while (*str) {
        uart_write_char(*str++);
    }
}

void uart_write_hex(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_write_string("0x");
    for (int i = 7; i >= 0; i--) {
        uart_write_char(hex_chars[(val >> (i * 4)) & 0xF]);
    }
}
