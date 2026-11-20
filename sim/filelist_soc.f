// SPDX-License-Identifier: Apache-2.0
// VCS Filelist for Full SoC Integration Simulation (tb_soc_top)
// Project: RISC-V VeeR-EL2 Based NN Inference Acceleration SoC

+libext+.v+.sv
+define+RV_BUILD_AXI4
+define+RV_OPENSOURCE

+incdir+../core_config
+incdir+../Cores-VeeR-EL2-main/design/include
+incdir+../Cores-VeeR-EL2-main/design/lib
+incdir+../rtl/bus
+incdir+../rtl/mem
+incdir+../rtl/ip

// VeeR EL2 Core RTL
../Cores-VeeR-EL2-main/design/lib/el2_assert.sv
../Cores-VeeR-EL2-main/design/el2_mubi_pkg.sv
../Cores-VeeR-EL2-main/design/include/el2_def.sv
../Cores-VeeR-EL2-main/design/el2_mem.sv
../Cores-VeeR-EL2-main/design/el2_pic_ctrl.sv
../Cores-VeeR-EL2-main/design/el2_veer.sv
../Cores-VeeR-EL2-main/design/el2_dma_ctrl.sv
../Cores-VeeR-EL2-main/design/el2_pmp.sv
../Cores-VeeR-EL2-main/design/ifu/el2_ifu_aln_ctl.sv
../Cores-VeeR-EL2-main/design/ifu/el2_ifu_compress_ctl.sv
../Cores-VeeR-EL2-main/design/ifu/el2_ifu_ifc_ctl.sv
../Cores-VeeR-EL2-main/design/ifu/el2_ifu_bp_ctl.sv
../Cores-VeeR-EL2-main/design/ifu/el2_ifu_ic_mem.sv
../Cores-VeeR-EL2-main/design/ifu/el2_ifu_mem_ctl.sv
../Cores-VeeR-EL2-main/design/ifu/el2_ifu_iccm_mem.sv
../Cores-VeeR-EL2-main/design/ifu/el2_ifu.sv
../Cores-VeeR-EL2-main/design/dec/el2_dec_decode_ctl.sv
../Cores-VeeR-EL2-main/design/dec/el2_dec_gpr_ctl.sv
../Cores-VeeR-EL2-main/design/dec/el2_dec_ib_ctl.sv
../Cores-VeeR-EL2-main/design/dec/el2_dec_pmp_ctl.sv
../Cores-VeeR-EL2-main/design/dec/el2_dec_tlu_ctl.sv
../Cores-VeeR-EL2-main/design/dec/el2_dec_trigger.sv
../Cores-VeeR-EL2-main/design/dec/el2_dec.sv
../Cores-VeeR-EL2-main/design/exu/el2_exu_alu_ctl.sv
../Cores-VeeR-EL2-main/design/exu/el2_exu_mul_ctl.sv
../Cores-VeeR-EL2-main/design/exu/el2_exu_div_ctl.sv
../Cores-VeeR-EL2-main/design/exu/el2_exu.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_clkdomain.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_addrcheck.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_lsc_ctl.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_stbuf.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_bus_buffer.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_bus_intf.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_ecc.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_dccm_mem.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_dccm_ctl.sv
../Cores-VeeR-EL2-main/design/lsu/el2_lsu_trigger.sv
../Cores-VeeR-EL2-main/design/dbg/el2_dbg.sv
../Cores-VeeR-EL2-main/design/dmi/dmi_mux.v
../Cores-VeeR-EL2-main/design/dmi/dmi_wrapper.v
../Cores-VeeR-EL2-main/design/dmi/dmi_jtag_to_core_sync.v
../Cores-VeeR-EL2-main/design/dmi/rvjtag_tap.v
../Cores-VeeR-EL2-main/design/lib/el2_lib.sv
../Cores-VeeR-EL2-main/design/lib/el2_mem_if.sv
-v ../Cores-VeeR-EL2-main/design/lib/beh_lib.sv
-v ../Cores-VeeR-EL2-main/design/lib/mem_lib.sv
../Cores-VeeR-EL2-main/design/el2_veer_wrapper.sv

// SoC Bus & Memory RTL
../rtl/bus/axi4lite_assertions.sv
../rtl/bus/axi4lite_decoder.sv
../rtl/bus/axi4lite_err_slave.sv
../rtl/bus/axi4lite_regif.sv
../rtl/bus/axi4lite_interconnect.sv
../rtl/bus/axi4_to_axi4lite.sv
../rtl/bus/axi4_to_axi4lite_ro.sv
../rtl/mem/axi4lite_sram.sv
../rtl/mem/axi4lite_sram_dp.sv

// SoC Peripherals
../rtl/ip/uart.sv
../rtl/ip/timer.sv
../rtl/ip/gpio.sv

// Custom Neural Network Hardware Accelerators
../rtl/ip/matrix_multiplier.sv
../rtl/ip/activation_unit.sv
../rtl/ip/dma_controller.sv

// SoC Top Integration
../rtl/soc_top.sv

// Verification Models & System TB
../tb/models/uart_monitor.sv
../tb/tb_soc_top.sv
