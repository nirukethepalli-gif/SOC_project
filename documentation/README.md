# RISC-V Based SoC for Lightweight Neural Network Inference Acceleration

## Final Year Honours Hardware Design Project

---

## 1. Project Overview
This repository contains the complete synthesizable Verilog RTL, AXI bus infrastructure, peripheral subsystems, verification testbenches, and documentation for a **RISC-V Based System-on-Chip (SoC) tailored for Lightweight Neural Network Inference Acceleration**.

The SoC offloads computationally heavy linear layer multiply-accumulate operations ($Y = W \times X + B$) and non-linear activations (ReLU, Sigmoid, Tanh) to three custom hardware accelerator IPs:
1. **Matrix Multiplier IP**: Configurable Q16.16 fixed-point matrix-vector MAC engine.
2. **Activation Unit IP**: Hardware accelerator supporting ReLU, Sigmoid (PWL), and Tanh (PWL).
3. **DMA Controller IP**: Autonomous memory-to-accelerator and accelerator-to-memory data mover.

The design features an **AXI4 system bus**, an **AXI4-to-AXI4-Lite Bridge**, a centralized **Address Decoder Crossbar**, 64 KB Instruction Memory, 64 KB Shared Data Memory, UART, Timer, GPIO, and an RV32 processor core (compatible with Western Digital VeeR-EL2).

---

## 2. Directory Structure

```
NN_Accelerator_SoC/
├── rtl/
│   ├── bridge/
│   │   └── axi4_to_axilite_bridge.v     # AXI4 to AXI4-Lite Protocol Converter Bridge
│   ├── interconnect/
│   │   └── address_decoder.v            # Central AXI4-Lite Address Decoder Crossbar
│   ├── matrix_multiplier/               # Custom IP 1: Matrix Multiplier
│   │   ├── mac_unit.v                   # Signed Q16.16 Multiply-Accumulate Engine
│   │   ├── input_buffer.v               # Vector X Dual-Port RAM Buffer
│   │   ├── weight_buffer.v              # Matrix W Dual-Port RAM Buffer
│   │   ├── bias_adder.v                 # Vector B RAM & Signed Saturation Adder
│   │   ├── output_buffer.v              # Output Y Dual-Port RAM Buffer
│   │   ├── matrix_controller.v          # Matrix Sequencing FSM Controller
│   │   ├── matrix_axi_regs.v            # AXI4-Lite Slave Register Interface
│   │   └── matrix_multiplier_top.v      # Matrix Multiplier Top Module
│   ├── activation_unit/                 # Custom IP 2: Activation Unit
│   │   ├── relu.v                       # Rectified Linear Unit (Exact)
│   │   ├── sigmoid.v                    # Sigmoid Piecewise Linear Approximation
│   │   ├── tanh.v                       # Tanh Piecewise Linear Approximation
│   │   ├── function_selector.v          # Function Multiplexer
│   │   ├── activation_controller.v      # Activation Vector Controller FSM
│   │   ├── activation_axi_regs.v        # AXI4-Lite Slave Register Interface
│   │   └── activation_top.v             # Activation Unit Top Module
│   ├── dma_controller/                  # Custom IP 3: DMA Controller
│   │   ├── dma_registers.v              # AXI4-Lite Slave Register Interface
│   │   ├── dma_fsm.v                    # DMA Master Control FSM
│   │   ├── address_generator.v          # Linear Address Stepper & Word Counter
│   │   ├── dma_read_controller.v        # AXI4 Master Read Channel
│   │   ├── dma_write_controller.v       # AXI4 Master Write Channel
│   │   ├── dma_transfer_engine.v        # Buffer Crossbar & Staging Engine
│   │   └── dma_top.v                    # DMA Controller Top Module
│   ├── memory/
│   │   ├── instruction_memory.v         # 64 KB Instruction Memory (0x0000_0000)
│   │   └── data_memory.v                # 64 KB Shared Data Memory (0x0001_0000)
│   ├── peripherals/
│   │   ├── uart.v                       # UART Peripheral (0x0002_0000)
│   │   ├── timer.v                      # System Timer (0x0002_0100)
│   │   └── gpio.v                       # GPIO (0x0002_0200)
│   ├── core/
│   │   └── riscv_core.v                 # 32-bit RISC-V Processor Core
│   └── soc_top.v                        # Complete SoC Top-Level Module
├── testbench/
│   ├── tb_matrix_multiplier.v           # Independent Testbench for IP 1
│   ├── tb_activation.v                  # Independent Testbench for IP 2
│   ├── tb_dma.v                         # Independent Testbench for IP 3
│   ├── tb_axi4_to_axilite_bridge.v      # Testbench for AXI Bridge
│   └── tb_soc.v                         # Full SoC End-to-End Testbench
├── software/
│   └── reference_model.py               # Python Golden Reference Model (Q16.16)
├── simulation/
│   ├── run_sim_modelsim.do              # ModelSim / QuestaSim Compilation Script
│   └── simulate_all.ps1                 # Automated PowerShell Simulation Runner
└── documentation/
    ├── README.md                        # Overall Project Documentation (This file)
    ├── README_Matrix_Multiplier.md      # Full Spec for Matrix Multiplier IP
    ├── README_Activation_Unit.md        # Full Spec for Activation Unit IP
    ├── README_DMA_Controller.md         # Full Spec for DMA Controller IP
    ├── README_AXI_Bridge.md             # Full Spec for AXI Bridge
    ├── ADDRESS_MAP.md                   # Complete Memory Map Table
    ├── REGISTER_MAP.md                  # Complete Register Bit Definitions
    ├── ARCHITECTURE.md                  # Comprehensive Architecture Guide
    └── VERIFICATION.md                  # Testbench Results & Verification Plan
```

---

## 3. How to Simulate the SoC

### Option 1: ModelSim / QuestaSim
Open ModelSim or QuestaSim, navigate to the `simulation` directory, and run:
```tcl
do run_sim_modelsim.do
```

### Option 2: Icarus Verilog
From the command prompt / PowerShell in the root directory:
```bash
# Matrix Multiplier Testbench
iverilog -o sim_mat.vvp -g2005-sv rtl/matrix_multiplier/*.v testbench/tb_matrix_multiplier.v
vvp sim_mat.vvp

# Activation Unit Testbench
iverilog -o sim_act.vvp -g2005-sv rtl/activation_unit/*.v testbench/tb_activation.v
vvp sim_act.vvp

# DMA Controller Testbench
iverilog -o sim_dma.vvp -g2005-sv rtl/dma_controller/*.v testbench/tb_dma.v
vvp sim_dma.vvp

# AXI Bridge Testbench
iverilog -o sim_bridge.vvp -g2005-sv rtl/bridge/*.v testbench/tb_axi4_to_axilite_bridge.v
vvp sim_bridge.vvp

# Complete SoC Integration Testbench
iverilog -o sim_soc.vvp -g2005-sv rtl/bridge/*.v rtl/interconnect/*.v rtl/matrix_multiplier/*.v rtl/activation_unit/*.v rtl/dma_controller/*.v rtl/memory/*.v rtl/peripherals/*.v rtl/core/*.v rtl/soc_top.v testbench/tb_soc.v
vvp sim_soc.vvp
```

### Option 3: Python Golden Model
To verify the Q16.16 mathematical reference calculations:
```bash
python software/reference_model.py
```
