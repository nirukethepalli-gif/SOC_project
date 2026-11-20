#!/usr/bin/env bash
# Open Synopsys DVE waveform viewer for SoC UVM simulation results
VPD_FILE=${1:-sim_soc_uvm.vpd}

dve -vpd "$VPD_FILE" &
