# VCS Filelist for SoC-Level UVM Environment
# Project: RISC-V Based SoC for Lightweight NN Inference Acceleration

+libext+.v+.sv
+define+RV_BUILD_AXI4
+define+RV_OPENSOURCE

+incdir+../../core_config
+incdir+../../Cores-VeeR-EL2-main/design/include
+incdir+../../Cores-VeeR-EL2-main/design/lib
+incdir+../../rtl/bus
+incdir+../../rtl/ip
+incdir+../../rtl/mem
+incdir+../../soc_uvm/interfaces
+incdir+../../soc_uvm/soc_uvm_env
+incdir+../../tb/vip/uart_vip_uvm_tb
+incdir+../../tb/vip/gpio_vip_uvm_tb
+incdir+../../tb/vip/timer_vip_uvm_tb
+incdir+../../tb/vip/matrix_multiplier_vip_uvm_tb
+incdir+../../tb/vip/activation_vip_uvm_tb
+incdir+../../tb/vip/dma_vip_uvm_tb

# Core Defines and Packages
../../core_config/common_defines.vh
../../Cores-VeeR-EL2-main/design/lib/el2_assert.sv
../../Cores-VeeR-EL2-main/design/el2_mubi_pkg.sv
../../Cores-VeeR-EL2-main/design/include/el2_def.sv

# VeeR EL2 Core Source
../../Cores-VeeR-EL2-main/design/el2_mem.sv
../../Cores-VeeR-EL2-main/design/el2_pic_ctrl.sv
../../Cores-VeeR-EL2-main/design/el2_veer.sv
../../Cores-VeeR-EL2-main/design/el2_dma_ctrl.sv
../../Cores-VeeR-EL2-main/design/el2_pmp.sv
../../Cores-VeeR-EL2-main/design/ifu/el2_ifu_aln_ctl.sv
../../Cores-VeeR-EL2-main/design/ifu/el2_ifu_compress_ctl.sv
../../Cores-VeeR-EL2-main/design/ifu/el2_ifu_ifc_ctl.sv
../../Cores-VeeR-EL2-main/design/ifu/el2_ifu_bp_ctl.sv
../../Cores-VeeR-EL2-main/design/ifu/el2_ifu_ic_mem.sv
../../Cores-VeeR-EL2-main/design/ifu/el2_ifu_mem_ctl.sv
../../Cores-VeeR-EL2-main/design/ifu/el2_ifu_iccm_mem.sv
../../Cores-VeeR-EL2-main/design/ifu/el2_ifu.sv
../../Cores-VeeR-EL2-main/design/dec/el2_dec_decode_ctl.sv
../../Cores-VeeR-EL2-main/design/dec/el2_dec_gpr_ctl.sv
../../Cores-VeeR-EL2-main/design/dec/el2_dec_ib_ctl.sv
../../Cores-VeeR-EL2-main/design/dec/el2_dec_pmp_ctl.sv
../../Cores-VeeR-EL2-main/design/dec/el2_dec_tlu_ctl.sv
../../Cores-VeeR-EL2-main/design/dec/el2_dec_trigger.sv
../../Cores-VeeR-EL2-main/design/dec/el2_dec.sv
../../Cores-VeeR-EL2-main/design/exu/el2_exu_alu_ctl.sv
../../Cores-VeeR-EL2-main/design/exu/el2_exu_mul_ctl.sv
../../Cores-VeeR-EL2-main/design/exu/el2_exu_div_ctl.sv
../../Cores-VeeR-EL2-main/design/exu/el2_exu.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_clkdomain.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_addrcheck.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_lsc_ctl.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_stbuf.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_bus_buffer.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_bus_intf.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_ecc.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_dccm_mem.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_dccm_ctl.sv
../../Cores-VeeR-EL2-main/design/lsu/el2_lsu_trigger.sv
../../Cores-VeeR-EL2-main/design/dbg/el2_dbg.sv
../../Cores-VeeR-EL2-main/design/dmi/dmi_mux.v
../../Cores-VeeR-EL2-main/design/dmi/dmi_wrapper.v
../../Cores-VeeR-EL2-main/design/dmi/dmi_jtag_to_core_sync.v
../../Cores-VeeR-EL2-main/design/dmi/rvjtag_tap.v
../../Cores-VeeR-EL2-main/design/lib/el2_lib.sv
../../Cores-VeeR-EL2-main/design/lib/el2_mem_if.sv
-v ../../Cores-VeeR-EL2-main/design/lib/beh_lib.sv
-v ../../Cores-VeeR-EL2-main/design/lib/mem_lib.sv
../../Cores-VeeR-EL2-main/design/el2_veer_wrapper.sv

# Bus Infrastructure & Bridges
../../rtl/bus/axi4_to_axi4lite.sv
../../rtl/bus/axi4_to_axi4lite_ro.sv
../../rtl/bus/axi4lite_decoder.sv
../../rtl/bus/axi4lite_interconnect.sv
../../rtl/bus/axi4lite_err_slave.sv
../../rtl/bus/axi4lite_regif.sv
../../rtl/bus/axi4lite_assertions.sv

# Memory Subsystem
../../rtl/mem/axi4lite_sram.sv
../../rtl/mem/axi4lite_sram_dp.sv

# Baseline Peripherals
../../rtl/ip/uart.sv
../../rtl/ip/timer.sv
../../rtl/ip/gpio.sv

# Custom Hardware IPs
../../rtl/ip/matrix_multiplier.sv
../../rtl/ip/activation_unit.sv
../../rtl/ip/dma_controller.sv

# SoC Top Integration
../../rtl/soc_top.sv

# VIP Interfaces & Packages
../../soc_uvm/interfaces/soc_vip_interfaces.sv
../../tb/vip/uart_vip_uvm_tb/uart_vip_pkg.sv
../../tb/vip/gpio_vip_uvm_tb/gpio_vip_pkg.sv
../../tb/vip/timer_vip_uvm_tb/timer_vip_pkg.sv
../../tb/vip/matrix_multiplier_vip_uvm_tb/matrix_multiplier_vip_pkg.sv
../../tb/vip/activation_vip_uvm_tb/activation_vip_pkg.sv
../../tb/vip/dma_vip_uvm_tb/dma_vip_pkg.sv

# SoC UVM Top Testbench
../../soc_uvm/tb/tb_soc_uvm_top.sv
