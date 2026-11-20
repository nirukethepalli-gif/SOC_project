# IP Specification: Matrix Multiplier IP

## 1. Overview
The Matrix Multiplier IP accelerates matrix-vector multiplication with bias addition ($Y = W \times X + B$) using a Multiply-Accumulate (MAC) datapath operating on signed Q16.16 fixed-point numbers.

## 2. Block Diagram & Internal Architecture
```
                        +----------------------+
                        |   matrix_axi_regs    | <--- AXI4-Lite Slave
                        +----------+-----------+
                                   | Control & Dimensions
                        +----------v-----------+
                        |  matrix_controller   |
                        +---+------+-------+---+
                            |      |       |
              +-------------+      |       +-------------+
              |                    |                     |
     +--------v-------+   +--------v-------+   +---------v------+
     |  input_buffer  |   | weight_buffer  |   |   bias_adder   |
     |   (Vector X)   |   |   (Matrix W)   |   |   (Vector B)   |
     +--------+-------+   +--------+-------+   +---------+------+
              |                    |                     |
              +----------+  +------+                     |
                         |  |                            |
                     +---v--v----+                       |
                     |  mac_unit | (Q16.16 MAC)          |
                     +-----+-----+                       |
                           | Dot-product                 |
                           +-------------> + <-----------+
                                           |
                                   +-------v-------+
                                   | output_buffer | ---> Streaming Valid/Ready
                                   +---------------+      (to Activation Unit)
```

## 3. Submodule Descriptions
1. **`mac_unit.v`**: Signed 32-bit Q16.16 multiplier and 48-bit accumulator with saturation to $+32767.9999$ and $-32768.0000$.
2. **`input_buffer.v`**: Dual-port synchronous RAM holding up to 256 vector elements.
3. **`weight_buffer.v`**: Dual-port synchronous RAM holding up to 1024 matrix elements.
4. **`bias_adder.v`**: Dedicated bias storage RAM and signed adder with overflow clamping.
5. **`matrix_controller.v`**: FSM that iterates over $M$ rows and $K$ inner dimensions, managing address generation, accumulator clearing, and streaming handshakes.
6. **`output_buffer.v`**: Dual-port synchronous RAM holding the computed raw linear layer.
7. **`matrix_axi_regs.v`**: AXI4-Lite slave interface managing control, status, and dimensions.
8. **`matrix_multiplier_top.v`**: Top-level module integrating all submodules.

## 4. Signal Descriptions & Ports
- `clk`, `rst_n`: System clock and active-low reset.
- `s_axi_*`: AXI4-Lite slave interface (0x0003_0000).
- `dma_in_*`, `dma_w_*`, `dma_bias_*`: High-throughput buffer write ports from DMA.
- `stream_act_data [31:0]`, `stream_act_valid`, `stream_act_ready`: Streaming handshake to Activation Unit.
- `busy`, `done`, `irq`: Status and interrupt signals.

## 5. Register Map (Base: 0x0003_0000)
- `0x00`: `CTRL` [bit 0: start, bit 1: soft reset]
- `0x04`: `STATUS` [bit 0: done, bit 1: busy, bit 2: overflow]
- `0x08`: `DIM_M_N_K` [bits 7:0: K, bits 15:8: N, bits 23:16: M]
- `0x0C`: `BASE_IN_ADDR`
- `0x10`: `BASE_OUT_ADDR`
- `0x14`: `BUF_INDEX`
- `0x20` - `0x2C`: Direct Buffer Data Registers

## 6. Simulation Instructions
Run standalone testbench in ModelSim / Icarus Verilog:
```bash
iverilog -o sim_mat.vvp -g2005-sv ../rtl/matrix_multiplier/*.v ../testbench/tb_matrix_multiplier.v
vvp sim_mat.vvp
```
Expected output: `[PASS] Y[0] matches expected Q16.16 value!` and `[PASS] Y[1] matches expected Q16.16 value!`.
