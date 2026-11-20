# SPDX-License-Identifier: Apache-2.0
# Startup code for VeeR-EL2 SoC

.section .text.init
.global _start
.type _start, @function

_start:
    # Set stack pointer to top of Data Memory
    la      sp, _stack_top

    # Set global pointer
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    # Clear BSS section
    la      a0, _sbss
    la      a1, _ebss
bss_clear_loop:
    bge     a0, a1, bss_clear_done
    sw      zero, 0(a0)
    addi    a0, a0, 4
    j       bss_clear_loop

bss_clear_done:
    # Copy initialized data section from IMEM to DMEM
    la      a0, _etext
    la      a1, _sdata
    la      a2, _edata
data_copy_loop:
    bge     a1, a2, data_copy_done
    lw      t0, 0(a0)
    sw      t0, 0(a1)
    addi    a0, a0, 4
    addi    a1, a1, 4
    j       data_copy_loop

data_copy_done:
    # Jump to C main()
    call    main

    # If main returns, loop forever
hang:
    wfi
    j       hang

.size _start, .-_start
