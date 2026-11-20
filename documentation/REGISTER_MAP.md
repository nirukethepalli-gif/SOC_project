# Complete Register Map Documentation

## 1. Matrix Multiplier IP (Base: `0x0003_0000`)

| Offset | Register Name | Access | Reset Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | **CTRL** | R/W | `0x0000_0000` | **Control Register**<br>- Bit 0: `START` (Pulse 1 to start linear computation; auto-clearing)<br>- Bit 1: `SOFT_RESET` (Resets FSM and internal accumulators)<br>- Bits 31:2: Reserved |
| `0x04` | **STATUS** | R | `0x0000_0000` | **Status Register**<br>- Bit 0: `DONE` (1 when calculation completes)<br>- Bit 1: `BUSY` (1 while MAC calculation is active)<br>- Bit 2: `OVERFLOW` (1 if accumulator or bias adder saturated)<br>- Bits 31:3: Reserved |
| `0x08` | **DIM_M_N_K** | R/W | `0x0002_0102` | **Matrix Dimensions Register**<br>- Bits 7:0: `DIM_K` (Inner dot-product dimension / length of vector X)<br>- Bits 15:8: `DIM_N` (Columns of output / batch dimension; default 1)<br>- Bits 23:16: `DIM_M` (Number of output neurons / rows of weight matrix)<br>- Bits 31:24: Reserved |
| `0x0C` | **BASE_IN_ADDR** | R/W | `0x0001_0000` | Base address of input buffer in system memory (for reference) |
| `0x10` | **BASE_OUT_ADDR** | R/W | `0x0001_0400` | Base address of output buffer in system memory (for reference) |
| `0x14` | **BUF_INDEX** | R/W | `0x0000_0000` | Internal RAM word index for direct CPU memory-mapped buffer loading |
| `0x20` | **IN_BUF_DATA** | W | `0x0000_0000` | Direct write to Input Buffer X at current `BUF_INDEX` (auto-increments index) |
| `0x24` | **W_BUF_DATA** | W | `0x0000_0000` | Direct write to Weight Buffer W at current `BUF_INDEX` (auto-increments index) |
| `0x28` | **BIAS_BUF_DATA** | W | `0x0000_0000` | Direct write to Bias Buffer B at current `BUF_INDEX` (auto-increments index) |
| `0x2C` | **OUT_BUF_DATA** | R | `0x0000_0000` | Direct read from Output Buffer Y at current `BUF_INDEX` |

---

## 2. Activation Unit IP (Base: `0x0003_0100`)

| Offset | Register Name | Access | Reset Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | **CTRL** | R/W | `0x0000_0000` | **Control Register**<br>- Bit 0: `START` (Pulse 1 to arm/start activation pass)<br>- Bit 1: `SOFT_RESET`<br>- Bits 3:2: `FUNC_SEL`<br>  - `2'b00`: ReLU ($f(x) = \max(0, x)$)<br>  - `2'b01`: Sigmoid PWL ($f(x) \approx \frac{1}{1+e^{-x}}$)<br>  - `2'b10`: Tanh PWL ($f(x) \approx \tanh(x)$)<br>  - `2'b11`: Bypass (Linear pass-through)<br>- Bits 31:4: Reserved |
| `0x04` | **STATUS** | R | `0x0000_0000` | **Status Register**<br>- Bit 0: `DONE` (1 when vector activation completes)<br>- Bit 1: `BUSY` (1 while processing elements)<br>- Bits 31:2: Reserved |
| `0x08` | **VEC_LEN** | R/W | `0x0000_0002` | Number of elements in the vector to activate |
| `0x0C` | **OUT_ADDR** | R/W | `0x0001_0400` | Destination address in Data Memory |
| `0x14` | **BUF_INDEX** | R/W | `0x0000_0000` | Buffer index for direct read/write |
| `0x20` | **IN_DATA** | W | `0x0000_0000` | Direct input push for manual activation testing |
| `0x24` | **OUT_DATA** | R | `0x0000_0000` | Direct read of activated output element |

---

## 3. DMA Controller IP (Base: `0x0003_0200`)

| Offset | Register Name | Access | Reset Value | Description |
| :--- | :--- | :--- | :--- | :--- |
| `0x00` | **CTRL** | R/W | `0x0000_0000` | **Control Register**<br>- Bit 0: `START` (Pulse 1 to initiate configured transfer)<br>- Bit 1: `SOFT_RESET`<br>- Bit 2: `DIRECTION`<br>  - `0`: Memory-to-Accelerator Transfer<br>  - `1`: Accelerator-to-Memory Transfer<br>- Bits 4:3: `ACC_TARGET`<br>  - `2'b00`: Matrix Multiplier Input Buffer X<br>  - `2'b01`: Matrix Multiplier Weight Buffer W<br>  - `2'b10`: Matrix Multiplier Bias Buffer B<br>  - `2'b11`: Activation Unit Output Buffer<br>- Bits 31:5: Reserved |
| `0x04` | **STATUS** | R | `0x0000_0000` | **Status Register**<br>- Bit 0: `DONE` (1 when DMA transfer completes)<br>- Bit 1: `BUSY` (1 while transfer is actively running)<br>- Bit 2: `ERROR` (1 on misaligned address or bus error)<br>- Bits 31:3: Reserved |
| `0x08` | **SRC_ADDR** | R/W | `0x0001_0000` | Source byte base address (must be 32-bit aligned) |
| `0x0C` | **DST_ADDR** | R/W | `0x0001_0400` | Destination byte base address (must be 32-bit aligned) |
| `0x10` | **BURST_LEN** | R/W | `0x0000_0004` | Transfer length (number of 32-bit words) |
