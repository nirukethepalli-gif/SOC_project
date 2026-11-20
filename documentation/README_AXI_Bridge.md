# IP Specification: AXI4 to AXI4-Lite Protocol Bridge

## 1. Overview
The AXI4-to-AXI4-Lite Bridge converts full AXI4 transactions from the RISC-V processor core into simple single-beat AXI4-Lite slave transactions. It decomposes multi-beat bursts into individual Lite accesses with automatic address increments, handles byte strobes, and propagates response statuses.

## 2. Architecture & Burst Decomposition
- **Full AXI4 Slave Channels**:
  - `AW`: Write Address (`awid`, `awaddr`, `awlen`, `awsize`, `awburst`, `awvalid`, `awready`)
  - `W`: Write Data (`wdata`, `wstrb`, `wlast`, `wvalid`, `wready`)
  - `B`: Write Response (`bid`, `bresp`, `bvalid`, `bready`)
  - `AR`: Read Address (`arid`, `araddr`, `arlen`, `arsize`, `arburst`, `arvalid`, `arready`)
  - `R`: Read Data (`rid`, `rdata`, `rresp`, `rlast`, `rvalid`, `rready`)
- **AXI4-Lite Master Channels**:
  - Single-beat addresses and data without burst/ID fields.

## 3. Burst Conversion Logic
- **Write Burst**: The bridge accepts an AXI4 write burst of length $N = \text{awlen} + 1$. For each beat:
  - Generates an AXI4-Lite write request to `addr + (beat * 4)`.
  - Waits for `m_axil_bvalid`.
  - When all beats are committed, returns a single AXI4 write response (`s_axi_bvalid`).
- **Read Burst**: For an AXI4 read burst of length $N = \text{arlen} + 1$:
  - Issues $N$ sequential AXI4-Lite reads to `addr + (beat * 4)`.
  - Forwards each returned word to `s_axi_rdata`.
  - Asserts `s_axi_rlast` on the final beat.

## 4. Simulation Instructions
```bash
iverilog -o sim_bridge.vvp -g2005-sv ../rtl/bridge/*.v ../testbench/tb_axi4_to_axilite_bridge.v
vvp sim_bridge.vvp
```
Expected output: `[PASS] Single AXI4 transfer correctly converted to AXI4-Lite!` and `[PASS] Burst write response received!`.
