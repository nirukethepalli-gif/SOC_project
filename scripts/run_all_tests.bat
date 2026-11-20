@echo off
REM ==============================================================================
REM Regression Test Script for Windows Environment
REM Project: RISC-V VeeR-EL2 Based NN Inference Acceleration SoC
REM ==============================================================================

cd /d "%~dp0..\sim"

echo ======================================================================
echo  Starting Full Verification Regression on Synopsys VCS
echo ======================================================================

echo [STEP 1] Running Custom IP 1: Matrix Multiplier Unit Verification...
vcs -full64 -sverilog -notice -timescale=1ns/1ps +v2k -debug_access+all +incdir+../core_config +incdir+../rtl/ip +incdir+../rtl/bus ../rtl/ip/matrix_multiplier.sv ../tb/unit/tb_matrix_multiplier.sv -o simv_mm -l compile_mm.log
simv_mm.exe -l sim_mm.log

echo [STEP 2] Running Custom IP 2: Activation Unit Unit Verification...
vcs -full64 -sverilog -notice -timescale=1ns/1ps +v2k -debug_access+all +incdir+../core_config +incdir+../rtl/ip +incdir+../rtl/bus ../rtl/ip/activation_unit.sv ../tb/unit/tb_activation.sv -o simv_act -l compile_act.log
simv_act.exe -l sim_act.log

echo [STEP 3] Running Custom IP 3: DMA Controller Unit Verification...
vcs -full64 -sverilog -notice -timescale=1ns/1ps +v2k -debug_access+all +incdir+../core_config +incdir+../rtl/ip +incdir+../rtl/bus ../rtl/ip/dma_controller.sv ../tb/unit/tb_dma.sv -o simv_dma -l compile_dma.log
simv_dma.exe -l sim_dma.log

echo [STEP 4] Running Full System-on-Chip Simulation (tb_soc_top)...
vcs -full64 -sverilog -notice -timescale=1ns/1ps +v2k -debug_access+all -f filelist_soc.f -o simv_soc -l compile.log
simv_soc.exe +HEX_FILE=main.hex -l sim.log

echo ======================================================================
echo  Simulation regression completed. Inspect sim.log for results.
echo ======================================================================
pause
