#!/usr/bin/env bash
# Script to compile and run SoC UVM tests using Synopsys VCS
# Usage: ./run_vcs.sh [TESTNAME] [SEED]
set -e

TEST=${1:-matrix_mult_test}
SEED=${2:-1}

echo "=========================================================="
echo " Starting VCS Simulation for SoC UVM: $TEST (Seed: $SEED)"
echo "=========================================================="

# Ensure hex file is copied
cp -f ../../sw/main.hex ./main.hex 2>/dev/null || true

# Compile
vcs -full64 -sverilog -ntb_opts uvm-1.2 \
    -timescale=1ns/1ps \
    +vcs+lic+wait \
    -debug_access+all \
    -kdb \
    +warn=noTFIPC \
    +v2k \
    -f filelist.f \
    -o simv_soc_uvm \
    -l compile.log

# Run
./simv_soc_uvm +UVM_TESTNAME=$TEST +UVM_VERBOSITY=UVM_MEDIUM +ntb_random_seed=$SEED +LOAD_HEX +DUMP_FSDB -l sim_${TEST}.log

echo "=========================================================="
echo " Simulation Complete. Review log: sim_${TEST}.log"
echo "=========================================================="
