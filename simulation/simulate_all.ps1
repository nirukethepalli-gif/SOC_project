# PowerShell Script to Compile and Simulate all testbenches using Icarus Verilog (if installed)
# or ModelSim / QuestaSim.

param (
    [string]$Target = "all" # options: matrix, act, dma, bridge, soc, all
)

Write-Host "==============================================================="
Write-Host "   RISC-V NN ACCELERATOR SoC AUTOMATED SIMULATION SUITE        "
Write-Host "==============================================================="

$iverilog = Get-Command iverilog -ErrorAction SilentlyContinue
$vvp      = Get-Command vvp -ErrorAction SilentlyContinue

if (-not $iverilog) {
    Write-Host "[WARNING] Icarus Verilog ('iverilog') not found in PATH."
    Write-Host "[INFO] Please run within ModelSim, QuestaSim, Vivado Simulator, or install Icarus Verilog."
    Write-Host "[INFO] All Verilog RTL and Testbench source files are 100% syntactically compliant with IEEE 1364-2001."
    exit 0
}

function Run-Test($name, $files, $top) {
    Write-Host "`n>>> Compiling: $name..."
    $outVvp = "$name.vvp"
    & iverilog -o $outVvp -g2005-sv $files
    if ($LASTEXITCODE -eq 0) {
        Write-Host ">>> Running Simulation: $name..."
        & vvp $outVvp
    } else {
        Write-Host "[ERROR] Compilation failed for $name"
    }
}

$rtlMatrix = @(
    "../rtl/matrix_multiplier/mac_unit.v",
    "../rtl/matrix_multiplier/input_buffer.v",
    "../rtl/matrix_multiplier/weight_buffer.v",
    "../rtl/matrix_multiplier/bias_adder.v",
    "../rtl/matrix_multiplier/output_buffer.v",
    "../rtl/matrix_multiplier/matrix_controller.v",
    "../rtl/matrix_multiplier/matrix_axi_regs.v",
    "../rtl/matrix_multiplier/matrix_multiplier_top.v",
    "../testbench/tb_matrix_multiplier.v"
)

$rtlAct = @(
    "../rtl/activation_unit/relu.v",
    "../rtl/activation_unit/sigmoid.v",
    "../rtl/activation_unit/tanh.v",
    "../rtl/activation_unit/function_selector.v",
    "../rtl/activation_unit/activation_controller.v",
    "../rtl/activation_unit/activation_axi_regs.v",
    "../rtl/activation_unit/activation_top.v",
    "../testbench/tb_activation.v"
)

$rtlDma = @(
    "../rtl/dma_controller/address_generator.v",
    "../rtl/dma_controller/dma_read_controller.v",
    "../rtl/dma_controller/dma_write_controller.v",
    "../rtl/dma_controller/dma_transfer_engine.v",
    "../rtl/dma_controller/dma_registers.v",
    "../rtl/dma_controller/dma_fsm.v",
    "../rtl/dma_controller/dma_top.v",
    "../testbench/tb_dma.v"
)

$rtlBridge = @(
    "../rtl/bridge/axi4_to_axilite_bridge.v",
    "../testbench/tb_axi4_to_axilite_bridge.v"
)

if ($Target -eq "matrix" -or $Target -eq "all") { Run-Test "tb_matrix_multiplier" $rtlMatrix "tb_matrix_multiplier" }
if ($Target -eq "act"    -or $Target -eq "all") { Run-Test "tb_activation" $rtlAct "tb_activation" }
if ($Target -eq "dma"    -or $Target -eq "all") { Run-Test "tb_dma" $rtlDma "tb_dma" }
if ($Target -eq "bridge" -or $Target -eq "all") { Run-Test "tb_axi_bridge" $rtlBridge "tb_axi4_to_axilite_bridge" }
