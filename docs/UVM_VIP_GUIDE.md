# Universal Verification Methodology (UVM) Verification IP (VIP) Suite

**Project:** RISC-V Based SoC for Lightweight Neural Network Inference Acceleration  
**Methodology:** IEEE 1800.2 Universal Verification Methodology (UVM 1.2)  
**Target Simulator:** Synopsys VCS (`vcs -full64 -sverilog -ntb_opts uvm`)

---

## 1. Overview & Architecture

To achieve industry-standard verification coverage for the custom hardware accelerators, a modular **UVM Verification IP (VIP)** suite has been developed. The suite contains three reusable VIPs and three specialized UVM test environments:

```text
                               +---------------------------------------------------+
                               |              UVM Test / Sequences                 |
                               +---------------------------------------------------+
                                                         |
                               +---------------------------------------------------+
                               |                 UVM Environment                   |
                               |  +--------------------+   +--------------------+  |
                               |  |  AXI4-Lite Master  |   |    Stream / Memory |  |
                               |  |      UVM VIP       |   |       UVM VIP      |  |
                               |  +--------------------+   +--------------------+  |
                               |            |                        |             |
                               |  +---------------------------------------------+  |
                               |  |       Mathematical Golden Scoreboard        |  |
                               |  +---------------------------------------------+  |
                               +---------------------------------------------------+
                                                         |
                                                         v
                               +---------------------------------------------------+
                               |          Custom Hardware IP Under Test (DUT)       |
                               |  (Matrix Multiplier / Activation / DMA Controller)|
                               +---------------------------------------------------+
```

---

## 2. Verification IPs (VIPs) Implemented

### VIP 1: AXI4-Lite Master VIP (`vip/axilite_vip/`)
- **Interface:** [`axilite_if.sv`](../verification/uvm/vip/axilite_vip/axilite_if.sv) with synchronous clocking blocks, modports, and SVA assertions checking `awvalid`, `wvalid`, and `arvalid` stability.
- **Package:** [`axilite_pkg.sv`](../verification/uvm/vip/axilite_vip/axilite_pkg.sv)
  - `axilite_seq_item`: Encapsulates 32-bit address, 32-bit data, 4-bit byte strobe, transaction kind (`READ`/`WRITE`), and response code (`OKAY`, `SLVERR`, `DECERR`).
  - `axilite_driver`: Drives standard 2-phase AXI4-Lite read/write address and data handshakes with configurable wait states.
  - `axilite_monitor`: Passively samples valid/ready transactions on clocking edges and broadcasts verified transactions via `uvm_analysis_port`.
  - `axilite_agent`: Encapsulates driver, monitor, and sequencer with `UVM_ACTIVE`/`UVM_PASSIVE` configuration.
  - `axilite_base_seq`: Reusable sequence library providing `write_reg()`, `read_reg()`, and `poll_reg()` tasks.

### VIP 2: Accelerator Streaming VIP (`vip/stream_vip/`)
- **Interface:** [`stream_if.sv`](../verification/uvm/vip/stream_vip/stream_if.sv) modeling the custom high-bandwidth vector port (`stream_act_data`, `stream_act_valid`, `stream_act_ready`).
- **Package:** [`stream_pkg.sv`](../verification/uvm/vip/stream_vip/stream_pkg.sv)
  - `stream_driver`: Operates either as `STREAM_SRC` (drives valid/data with randomized delays) or `STREAM_SNK` (drives ready with randomized backpressure bubbles to stress DUT FIFOs).
  - `stream_monitor`: Captures transferred words and sends them to the scoreboard.

### VIP 3: AXI4 Memory Slave VIP (`vip/axi_mem_slave_vip/`)
- **Interface:** [`axi_mem_slave_if.sv`](../verification/uvm/vip/axi_mem_slave_vip/axi_mem_slave_if.sv) connecting to the DMA Controller's AXI4 Master memory interface.
- **Package:** [`axi_mem_slave_pkg.sv`](../verification/uvm/vip/axi_mem_slave_vip/axi_mem_slave_pkg.sv)
  - `axi_mem_slave_driver`: High-speed behavioral SRAM responder with sparse associative memory (`bit [31:0] mem[bit [31:0]]`). Automatically responds to multi-beat AXI4 read bursts (`rdata`, `rlast`, `rvalid`) and captures write bursts (`wdata`, `bvalid`).

