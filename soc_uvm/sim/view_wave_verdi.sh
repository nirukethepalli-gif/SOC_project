#!/usr/bin/env bash
# Open Verdi waveform viewer for SoC UVM simulation results
FSDB_FILE=${1:-sim_soc_uvm.fsdb}

if [ ! -f "$FSDB_FILE" ]; then
    echo "Warning: $FSDB_FILE does not exist. Run simulation with +DUMP_FSDB first."
fi

verdi -ssf "$FSDB_FILE" -dbdir simv_soc_uvm.daidir &
