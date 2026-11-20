# IP Specification: DMA Controller IP

## 1. Overview
The DMA Controller IP autonomously moves input vectors, weight matrices, and bias values from Data Memory to Matrix Multiplier buffers, and moves activated inference results back to Data Memory without CPU cycle-by-cycle overhead.

## 2. Block Diagram & Architecture
```
             +--------------------+
             |   dma_registers    | <--- AXI4-Lite Slave (CPU Config)
             +---------+----------+
                       | Start & Config
             +---------v----------+
             |      dma_fsm       |
             +---+-----+------+---+
                 |     |      |
                 |     |      +---------------------+
                 |     |                            |
       +---------v--+  +----v--------------------+  +---v---------------------+
       |address_gen |       |dma_read_controller |      |dma_write_controller |
       +------------+       +---------+----------+      +----------+----------+
                                      | AXI4 Read                  | AXI4 Write
                                      | Channel                    | Channel
                                      |                            |
                            +---------v----------------------------v----------+
                            |               dma_transfer_engine               |
                            +--------------------+----------------------------+
                                                 |
                       +-------------------------+-------------------------+
                       |                                                   |
              +--------v-------+                                  +--------v-------+
              | Matrix Buffers |                                  | Activation Out |
              |  (X, W, B)     |                                  | (Read Result)  |
              +----------------+                                  +----------------+
```

## 3. Submodule Descriptions
1. **`dma_registers.v`**: AXI4-Lite slave register interface for CPU configuration.
2. **`dma_fsm.v`**: Central FSM sequencing read burst, transfer staging, address incrementing, and completion.
3. **`address_generator.v`**: Tracks 32-bit linear memory addresses, checks word alignment, and decrements word transfer counters.
4. **`dma_read_controller.v`**: AXI4 Master interface executing memory read transactions.
5. **`dma_write_controller.v`**: AXI4 Master interface executing memory write transactions.
6. **`dma_transfer_engine.v`**: Cross-routes data between memory channels and accelerator buffers.
7. **`dma_top.v`**: Top module integrating all components.

## 4. Register Map (Base: 0x0003_0200)
- `0x00`: `CTRL` [bit 0: start, bit 1: soft reset, bit 2: direction (0=Mem->Acc, 1=Acc->Mem), bits 4:3: target (00=Input, 01=Weight, 10=Bias, 11=Act Out)]
- `0x04`: `STATUS` [bit 0: done, bit 1: busy, bit 2: error]
- `0x08`: `SRC_ADDR`
- `0x0C`: `DST_ADDR`
- `0x10`: `BURST_LEN` (Words)

## 5. Simulation Instructions
```bash
iverilog -o sim_dma.vvp -g2005-sv ../rtl/dma_controller/*.v ../testbench/tb_dma.v
vvp sim_dma.vvp
```
Expected output: `[PASS] DMA Mem->Acc transfer completed successfully!` and `[PASS] Accelerator result correctly transferred to RAM!`.
