// Filelist for Custom IPs Unit Verification in Synopsys VCS
// Target: Matrix Multiplier, Activation Unit, and DMA Controller

+incdir+../core_config
+incdir+../rtl/ip
+incdir+../rtl/bus

// Custom IPs RTL
../rtl/ip/matrix_multiplier.sv
../rtl/ip/activation_unit.sv
../rtl/ip/dma_controller.sv

// Testbench Models & BFMs
../tb/models/axi4lite_master_bfm.sv
../tb/models/uart_monitor.sv
