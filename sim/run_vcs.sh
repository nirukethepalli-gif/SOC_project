#!/usr/bin/env bash
# Script to compile and simulate top-level SoC using Synopsys VCS
set -e

echo "=========================================================="
echo " Compiling and Running RISC-V NN Accelerator SoC (VCS)"
echo "=========================================================="

cp -f ../sw/main.hex ./main.hex 2>/dev/null || true

vcs -full64 -sverilog \
    -timescale=1ns/1ps \
    +vcs+lic+wait \
    -debug_access+all \
    -kdb \
    +warn=noTFIPC \
    +v2k \
    -f filelist_soc.f \
    -o simv_soc \
    -l compile.log

./simv_soc +LOAD_HEX +DUMP_FSDB -l sim_soc.log

echo "=========================================================="
echo " Simulation Finished. Review log: sim_soc.log"
echo "=========================================================="
