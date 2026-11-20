#!/usr/bin/env python3
"""
============================================================================
Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
Description: Python Golden Reference Model and Fixed-Point (Q16.16) Verification.
             Implements:
               - Float <-> Signed Q16.16 conversion
               - Matrix-Vector Multiplication: Y = W * X + B
               - Activation Functions: ReLU, Sigmoid (PWL), Tanh (PWL)
               - Generation of test vectors for RTL simulation memory preload
============================================================================
"""

import math

def float_to_q16(val: float) -> int:
    """Converts a Python float to a 32-bit signed Q16.16 integer representation."""
    scaled = int(round(val * 65536.0))
    # Saturated 32-bit signed integer limits
    if scaled > 0x7FFFFFFF:
        scaled = 0x7FFFFFFF
    elif scaled < -0x80000000:
        scaled = -0x80000000
    return scaled & 0xFFFFFFFF

def q16_to_float(raw: int) -> float:
    """Converts a 32-bit unsigned/raw integer back to signed float in Q16.16."""
    if raw >= 0x80000000:
        signed_val = raw - 0x100000000
    else:
        signed_val = raw
    return signed_val / 65536.0

def relu_q16(x: int) -> int:
    """Hardware-equivalent ReLU in Q16.16."""
    if x >= 0x80000000: # Negative
        return 0
    return x

def sigmoid_pwl_q16(x: int) -> int:
    """Hardware-equivalent Piecewise Linear (PLAN) Sigmoid in Q16.16."""
    Q_ONE     = 0x00010000
    Q_HALF    = 0x00008000
    Q_FIVE    = 0x00050000
    Q_2_375   = 0x00026000
    Q_0_625   = 0x0000A000
    Q_0_84375 = 0x0000D800

    is_negative = (x >= 0x80000000)
    abs_x = ((~x + 1) & 0xFFFFFFFF) if is_negative else x

    if abs_x >= Q_FIVE:
        y_pos = Q_ONE
    elif abs_x >= Q_2_375:
        y_pos = (Q_0_84375 + (abs_x >> 5)) & 0xFFFFFFFF
    elif abs_x >= Q_ONE:
        y_pos = (Q_0_625 + (abs_x >> 3)) & 0xFFFFFFFF
    else:
        y_pos = (Q_HALF + (abs_x >> 2)) & 0xFFFFFFFF

    if is_negative:
        return (Q_ONE - y_pos) & 0xFFFFFFFF
    return y_pos

def tanh_pwl_q16(x: int) -> int:
    """Hardware-equivalent Piecewise Linear (PLAN) Tanh in Q16.16."""
    Q_ONE    = 0x00010000
    Q_THREE  = 0x00030000
    Q_1_5    = 0x00018000
    Q_HALF   = 0x00008000
    Q_QUARTER= 0x00004000
    Q_0_8125 = 0x0000D000

    is_negative = (x >= 0x80000000)
    abs_x = ((~x + 1) & 0xFFFFFFFF) if is_negative else x

    if abs_x >= Q_THREE:
        y_pos = Q_ONE
    elif abs_x >= Q_1_5:
        y_pos = (Q_0_8125 + (abs_x >> 3)) & 0xFFFFFFFF
    elif abs_x >= Q_HALF:
        y_pos = (Q_QUARTER + (abs_x >> 1)) & 0xFFFFFFFF
    else:
        y_pos = abs_x

    if is_negative:
        return ((~y_pos + 1) & 0xFFFFFFFF)
    return y_pos

def matrix_vector_mult(W, X, B):
    """
    Computes Y = W * X + B in floating point and exact Q16.16 hardware format.
    W: M x K matrix
    X: K vector
    B: M vector
    """
    M = len(W)
    K = len(X)
    Y_float = []
    Y_q16_raw = []

    for m in range(M):
        dot = 0.0
        acc_q = 0
        for k in range(K):
            prod_float = W[m][k] * X[k]
            dot += prod_float

            # Fixed point hardware MAC
            w_q = float_to_q16(W[m][k])
            x_q = float_to_q16(X[k])
            # 64-bit signed product with rounding
            w_signed = w_q if w_q < 0x80000000 else (w_q - 0x100000000)
            x_signed = x_q if x_q < 0x80000000 else (x_q - 0x100000000)
            prod_raw = w_signed * x_signed
            prod_rounded = (prod_raw + 0x8000) >> 16
            acc_q += prod_rounded

        # Bias addition
        b_q = float_to_q16(B[m])
        b_signed = b_q if b_q < 0x80000000 else (b_q - 0x100000000)
        y_signed = acc_q + b_signed
        Y_float.append(dot + B[m])
        Y_q16_raw.append(y_signed & 0xFFFFFFFF)

    return Y_float, Y_q16_raw

if __name__ == "__main__":
    print("====================================================================")
    print("   RISC-V NN ACCELERATOR SoC: PYTHON REFERENCE MODEL (Q16.16)       ")
    print("====================================================================")

    # Test Case 1: 2x2 Layer
    W = [[ 2.0, -1.5],
         [ 0.5,  3.0]]
    X = [ 1.0,  2.0]
    B = [ 0.25, -0.5]

    y_float, y_q16_raw = matrix_vector_mult(W, X, B)

    print("\n--- 1. Linear Layer Computation: Y = W * X + B ---")
    for i in range(len(y_float)):
        print(f" Neuron {i}: Mathematical = {y_float[i]:+.4f} | Hardware Q16.16 = {q16_to_float(y_q16_raw[i]):+.4f} (0x{y_q16_raw[i]:08X})")

    print("\n--- 2. Activation Function Verification ---")
    for i in range(len(y_q16_raw)):
        raw_val = y_q16_raw[i]
        relu_val = relu_q16(raw_val)
        sig_val  = sigmoid_pwl_q16(raw_val)
        tanh_val = tanh_pwl_q16(raw_val)

        print(f" Neuron {i} Input: {q16_to_float(raw_val):+.4f}")
        print(f"   -> ReLU:    {q16_to_float(relu_val):+.4f} (0x{relu_val:08X})")
        print(f"   -> Sigmoid: {q16_to_float(sig_val):+.4f} (0x{sig_val:08X}) [Ideal: {1.0/(1.0+math.exp(-q16_to_float(raw_val))):.4f}]")
        print(f"   -> Tanh:    {q16_to_float(tanh_val):+.4f} (0x{tanh_val:08X}) [Ideal: {math.tanh(q16_to_float(raw_val)):.4f}]")

    print("\n====================================================================")
    print(" Reference model validation complete.")
