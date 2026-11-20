# Verification Plan & Simulation Results

## 1. Verification Strategy

The design follows a modular, hierarchical verification methodology:
1. **Unit-Level Testbenches**: Verify individual custom IPs independently using directed stimulus, corner cases, and protocol assertion checks.
2. **Bridge Protocol Testbench**: Verify AXI4 burst decomposition into single-beat AXI4-Lite transfers.
3. **End-to-End SoC Testbench**: Verify complete neural network inference acceleration across CPU, Memories, DMA, Matrix Multiplier, and Activation Unit.
4. **Python Golden Reference Comparison**: Ensure all fixed-point mathematical operations match bit-exact reference calculations.

---

## 2. Testbench Matrix

| Testbench File | Target Module | Key Verification Checks | Status |
| :--- | :--- | :--- | :--- |
| **`tb_matrix_multiplier.v`** | `matrix_multiplier_top` | - 2x2 matrix-vector multiplication with bias<br>- Positive, negative, fractional operands<br>- Accumulator clear and saturation logic<br>- Streaming valid/ready handshake<br>- AXI4-Lite register access | **PASSED** |
| **`tb_activation.v`** | `activation_top` | - ReLU for positive, negative, and zero inputs<br>- Sigmoid PWL at zero ($0.5$), positive, and negative values<br>- Tanh PWL at zero ($0.0$), positive, and negative values<br>- Function selection register switching<br>- Vector length counting | **PASSED** |
| **`tb_dma.v`** | `dma_top` | - Memory-to-Accelerator transfer<br>- Accelerator-to-Memory transfer<br>- Address auto-increment (+4 bytes)<br>- Transfer counter decrement<br>- Misalignment error handling | **PASSED** |
| **`tb_axi4_to_axilite_bridge.v`** | `axi4_to_axilite_bridge` | - Single-beat write and read conversion<br>- Multi-beat burst write (INCR mode)<br>- Multi-beat burst read with `RLAST`<br>- Backpressure and ready handshakes | **PASSED** |
| **`tb_soc.v`** | `soc_top` | - Full inference pipeline:<br>  $\text{Data Memory} \rightarrow \text{DMA} \rightarrow \text{Matrix Mult} \rightarrow \text{Activation} \rightarrow \text{DMA} \rightarrow \text{Data Memory}$<br>- Verification of final outputs in memory against golden mathematical model | **PASSED** |

---

## 3. End-to-End Simulation Test Case (2x2 Neuron Layer)

### Mathematical Parameters:
- **Input Vector $X$**:
  $$X = \begin{bmatrix} +1.0 \\ +2.0 \end{bmatrix} \quad (\text{Q16.16: } [0x0001\_0000, 0x0002\_0000])$$
- **Weight Matrix $W$**:
  $$W = \begin{bmatrix} +2.0 & -1.5 \\ +0.5 & +3.0 \end{bmatrix} \quad (\text{Q16.16: } [0x0002\_0000, 0xFFFE\_8000, 0x0000\_8000, 0x0003\_0000])$$
- **Bias Vector $B$**:
  $$B = \begin{bmatrix} +0.25 \\ -0.50 \end{bmatrix} \quad (\text{Q16.16: } [0x0000\_4000, 0xFFFF\_8000])$$

### Expected Linear Computation ($Y_{raw} = W \times X + B$):
- **Neuron 0**:
  $$Y_{raw}[0] = (2.0 \times 1.0) + (-1.5 \times 2.0) + 0.25 = 2.0 - 3.0 + 0.25 = -0.75 \quad (0xFFFF\_4000)$$
- **Neuron 1**:
  $$Y_{raw}[1] = (0.5 \times 1.0) + (3.0 \times 2.0) + (-0.5) = 0.5 + 6.0 - 0.5 = +6.0 \quad (0x0006\_0000)$$

### Expected Activated Computation ($Y_{act} = \text{ReLU}(Y_{raw})$):
- **Neuron 0**:
  $$Y_{act}[0] = \text{ReLU}(-0.75) = 0.0 \quad (\mathbf{0x0000\_0000})$$
- **Neuron 1**:
  $$Y_{act}[1] = \text{ReLU}(+6.0) = +6.0 \quad (\mathbf{0x0006\_0000})$$

### Actual Hardware Results from `tb_soc.v`:
- `Data Memory[256]` (Neuron 0): **`0x0000_0000`** ($0.0$) $\rightarrow$ **MATCH [PASS]**
- `Data Memory[257]` (Neuron 1): **`0x0006_0000`** ($+6.0$) $\rightarrow$ **MATCH [PASS]**
