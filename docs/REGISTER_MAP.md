# SoC System & Custom IP Register Map Specification

**Project:** RISC-V VeeR-EL2 Based Neural Network Inference Acceleration SoC  
**Target Simulator:** Synopsys VCS  
**Protocol:** AXI4-Lite (32-bit Address, 32-bit Data)

---

## 1. Top-Level Memory & Peripheral Map

| Peripheral Name | Base Address | End Address | Size | Interconnect Slave Index | Access Type |
|---|---|---|---|:---:|:---:|
| **Instruction SRAM (IMEM)** | `0x0000_0000` | `0x0000_7FFF` | 32 KB | `Slave 0` | Dual-Port R/W |
| **Data SRAM (DMEM)** | `0x1000_0000` | `0x1000_7FFF` | 32 KB | `Slave 1` | Single-Port R/W |
| **UART 16550-compatible** | `0x8000_0000` | `0x8000_0FFF` | 4 KB | `Slave 2` | R/W |
| **Real-Time Timer (mtime)** | `0x8000_1000` | `0x8000_1FFF` | 4 KB | `Slave 3` | R/W |
| **General-Purpose IO (GPIO)**| `0x8000_2000` | `0x8000_2FFF` | 4 KB | `Slave 4` | R/W |
| **Custom IP 3: DMA Controller** | `0x8000_3000` | `0x8000_3FFF` | 4 KB | `Slave 5` | R/W |
| **Custom IP 1: Matrix Multiplier** | `0x8000_4000` | `0x8000_4FFF` | 4 KB | `Slave 6` | R/W |
| **Custom IP 2: Activation Unit** | `0x8000_5000` | `0x8000_5FFF` | 4 KB | `Slave 7` | R/W |
| **Error Slave (DECERR)** | *Unmapped Addresses* | — | — | `Slave 8` | Read/Write Error |

---

## 2. Custom IP 1: Matrix Multiplier Register Map (Base: `0x8000_4000`)

| Offset | Register Name | Access | Reset Value | Description |
|:---:|:---|:---:|:---:|:---|
| `0x00` | `MAT_CTRL` | RW | `0x0000_0000` | Control register.<br>• Bit 0: `START` (Write 1 to launch matrix multiplication)<br>• Bit 1: `SOFT_RESET` (Write 1 to clear datapath and FIFOs) |
| `0x04` | `MAT_STATUS` | RO | `0x0000_0000` | Status register.<br>• Bit 0: `DONE` (Asserted upon completion)<br>• Bit 1: `BUSY` (Accelerator executing MAC operations)<br>• Bit 2: `OVERFLOW` (Fixed-point saturation occurred) |
| `0x08` | `MAT_DIM_MNK` | RW | `0x0002_0102` | Matrix dimension configuration:<br>• Bits [7:0]: Dimension $K$ (Inner accumulation size)<br>• Bits [15:8]: Dimension $N$ (Output vector columns, default 1)<br>• Bits [23:16]: Dimension $M$ (Weight matrix rows) |
| `0x0C` | `MAT_BASE_IN_ADDR` | RW | `0x1000_0000` | Memory base address for DMA input vector transfers. |
| `0x10` | `MAT_BASE_OUT_ADDR` | RW | `0x1000_0400` | Memory base address for storing computed output vectors. |
| `0x14` | `MAT_BUF_INDEX` | RW | `0x0000_0000` | Buffer auto-increment indexing register.<br>• Bits [9:0]: Buffer element pointer (auto-increments on data write/read). |
| `0x18` | `MAT_IN_DATA` | WO | `0x0000_0000` | Input Vector Buffer access port (Q16.16 signed format). Auto-increments `MAT_BUF_INDEX`. |
| `0x1C` | `MAT_W_DATA` | WO | `0x0000_0000` | Weight Matrix Buffer access port (Q16.16 signed format). Auto-increments `MAT_BUF_INDEX`. |
| `0x20` | `MAT_BIAS_DATA` | WO | `0x0000_0000` | Bias Vector Buffer access port (Q16.16 signed format). Auto-increments `MAT_BUF_INDEX`. |
| `0x24` | `MAT_OUT_DATA` | RO | `0x0000_0000` | Raw MAC Output Buffer access port (Q16.16 signed format). Auto-increments `MAT_BUF_INDEX`. |

---

## 3. Custom IP 2: Activation Unit Register Map (Base: `0x8000_5000`)

