# SoC Architecture & Hardware Design Specification

## 1. System Overview

The **RISC-V Based SoC for Lightweight Neural Network Inference Acceleration** offloads linear layer operations ($Y = W \times X + B$) and non-linear activations to custom hardware accelerators, while maintaining software programmability via a 32-bit RISC-V processor core.

```
+-----------------------------------------------------------------------------------+
|                                  RISC-V SoC                                        |
|                                                                                   |
|  +--------------------+        +---------------------+       +-----------------+  |
|  |  RISC-V Processor  |        | 64 KB Instruction   |       | 64 KB Shared    |  |
|  |  Core (RV32I /     |        | Memory              |       | Data Memory     |  |
|  |  VeeR-EL2 Core)    |        | (0x0000_0000)       |       | (0x0001_0000)   |  |
|  +---------+----------+        +----------+----------+       +--------+--------+  |
|            | AXI4 Master                  | Fetch                     |           |
|            |                              |                           | AXI4      |
|  +---------v------------------------------v---------------------------v--------+  |
|  |                       System Interconnect & Bus Arbiter                    |  |
|  +----------------------------------------+------------------------------------+  |
|                                           | AXI4 Master (CPU)                     |
|                               +-----------v-----------+                           |
|                               | AXI4-to-AXI4-Lite     |                           |
|                               | Protocol Bridge       |                           |
|                               +-----------+-----------+                           |
|                                           | AXI4-Lite                             |
|                               +-----------v-----------+                           |
|                               | Central Decoder       |                           |
|                               +---+---+---+---+---+---+                           |
|                                   |   |   |   |   |   |                           |
|         +-------------------------+   |   |   |   |   +---------------------+     |
|         |                             |   |   |   |                         |     |
|  +------v------+              +-------v-+ | +-v---v----+              +-----v---+ |
|  |    UART     |              |  Timer  | | |   GPIO   |              |   DMA   | |
|  | (0x00020000)|              |(0x00020100| |(0x00020200|             |Controllr| |
|  +-------------+              +---------+ | +----------+              |(0x00030200|
|                                           |                           +----+----+ |
|                                           |                                |      |
|       +-----------------------------------+--------------------+           | DMA  |
|       |                                                        |           | AXI4 |
|  +----v--------------------+            +----------------------v--+        | Mstr |
|  | Matrix Multiplier IP    |  Streaming | Activation Unit IP      |        |      |
|  | (0x0003_0000)           +----------->| (0x0003_0100)           |        |      |
|  | Submodules:             |  Valid/Rdy | Submodules:             |        |      |
|  | - mac_unit.v            |            | - relu.v                |        |      |
|  | - input_buffer.v        |            | - sigmoid.v (PWL)       |        |      |
|  | - weight_buffer.v       |            | - tanh.v (PWL)          |        |      |
|  | - bias_adder.v          |            | - function_selector.v   |        |      |
|  | - matrix_controller.v   |            | - activation_controller |        |      |
|  | - output_buffer.v       |            | - activation_axi_regs.v |        |      |
|  | - matrix_axi_regs.v     |            | - activation_top.v      |        |      |
|  +------------^------------+            +------------+------------+        |      |
|               |                                      |                     |      |
|               +----------- DMA Fast Write Channels --+---------------------+      |
|               | (Loads Vector X, Weight W, Bias B)   | Readout Final Result       |
+---------------+--------------------------------------+----------------------------+
```

---

## 2. Bus Hierarchy: AXI4 & AXI4-Lite Integration

- **AXI4 Full Bus**:
  - Used for high-bandwidth memory accesses.
  - The RISC-V CPU masters AXI4 for loads and stores.
  - The DMA Controller masters AXI4 for bulk autonomous transfers to/from Data Memory.
