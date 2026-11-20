# System-on-Chip Unified Address Map

## Project: RISC-V Based SoC for Lightweight Neural Network Inference Acceleration

All memory blocks, peripheral registers, and custom hardware accelerator IP register files are mapped into a unified 32-bit flat address space.

---

### Central Memory Map Table

| Peripheral / Module | Base Address | End Address | Size | Bus Protocol | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Instruction Memory** | `0x0000_0000` | `0x0000_FFFF` | 64 KB | Dedicated CPU Fetch / AXI | Stores compiled RISC-V program code |
| **Data Memory** | `0x0001_0000` | `0x0001_FFFF` | 64 KB | AXI4 Full (Shared) | Holds Input Vector X, Weight Matrix W, Bias B, Output Y |
| **UART** | `0x0002_0000` | `0x0002_00FF` | 256 B | AXI4-Lite Slave | Serial communication & inference reporting |
| **Timer** | `0x0002_0100` | `0x0002_01FF` | 256 B | AXI4-Lite Slave | System tick, profiling, and interval interrupts |
| **GPIO** | `0x0002_0200` | `0x0002_02FF` | 256 B | AXI4-Lite Slave | General purpose I/O pins (LEDs, triggers) |
| **Matrix Multiplier** | `0x0003_0000` | `0x0003_00FF` | 256 B | AXI4-Lite Slave | Custom IP 1: Hardware-accelerated MAC engine ($Y = W \times X + B$) |
| **Activation Unit** | `0x0003_0100` | `0x0003_01FF` | 256 B | AXI4-Lite Slave | Custom IP 2: Nonlinear activations (ReLU, Sigmoid, Tanh) |
| **DMA Controller** | `0x0003_0200` | `0x0003_02FF` | 256 B | AXI4-Lite Slave | Custom IP 3: Autonomous data movement between memory & accelerators |

---

### Data Memory Layout for Inference Workloads

Within Data Memory (`0x0001_0000` - `0x0001_FFFF`):

| Data Array | Base Offset | Absolute Address | Description |
| :--- | :--- | :--- | :--- |
| **Input Vector X** | `+0x0000` | `0x0001_0000` | Input feature vector elements in Q16.16 format |
| **Weight Matrix W** | `+0x0020` | `0x0001_0020` | Row-major weight matrix elements in Q16.16 format |
| **Bias Vector B** | `+0x0040` | `0x0001_0040` | Neuron bias values in Q16.16 format |
| **Final Output Vector Y** | `+0x0400` | `0x0001_0400` | Output activations written back by DMA after inference |
