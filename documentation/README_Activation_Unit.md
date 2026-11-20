# IP Specification: Activation Unit IP

## 1. Overview
The Activation Unit IP accelerates non-linear activation functions element-wise for neural network inference. It supports run-time selection among ReLU, Sigmoid (PWL), and Tanh (PWL).

## 2. Block Diagram & Architecture
```
                           +----------------------+
                           |  activation_axi_regs | <--- AXI4-Lite Slave
                           +----------+-----------+
                                      | Config & Func Sel
                           +----------v-----------+
                           |activation_controller |
                           +----------+-----------+
                                      | Valid / Handshake
                 +--------------------+--------------------+
                 |                    |                    |
            +----v----+          +----v----+          +----v----+
            | relu.v  |          |sigmoid.v|          | tanh.v  |
            +----+----+          +----+----+          +----+----+
                 |                    |                    |
                 +-----------------+  |  +-----------------+
                                   |  |  |
                               +---v--v--v----------+
                               | function_selector  |
                               +----------+---------+
                                          |
                                  +-------v--------+
                                  | Output Buffer  | ---> DMA Readout Port
                                  +----------------+
```

## 3. Mathematical Approximation Details
- **ReLU**:
  $$f(x) = \max(0, x)$$
- **Sigmoid (Piecewise Linear)**:
  Zero multipliers required. Uses shift-and-add logic:
  - $|x| \ge 5.0 \implies 1.0$ ($0x0001\_0000$)
  - $2.375 \le |x| < 5.0 \implies 0.84375 + |x| \gg 5$
  - $1.0 \le |x| < 2.375 \implies 0.625 + |x| \gg 3$
  - $0 \le |x| < 1.0 \implies 0.5 + |x| \gg 2$
  - Symmetry: $f(-x) = 1.0 - f(x)$
- **Tanh (Piecewise Linear)**:
  - $|x| \ge 3.0 \implies 1.0$
  - $1.5 \le |x| < 3.0 \implies 0.8125 + |x| \gg 3$
  - $0.5 \le |x| < 1.5 \implies 0.25 + |x| \gg 1$
  - $0 \le |x| < 0.5 \implies |x|$
  - Symmetry: $f(-x) = -f(x)$

## 4. Register Map (Base: 0x0003_0100)
- `0x00`: `CTRL` [bit 0: start, bit 1: soft reset, bits 3:2: func_sel: 00=ReLU, 01=Sigmoid, 10=Tanh, 11=Bypass]
- `0x04`: `STATUS` [bit 0: done, bit 1: busy]
- `0x08`: `VEC_LEN`
- `0x0C`: `OUT_ADDR`
- `0x14`: `BUF_INDEX`
- `0x20`: `IN_DATA` (Direct write)
- `0x24`: `OUT_DATA` (Direct read)

## 5. Simulation Instructions
```bash
iverilog -o sim_act.vvp -g2005-sv ../rtl/activation_unit/*.v ../testbench/tb_activation.v
vvp sim_act.vvp
```
Expected output: `[PASS] ReLU functional test passed!`, `[PASS] Sigmoid(0.0) matches 0.5 exactly!`, and `[PASS] Tanh(0.0) matches 0.0 exactly!`.
