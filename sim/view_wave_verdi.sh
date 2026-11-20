#!/usr/bin/env bash
# Open Verdi waveform viewer for SoC simulation
FSDB_FILE=${1:-sim_soc.fsdb}
verdi -ssf "$FSDB_FILE" -dbdir simv_soc.daidir &
