// SPDX-License-Identifier: Apache-2.0
// main.c - Neural Network Inference Test Application for VeeR-EL2 SoC
// Project: RISC-V Based SoC for Lightweight NN Inference Acceleration

#include "soc.h"

// Test dataset in Q16.16 fixed-point format
// X = [ 1.5, -0.5 ]
static const uint32_t input_vector[2] = {
    0x00018000, // +1.5
    0xFFFF8000  // -0.5
};

// W = [ [ 2.0,  1.0 ],
//       [-1.0,  3.0 ] ]
static const uint32_t weight_matrix[4] = {
    0x00020000, // W00 = +2.0
    0x00010000, // W01 = +1.0
    0xFFFF0000, // W10 = -1.0
    0x00030000  // W11 = +3.0
};

// B = [ 0.25, 0.50 ]
static const uint32_t bias_vector[2] = {
    0x00004000, // B0 = +0.25
    0x00008000  // B1 = +0.50
};

// Expected Mathematical Output after ReLU:
// Y0 = (2.0 * 1.5) + (1.0 * -0.5) + 0.25 = 3.0 - 0.5 + 0.25 = 2.75 -> 0x0002C000
// Y1 = (-1.0 * 1.5) + (3.0 * -0.5) + 0.50 = -1.5 - 1.5 + 0.50 = -2.5 -> 0xFFFD8000
// ReLU(Y0) = 2.75 -> 0x0002C000
// ReLU(Y1) = 0.00 -> 0x00000000
static const uint32_t expected_output[2] = {
    0x0002C000,
    0x00000000
};

int main(void) {
    // 1. Initialize UART (baud rate divisor = 434 for 115200 baud @ 50MHz)
    UART_REG_BAUDDIV = 434;
    UART_REG_CTRL    = 0x03; // Enable TX and RX

    uart_puts("\n");
    uart_puts("====================================================\n");
    uart_puts("[SoC] VeeR-EL2 RISC-V NN Inference Accelerator Booted\n");
    uart_puts("[SoC] Memory Map: Base 0x8000_0000 Peripherals Active\n");
    uart_puts("====================================================\n");

    // 2. Program Matrix Multiplier Dimensions: M=2, N=1, K=2
    // DIM_MNK register format: [23:16]=M, [15:8]=N, [7:0]=K
    uart_puts("[SoC] Configuring Matrix Multiplier Dimensions (2x2 * 2x1 + 2x1)...\n");
    MAT_REG_DIM_MNK = (2U << 16) | (1U << 8) | 2U;

    // 3. Load Inputs, Weights, and Biases via MMIO buffer ports
    uart_puts("[SoC] Loading Input Vector X into Matrix Buffer...\n");
    MAT_REG_BUF_INDEX = 0;
    MAT_REG_IN_DATA   = input_vector[0];
    MAT_REG_IN_DATA   = input_vector[1];

    uart_puts("[SoC] Loading Weight Matrix W into Matrix Buffer...\n");
    MAT_REG_BUF_INDEX = 0;
    for (int i = 0; i < 4; i++) {
        MAT_REG_W_DATA = weight_matrix[i];
    }

    uart_puts("[SoC] Loading Bias Vector B into Matrix Buffer...\n");
    MAT_REG_BUF_INDEX = 0;
    MAT_REG_BIAS_DATA = bias_vector[0];
    MAT_REG_BIAS_DATA = bias_vector[1];

    // 4. Configure Activation Unit for 2 elements with ReLU function
    uart_puts("[SoC] Configuring Activation Unit (Vector Length = 2, Function = ReLU)...\n");
    ACT_REG_VEC_LEN = 2;
    // Set ReLU function (bits [3:2] = 00)
    ACT_REG_CTRL    = ACT_FUNC_RELU;

    // 5. Start Matrix Multiplier IP
    uart_puts("[SoC] Launching Custom IP 1: Matrix Multiplier...\n");
    MAT_REG_CTRL = MAT_CTRL_START;

    // Wait for Matrix Multiplier completion
    while (!(MAT_REG_STATUS & MAT_STATUS_DONE));
    uart_puts("[SoC] Matrix Multiplier Execution Finished.\n");

    // 6. Read Raw Outputs from Matrix Multiplier and Feed into Activation Unit
    MAT_REG_BUF_INDEX = 0;
    uint32_t raw_y0 = MAT_REG_OUT_DATA;
    uint32_t raw_y1 = MAT_REG_OUT_DATA;

    uart_puts("[SoC] Raw MAC Output Y[0]: ");
    uart_puthex(raw_y0);
    uart_puts(", Y[1]: ");
    uart_puthex(raw_y1);
    uart_puts("\n");

    // Stream/Write into Activation Unit
    ACT_REG_BUF_INDEX = 0;
    ACT_REG_IN_DATA   = raw_y0;
    ACT_REG_IN_DATA   = raw_y1;

    // 7. Launch Activation Unit IP
    uart_puts("[SoC] Launching Custom IP 2: Activation Unit (ReLU)...\n");
    ACT_REG_CTRL = ACT_FUNC_RELU | ACT_CTRL_START;

    // Wait for Activation Unit completion
    while (!(ACT_REG_STATUS & ACT_STATUS_DONE));
    uart_puts("[SoC] Activation Unit Processing Finished.\n");

    // 8. Read and Verify Final Neural Network Inference Results
    ACT_REG_BUF_INDEX = 0;
    uint32_t z0 = ACT_REG_OUT_DATA;
    uint32_t z1 = ACT_REG_OUT_DATA;

    uart_puts("[SoC] Final Activated Result Z[0]: ");
    uart_puthex(z0);
    uart_puts(" (Expected: ");
    uart_puthex(expected_output[0]);
    uart_puts(")\n");

    uart_puts("[SoC] Final Activated Result Z[1]: ");
    uart_puthex(z1);
    uart_puts(" (Expected: ");
    uart_puthex(expected_output[1]);
    uart_puts(")\n");

    int errors = 0;
    if (z0 != expected_output[0]) errors++;
    if (z1 != expected_output[1]) errors++;

    if (errors == 0) {
        uart_puts("\n====================================================\n");
        uart_puts("[SoC] === TEST PASSED ===\n");
        uart_puts("[SoC] Neural Network Inference Accelerator Verified!\n");
        uart_puts("====================================================\n");
    } else {
        uart_puts("\n====================================================\n");
        uart_puts("[SoC] === TEST FAILED ===\n");
        uart_puts("====================================================\n");
    }

    // Toggle GPIO pins as an external completion indicator
    GPIO_REG_DIR      = 0xFFFF; // All outputs
    GPIO_REG_DATA_OUT = (errors == 0) ? 0xAA55 : 0xDEAD;

    return errors;
}
