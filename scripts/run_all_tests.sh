#!/usr/bin/env bash
# ==============================================================================
# Regression Test Script for Synopsys VCS
# Project: RISC-V VeeR-EL2 Based NN Inference Acceleration SoC
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_DIR="${SCRIPT_DIR}/../sim"

echo "======================================================================"
echo " Starting Full Verification Regression on Synopsys VCS"
echo "======================================================================"

cd "${SIM_DIR}"

# 1. Clean previous runs
echo "[STEP 1] Cleaning temporary simulation artifacts..."
make -f Makefile.vcs clean

# 2. Run Unit Test 1: Matrix Multiplier
echo ""
echo "[STEP 2] Running Custom IP 1: Matrix Multiplier Unit Verification..."
make -f Makefile.vcs unit_mm
grep -q "tb_matrix_multiplier: ALL TESTS PASSED" sim_mm.log && echo ">>> IP 1 (Matrix Multiplier): PASSED" || { echo ">>> IP 1 FAILED"; exit 1; }

# 3. Run Unit Test 2: Activation Unit
echo ""
echo "[STEP 3] Running Custom IP 2: Activation Unit Unit Verification..."
make -f Makefile.vcs unit_act
grep -q "tb_activation: ALL TESTS PASSED" sim_act.log && echo ">>> IP 2 (Activation Unit): PASSED" || { echo ">>> IP 2 FAILED"; exit 1; }

# 4. Run Unit Test 3: DMA Controller
echo ""
echo "[STEP 4] Running Custom IP 3: DMA Controller Unit Verification..."
make -f Makefile.vcs unit_dma
grep -q "tb_dma: ALL TESTS PASSED" sim_dma.log && echo ">>> IP 3 (DMA Controller): PASSED" || { echo ">>> IP 3 FAILED"; exit 1; }

# 5. Run Full SoC Testbench with VeeR-EL2 RISC-V Core & Firmware
echo ""
echo "[STEP 5] Running Full System-on-Chip Simulation (tb_soc_top)..."
make -f Makefile.vcs soc
grep -q "tb_soc_top: FULL SOC TEST PASSED" sim.log && echo ">>> FULL SOC TOP: PASSED" || { echo ">>> FULL SOC TOP FAILED"; exit 1; }

echo ""
echo "======================================================================"
echo " === ALL TESTS AND SYSTEM INTEGRATION PASSED 100% ON VCS! ==="
echo "======================================================================"
