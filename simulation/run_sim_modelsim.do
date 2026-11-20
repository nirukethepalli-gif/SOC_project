# ==============================================================================
# ModelSim / QuestaSim Simulation Script
# Project: RISC-V Based SoC for Lightweight NN Inference Acceleration
# ==============================================================================

vlib work
vmap work work

# Compile Bridge
vlog -work work ../rtl/bridge/axi4_to_axilite_bridge.v
vlog -work work ../testbench/tb_axi4_to_axilite_bridge.v

# Compile Matrix Multiplier IP
vlog -work work ../rtl/matrix_multiplier/mac_unit.v
vlog -work work ../rtl/matrix_multiplier/input_buffer.v
vlog -work work ../rtl/matrix_multiplier/weight_buffer.v
vlog -work work ../rtl/matrix_multiplier/bias_adder.v
vlog -work work ../rtl/matrix_multiplier/output_buffer.v
vlog -work work ../rtl/matrix_multiplier/matrix_controller.v
vlog -work work ../rtl/matrix_multiplier/matrix_axi_regs.v
vlog -work work ../rtl/matrix_multiplier/matrix_multiplier_top.v
vlog -work work ../testbench/tb_matrix_multiplier.v

# Compile Activation Unit IP
vlog -work work ../rtl/activation_unit/relu.v
vlog -work work ../rtl/activation_unit/sigmoid.v
vlog -work work ../rtl/activation_unit/tanh.v
vlog -work work ../rtl/activation_unit/function_selector.v
vlog -work work ../rtl/activation_unit/activation_controller.v
vlog -work work ../rtl/activation_unit/activation_axi_regs.v
vlog -work work ../rtl/activation_unit/activation_top.v
vlog -work work ../testbench/tb_activation.v

# Compile DMA Controller IP
vlog -work work ../rtl/dma_controller/address_generator.v
vlog -work work ../rtl/dma_controller/dma_read_controller.v
vlog -work work ../rtl/dma_controller/dma_write_controller.v
vlog -work work ../rtl/dma_controller/dma_transfer_engine.v
vlog -work work ../rtl/dma_controller/dma_registers.v
vlog -work work ../rtl/dma_controller/dma_fsm.v
vlog -work work ../rtl/dma_controller/dma_top.v
vlog -work work ../testbench/tb_dma.v

# Compile Interconnect & Memories & Peripherals & Core & SoC Top
vlog -work work ../rtl/interconnect/address_decoder.v
vlog -work work ../rtl/memory/instruction_memory.v
vlog -work work ../rtl/memory/data_memory.v
vlog -work work ../rtl/peripherals/uart.v
vlog -work work ../rtl/peripherals/timer.v
vlog -work work ../rtl/peripherals/gpio.v
vlog -work work ../rtl/core/riscv_core.v
vlog -work work ../rtl/soc_top.v
vlog -work work ../testbench/tb_soc.v

# Run Simulation for Full SoC
vsim -c -voptargs="+acc" work.tb_soc
run -all
