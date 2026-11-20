# ==============================================================================
# Bare-Metal Software Build Makefile for VeeR-EL2 SoC
# Cross-compiler: riscv32-unknown-elf-gcc (or riscv64-unknown-elf-gcc with -march=rv32imc)
# ==============================================================================

CC      = riscv32-unknown-elf-gcc
OBJCOPY = riscv32-unknown-elf-objcopy
OBJDUMP = riscv32-unknown-elf-objdump
SIZE    = riscv32-unknown-elf-size

CFLAGS  = -march=rv32imc -mabi=ilp32 -O2 -g -Wall -ffreestanding -nostdlib -I.
LDFLAGS = -T link.ld -nostdlib

SRCS    = crt0.S main.c matrix_multiplier.c activation.c dma.c uart.c timer.c gpio.c
OBJS    = $(SRCS:.c=.o)
OBJS   := $(OBJS:.S=.o)

all: main.elf main.bin main.hex main.dis

main.elf: $(OBJS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@
	$(SIZE) $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

main.bin: main.elf
	$(OBJCOPY) -O binary $< $@

main.dis: main.elf
	$(OBJDUMP) -d -S $< > $@

main.hex: main.bin
	python3 -c "import binascii; data = open('main.bin', 'rb').read(); [print(binascii.hexlify(data[i:i+4][::-1]).decode()) for i in range(0, len(data), 4)]" > $@

clean:
	rm -f *.o *.elf *.bin *.dis *.hex