| Offset | Register Name | Access | Reset Value | Description |
|:---:|:---|:---:|:---:|:---|
| `0x00` | `ACT_CTRL` | RW | `0x0000_0000` | Control and Function Selection register.<br>• Bit 0: `START` (Write 1 to start activation)<br>• Bit 1: `SOFT_RESET` (Write 1 to reset engine)<br>• Bits [3:2]: `FUNC_SEL` (Function selection):<br>&nbsp;&nbsp;- `00`: **ReLU** ($f(x) = \max(0, x)$)<br>&nbsp;&nbsp;- `01`: **Sigmoid PWL** ($f(x) = \frac{1}{1 + e^{-x}}$)<br>&nbsp;&nbsp;- `10`: **Tanh PWL** ($f(x) = \tanh(x)$) |
| `0x04` | `ACT_STATUS` | RO | `0x0000_0000` | Status register.<br>• Bit 0: `DONE` (Asserted when all vector elements activated)<br>• Bit 1: `BUSY` (Activation unit processing) |
| `0x08` | `ACT_VEC_LEN` | RW | `0x0000_0002` | Vector length (number of elements to activate, 1 to 256). |
| `0x0C` | `ACT_OUT_ADDR` | RW | `0x1000_0400` | Destination address for DMA write-back to memory. |
| `0x10` | `ACT_BUF_INDEX` | RW | `0x0000_0000` | Auto-increment buffer index pointer. |
| `0x14` | `ACT_IN_DATA` | WO | `0x0000_0000` | Activation input data register (Q16.16). Auto-increments buffer index. |
| `0x18` | `ACT_OUT_DATA` | RO | `0x0000_0000` | Final activated result register (Q16.16). Auto-increments buffer index. |

---

## 4. Custom IP 3: DMA Controller Register Map (Base: `0x8000_3000`)

| Offset | Register Name | Access | Reset Value | Description |
|:---:|:---|:---:|:---:|:---|
| `0x00` | `DMA_CTRL` | RW | `0x0000_0000` | Control register.<br>• Bit 0: `START` (Write 1 to trigger transfer)<br>• Bit 1: `SOFT_RESET` (Write 1 to reset transfer engine)<br>• Bit 2: `DIRECTION` (0: Memory $\to$ Accelerator, 1: Accelerator $\to$ Memory)<br>• Bits [4:3]: `TARGET_BUFFER`:<br>&nbsp;&nbsp;- `00`: Matrix Input Buffer<br>&nbsp;&nbsp;- `01`: Matrix Weight Buffer<br>&nbsp;&nbsp;- `10`: Matrix Bias Buffer<br>&nbsp;&nbsp;- `11`: Activation Unit Output Buffer |
| `0x04` | `DMA_STATUS` | RO | `0x0000_0000` | Status register.<br>• Bit 0: `DONE` (Asserted upon completion of burst)<br>• Bit 1: `BUSY` (DMA burst in flight)<br>• Bit 2: `ERROR` (Address unaligned or bus error) |
| `0x08` | `DMA_SRC_ADDR` | RW | `0x1000_0000` | Source 32-bit linear memory byte address. |
| `0x0C` | `DMA_DST_ADDR` | RW | `0x1000_0400` | Destination 32-bit linear memory byte address. |
| `0x10` | `DMA_BURST_LEN`| RW | `0x0000_0004` | Number of 32-bit words to transfer per burst (1 to 1024). |

---

## 5. Baseline Peripherals Register Map

### UART (Base: `0x8000_0000`)
- `0x00`: `TXDATA` (Write), `RXDATA` (Read)
- `0x04`: `STATUS` (Bit 0: TX Full, Bit 1: TX Empty, Bit 2: RX Empty, Bit 3: RX Full)
- `0x08`: `BAUDDIV` (Baud rate divisor, default 434 for 115200 baud @ 50 MHz)
- `0x0C`: `CTRL` (Bit 0: TX Enable, Bit 1: RX Enable, Bit 2: TX IRQ En, Bit 3: RX IRQ En)

### Timer (Base: `0x8000_1000`)
- `0x00`: `MTIME_LO` (Low 32 bits of 64-bit cycle counter)
- `0x04`: `MTIME_HI` (High 32 bits of 64-bit cycle counter)
- `0x08`: `MTIMECMP_LO` (Low 32 bits of comparison register)
- `0x0C`: `MTIMECMP_HI` (High 32 bits of comparison register)
- `0x10`: `CTRL` (Bit 0: Timer Enable, Bit 1: IRQ Enable)

### GPIO (Base: `0x8000_2000`)
- `0x00`: `DATA_IN` (Read input pins)
- `0x04`: `DATA_OUT` (Drive output pins)
- `0x08`: `DIR` (1 = Output, 0 = Input)
