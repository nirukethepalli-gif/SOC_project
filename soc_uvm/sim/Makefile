# Makefile for Synopsys VCS SoC UVM Environment
# Project: RISC-V Based SoC for Lightweight NN Inference Acceleration

VCS_OPTS = -full64 -sverilog -ntb_opts uvm-1.2 \
           -timescale=1ns/1ps \
           +vcs+lic+wait \
           -debug_access+all \
           -kdb \
           +warn=noTFIPC \
           +v2k \
           -f filelist.f

TESTNAME ?= matrix_mult_test
HEX_FILE ?= ../../sw/main.hex
SEED     ?= 1

all: comp run

comp:
	@echo "=========================================================="
	@echo " Compiling SoC UVM Environment with Synopsys VCS"
	@echo "=========================================================="
	vcs $(VCS_OPTS) -o simv_soc_uvm

run:
	@echo "=========================================================="
	@echo " Running Test: $(TESTNAME) (Seed: $(SEED))"
	@echo "=========================================================="
	cp -f $(HEX_FILE) main.hex || true
	./simv_soc_uvm +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=UVM_MEDIUM +ntb_random_seed=$(SEED) +LOAD_HEX +DUMP_FSDB -l sim_$(TESTNAME).log

run_gui:
	cp -f $(HEX_FILE) main.hex || true
	./simv_soc_uvm +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=UVM_MEDIUM -gui -l sim_$(TESTNAME).log

test_mm:
	$(MAKE) run TESTNAME=matrix_mult_test

test_act:
	$(MAKE) run TESTNAME=activation_test

test_dma:
	$(MAKE) run TESTNAME=dma_test

test_uart:
	$(MAKE) run TESTNAME=uart_connectivity_test

test_timer:
	$(MAKE) run TESTNAME=timer_test

test_gpio:
	$(MAKE) run TESTNAME=gpio_test

clean:
	rm -rf simv* csrc *.log *.key *.vpd *.vcd *.fsdb DVEfiles verdiLog ucli.key vc_hdrs.h *.h *.hex
