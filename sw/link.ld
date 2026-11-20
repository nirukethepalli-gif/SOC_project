/* SPDX-License-Identifier: Apache-2.0 */
/* Linker script for VeeR-EL2 SoC */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 32K
    DMEM (rw) : ORIGIN = 0x10000000, LENGTH = 32K
}

SECTIONS
{
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text)
        *(.text.*)
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
        _etext = .;
    } > IMEM

    .data : AT(_etext) {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > DMEM

    .bss : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > DMEM

    /* Stack pointer starts at the top of 32 KB DMEM */
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM) - 16;
}
