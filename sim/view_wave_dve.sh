#!/usr/bin/env bash
# Open Synopsys DVE waveform viewer for SoC simulation
VPD_FILE=${1:-sim_soc.vpd}
dve -vpd "$VPD_FILE" &
