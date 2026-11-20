// SPDX-License-Identifier: Apache-2.0
// uart.h - Driver for 16550-like UART
// Base Address: 0x8000_0000

#ifndef UART_H
#define UART_H

#include "soc.h"

void uart_init(uint16_t bauddiv);
void uart_write_char(char c);
char uart_read_char(void);
void uart_write_string(const char *str);
void uart_write_hex(uint32_t val);

#endif // UART_H