---

## 3. Custom IP UVM Environments & Scoreboards

### 1. Matrix Multiplier UVM Environment (`matrix_mult_env`)
- **File:** [`envs/matrix_mult_env.sv`](../verification/uvm/envs/matrix_mult_env.sv)
- **Scoreboard:** Contains a 64-bit mathematical golden model for $Y = W \times X + B$ in signed Q16.16 fixed-point arithmetic with saturation clamping (`0x7FFF_FFFF` and `0x8000_0000`).
- **Checkpoints:** Compares actual words streaming out of the DUT against predicted golden words.

### 2. Activation Unit UVM Environment (`activation_env`)
- **File:** [`envs/activation_env.sv`](../verification/uvm/envs/activation_env.sv)
- **Scoreboard:** Contains analytical models for:
  - **ReLU:** $f(x) = \max(0, x)$
  - **Sigmoid PWL:** 8-segment synthesizable linear interpolation
  - **Tanh PWL:** 8-segment symmetric piecewise linear curve
- **Checkpoints:** Compares readback outputs from `ACT_REG_OUT_DATA` against expected values across positive, negative, and zero inputs.

### 3. DMA Controller UVM Environment (`dma_env`)
- **File:** [`envs/dma_env.sv`](../verification/uvm/envs/dma_env.sv)
- **Scoreboard:** Verifies data integrity across memory-to-accelerator and accelerator-to-memory burst transfers.

---

## 4. How to Compile and Run UVM VIPs in Synopsys VCS

Navigate to the UVM simulation directory:
```bash
cd NN_Accelerator_SoC/verification/uvm/sim
```

### Run Matrix Multiplier UVM Test:
```bash
make -f Makefile.uvm test_mm
```
*Expected VCS Log:*
```text
UVM_INFO @ 0: reporter [RNTST] Running test matrix_mult_2x2_test...
UVM_INFO @ 45000: uvm_test_top.env.scoreboard [SCB/MM/PASS] MATCH: Out=0x0002C000 Expected=0x0002C000
UVM_INFO @ 55000: uvm_test_top.env.scoreboard [SCB/MM/PASS] MATCH: Out=0xFFFD8000 Expected=0xFFFD8000
--- UVM Report Summary ---
** Report counts by severity
UVM_INFO : 8
UVM_WARNING : 0
UVM_ERROR : 0
UVM_FATAL : 0
```

### Run Activation Unit UVM Test:
```bash
make -f Makefile.uvm test_act
```
*Expected VCS Log:*
```text
UVM_INFO @ 0: reporter [RNTST] Running test activation_all_func_test...
UVM_INFO @ 35000: uvm_test_top.env.scoreboard [SCB/ACT/PASS] [ReLU] In=0x0002C000 Act=0x0002C000 Exp=0x0002C000 - MATCH
UVM_INFO @ 35000: uvm_test_top.env.scoreboard [SCB/ACT/PASS] [ReLU] In=0xFFFD8000 Act=0x00000000 Exp=0x00000000 - MATCH
UVM_INFO @ 65000: uvm_test_top.env.scoreboard [SCB/ACT/PASS] [Sigmoid] In=0x00000000 Act=0x00008000 Exp=0x00008000 - MATCH
UVM_INFO @ 95000: uvm_test_top.env.scoreboard [SCB/ACT/PASS] [Tanh] In=0x00000000 Act=0x00000000 Exp=0x00000000 - MATCH
--- UVM Report Summary: 0 Errors ---
```

### Run DMA Controller UVM Test:
```bash
make -f Makefile.uvm test_dma
```

### Run Full UVM VIP Suite:
```bash
make -f Makefile.uvm all_uvm
```