- **AXI4-to-AXI4-Lite Bridge (`axi4_to_axilite_bridge.v`)**:
  - Transparently intercepts CPU transactions targeting peripherals and accelerators (`0x0002_0000` - `0x0003_FFFF`).
  - Decomposes bursts into single-beat Lite operations, manages `VALID/READY` handshaking, and forwards `BRESP`/`RRESP`.
- **AXI4-Lite Interconnect (`address_decoder.v`)**:
  - High-efficiency crossbar decoding 6 peripheral targets without complex arbitration overhead.

---

## 3. Custom IP 1: Matrix Multiplier Architecture

### Datapath & Mathematical Formulation
Performs matrix-vector multiplication with bias addition:
$$\mathbf{Y} = \mathbf{W} \times \mathbf{X} + \mathbf{B}$$
Where $W \in \mathbb{R}^{M \times K}$, $X \in \mathbb{R}^{K \times 1}$, $B \in \mathbb{R}^{M \times 1}$, and $Y \in \mathbb{R}^{M \times 1}$.

- **Fixed-Point Format**: Signed Q16.16 (32-bit: 1 sign bit, 15 integer bits, 16 fractional bits).
- **MAC Engine (`mac_unit.v`)**:
  - Multiplies 32-bit operands to produce a 64-bit product (Q32.32).
  - Rounds at bit 15 (`product + 0x8000`).
  - Shifts by 16 bits to extract Q16.16.
  - Saturated accumulation prevents integer wrap-around.
- **Internal Storage**:
  - `input_buffer.v`: Dual-port RAM for 256 vector elements.
  - `weight_buffer.v`: Dual-port RAM for 1024 matrix elements.
  - `bias_adder.v`: Internal bias memory and signed addition with overflow saturation.
  - `output_buffer.v`: Dual-port RAM holding output activations.
- **Controller FSM (`matrix_controller.v`)**:
  - Iterates through $M$ rows and $K$ inner accumulations.
  - Controls address sequencing and clears the accumulator at the start of each row.

---

## 4. Custom IP 2: Activation Unit Architecture

Applies element-wise non-linear activation functions directly to the outputs produced by the Matrix Multiplier:

1. **ReLU (`relu.v`)**:
   $$f(x) = \max(0, x)$$
   Non-negative values are passed through; negative values are clipped to zero.
2. **Sigmoid Approximation (`sigmoid.v`)**:
   Piecewise Linear Approximation of Nonlinearities (PLAN):
   - For $|x| \ge 5.0$: Output = $1.0$ ($0x0001\_0000$)
   - For $2.375 \le |x| < 5.0$: Output = $0.84375 + |x| \gg 5$
   - For $1.0 \le |x| < 2.375$: Output = $0.625 + |x| \gg 3$
   - For $0 \le |x| < 1.0$: Output = $0.5 + |x| \gg 2$
   - Negative symmetry: $\sigma(-x) = 1.0 - \sigma(x)$.
3. **Tanh Approximation (`tanh.v`)**:
   Piecewise Linear Approximation:
   - For $|x| \ge 3.0$: Output = $1.0$
   - For $1.5 \le |x| < 3.0$: Output = $0.8125 + |x| \gg 3$
   - For $0.5 \le |x| < 1.5$: Output = $0.25 + |x| \gg 1$
   - For $0 \le |x| < 0.5$: Output = $|x|$
   - Odd symmetry: $\tanh(-x) = -\tanh(x)$.

---

## 5. Custom IP 3: DMA Controller Architecture

Enables zero-CPU overhead data movement:
- **`dma_registers.v`**: AXI4-Lite slave configuration file.
- **`address_generator.v`**: Generates linear 32-bit addresses and decrements word transfer counts. Checks word alignment.
- **`dma_read_controller.v`**: AXI4 master read channel initiating memory bursts.
- **`dma_write_controller.v`**: AXI4 master write channel writing back results.
- **`dma_transfer_engine.v`**: Routes memory words directly into the Matrix Multiplier buffers ($X$, $W$, $B$) and Activation Unit output buffer.
