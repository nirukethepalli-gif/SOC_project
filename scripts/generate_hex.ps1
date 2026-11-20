# PowerShell RV32I Two-Pass Assembler to produce main.hex for VeeR-EL2 SoC
# Generates verbatim 32-bit hex words matching Verilog $readmemh format

$ErrorActionPreference = "Stop"

class Assembler {
    [System.Collections.Generic.Dictionary[string, int]]$labels = [System.Collections.Generic.Dictionary[string, int]]::new()
    [System.Collections.Generic.List[object]]$instructions = [System.Collections.Generic.List[object]]::new()
    [int]$currentPc = 0

    [int]Reg([string]$name) {
        $n = $name.Trim().ToLower()
        switch ($n) {
            "zero" { return 0 }
            "ra"   { return 1 }
            "sp"   { return 2 }
            "gp"   { return 3 }
            "tp"   { return 4 }
            "t0"   { return 5 }
            "t1"   { return 6 }
            "t2"   { return 7 }
            "s0"   { return 8 }
            "s1"   { return 9 }
            "a0"   { return 10 }
            "a1"   { return 11 }
            "a2"   { return 12 }
            "a3"   { return 13 }
            "a4"   { return 14 }
            "a5"   { return 15 }
            "a6"   { return 16 }
            "a7"   { return 17 }
            "s2"   { return 18 }
            "s3"   { return 19 }
            "s4"   { return 20 }
            "s5"   { return 21 }
            "s6"   { return 22 }
            "s7"   { return 23 }
            "s8"   { return 24 }
            "s9"   { return 25 }
            "s10"  { return 26 }
            "s11"  { return 27 }
            "t3"   { return 28 }
            "t4"   { return 29 }
            "t5"   { return 30 }
            "t6"   { return 31 }
            default {
                if ($n.StartsWith("x")) {
                    return [int]::Parse($n.Substring(1))
                }
                throw "Unknown register: $name"
            }
        }
        return 0
    }

    Label([string]$name) {
        $this.labels[$name] = $this.currentPc
    }

    AddInst([scriptblock]$emitter) {
        $this.instructions.Add(@{ Pc = $this.currentPc; Emitter = $emitter })
        $this.currentPc += 4
    }

    AddDataWord([uint32]$val) {
        $this.instructions.Add(@{ Pc = $this.currentPc; Emitter = { return [uint32]$val } })
        $this.currentPc += 4
    }

    AddString([string]$str) {
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($str)
        # null terminator
        $byteList = [System.Collections.Generic.List[byte]]::new($bytes)
        $byteList.Add(0)
        # Pad to multiple of 4
        while (($byteList.Count % 4) -ne 0) {
            $byteList.Add(0)
        }
        for ($i = 0; $i -lt $byteList.Count; $i += 4) {
            $b0 = [uint32]$byteList[$i]
            $b1 = [uint32]$byteList[$i+1]
            $b2 = [uint32]$byteList[$i+2]
            $b3 = [uint32]$byteList[$i+3]
            $w = [uint32]($b0 -bor ($b1 -shl 8) -bor ($b2 -shl 16) -bor ($b3 -shl 24))
            $this.AddDataWord($w)
        }
    }

    # Instruction encoders
    LUI([string]$rd, [int64]$imm) {
        $d = $this.Reg($rd)
        $this.AddInst({
            param($pc, $asm)
            $uimm = [uint32]($imm -shl 12)
            return [uint32](($uimm -band 0xFFFFF000) -bor ($d -shl 7) -bor 0x37)
        }.GetNewClosure())
    }

    ADDI([string]$rd, [string]$rs1, [int]$imm) {
        $d = $this.Reg($rd)
        $s = $this.Reg($rs1)
        $this.AddInst({
            param($pc, $asm)
            $uimm = [uint32]($imm -band 0xFFF)
            return [uint32](($uimm -shl 20) -bor ($s -shl 15) -bor ($d -shl 7) -bor 0x13)
        }.GetNewClosure())
    }

    ANDI([string]$rd, [string]$rs1, [int]$imm) {
        $d = $this.Reg($rd)
        $s = $this.Reg($rs1)
        $this.AddInst({
            param($pc, $asm)
            $uimm = [uint32]($imm -band 0xFFF)
            return [uint32](($uimm -shl 20) -bor ($s -shl 15) -bor (7 -shl 12) -bor ($d -shl 7) -bor 0x13)
        }.GetNewClosure())
    }

    SW([string]$rs2, [int]$offset, [string]$rs1) {
        $s2 = $this.Reg($rs2)
        $s1 = $this.Reg($rs1)
        $this.AddInst({
            param($pc, $asm)
            $off = [uint32]($offset -band 0xFFF)
            $imm11_5 = ($off -shr 5) -band 0x7F
            $imm4_0  = $off -band 0x1F
            return [uint32](($imm11_5 -shl 25) -bor ($s2 -shl 20) -bor ($s1 -shl 15) -bor (2 -shl 12) -bor ($imm4_0 -shl 7) -bor 0x23)
        }.GetNewClosure())
    }

    LW([string]$rd, [int]$offset, [string]$rs1) {
        $d = $this.Reg($rd)
        $s = $this.Reg($rs1)
        $this.AddInst({
            param($pc, $asm)
            $off = [uint32]($offset -band 0xFFF)
            return [uint32](($off -shl 20) -bor ($s -shl 15) -bor (2 -shl 12) -bor ($d -shl 7) -bor 0x03)
        }.GetNewClosure())
    }

    LBU([string]$rd, [int]$offset, [string]$rs1) {
        $d = $this.Reg($rd)
        $s = $this.Reg($rs1)
        $this.AddInst({
            param($pc, $asm)
            $off = [uint32]($offset -band 0xFFF)
            return [uint32](($off -shl 20) -bor ($s -shl 15) -bor (4 -shl 12) -bor ($d -shl 7) -bor 0x03)
        }.GetNewClosure())
    }

    BEQ([string]$rs1, [string]$rs2, [string]$label) {
        $s1 = $this.Reg($rs1)
        $s2 = $this.Reg($rs2)
        $this.AddInst({
            param($pc, $asm)
            $target = $asm.labels[$label]
            $offset = $target - $pc
            $uoff = [uint32]($offset -band 0x1FFE)
            $imm12   = ($uoff -shr 12) -band 0x1
            $imm10_5 = ($uoff -shr 5)  -band 0x3F
            $imm4_1  = ($uoff -shr 1)  -band 0xF
            $imm11   = ($uoff -shr 11) -band 0x1
            return [uint32](($imm12 -shl 31) -bor ($imm10_5 -shl 25) -bor ($s2 -shl 20) -bor ($s1 -shl 15) -bor (0 -shl 12) -bor ($imm4_1 -shl 8) -bor ($imm11 -shl 7) -bor 0x63)
        }.GetNewClosure())
    }

    BNE([string]$rs1, [string]$rs2, [string]$label) {
        $s1 = $this.Reg($rs1)
        $s2 = $this.Reg($rs2)
        $this.AddInst({
            param($pc, $asm)
            $target = $asm.labels[$label]
            $offset = $target - $pc
            $uoff = [uint32]($offset -band 0x1FFE)
            $imm12   = ($uoff -shr 12) -band 0x1
            $imm10_5 = ($uoff -shr 5)  -band 0x3F
            $imm4_1  = ($uoff -shr 1)  -band 0xF
            $imm11   = ($uoff -shr 11) -band 0x1
            return [uint32](($imm12 -shl 31) -bor ($imm10_5 -shl 25) -bor ($s2 -shl 20) -bor ($s1 -shl 15) -bor (1 -shl 12) -bor ($imm4_1 -shl 8) -bor ($imm11 -shl 7) -bor 0x63)
        }.GetNewClosure())
    }

    JAL([string]$rd, [string]$label) {
        $d = $this.Reg($rd)
        $this.AddInst({
            param($pc, $asm)
            $target = $asm.labels[$label]
            $offset = $target - $pc
            $uoff = [uint32]($offset -band 0x1FFFFE)
            $imm20   = ($uoff -shr 20) -band 0x1
            $imm10_1 = ($uoff -shr 1)  -band 0x3FF
            $imm11   = ($uoff -shr 11) -band 0x1
            $imm19_12= ($uoff -shr 12) -band 0xFF
            return [uint32](($imm20 -shl 31) -bor ($imm10_1 -shl 21) -bor ($imm11 -shl 20) -bor ($imm19_12 -shl 12) -bor ($d -shl 7) -bor 0x6F)
        }.GetNewClosure())
    }

    JALR([string]$rd, [string]$rs1, [int]$offset) {
        $d = $this.Reg($rd)
        $s = $this.Reg($rs1)
        $this.AddInst({
            param($pc, $asm)
            $off = [uint32]($offset -band 0xFFF)
            return [uint32](($off -shl 20) -bor ($s -shl 15) -bor ($d -shl 7) -bor 0x67)
        }.GetNewClosure())
    }

    # Pseudo-instructions
    NOP() {
        $this.ADDI("zero", "zero", 0)
    }

    RET() {
        $this.JALR("zero", "ra", 0)
    }

    J([string]$label) {
        $this.JAL("zero", $label)
    }

    LA([string]$rd, [string]$label) {
        $d = $this.Reg($rd)
        $this.AddInst({
            param($pc, $asm)
            $target = [uint32]$asm.labels[$label]
            $hi = [int32](($target + 0x800) -shr 12)
            return [uint32](($hi -shl 12) -bor ($d -shl 7) -bor 0x37)
        }.GetNewClosure())
        $this.AddInst({
            param($pc, $asm)
            $target = [uint32]$asm.labels[$label]
            $lo = [int32]($target -band 0xFFF)
            if ($lo -ge 0x800) { $lo = $lo - 0x1000 }
            $ulo = [uint32]($lo -band 0xFFF)
            return [uint32](($ulo -shl 20) -bor ($d -shl 15) -bor ($d -shl 7) -bor 0x13)
        }.GetNewClosure())
    }

    [string[]]BuildHex() {
        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $this.instructions) {
            $val = [uint32](& $item.Emitter $item.Pc $this)
            $hexStr = "{0:x8}" -f $val
            $lines.Add($hexStr)
        }
        return $lines.ToArray()
    }
}

# Assemble our complete test program
$asm = [Assembler]::new()

# Reset vector (0x00000000): Jump to main initialization
$asm.Label("entry")
$asm.JAL("zero", "main")

# Subroutine: uart_putc (char in a0)
$asm.Label("uart_putc")
$asm.LW("t0", 4, "s0")             # read UART STATUS
$asm.ANDI("t0", "t0", 1)           # check tx_full
$asm.BNE("t0", "zero", "uart_putc")# wait if tx_full
$asm.SW("a0", 0, "s0")             # write TXDATA
$asm.RET()

# Subroutine: uart_puts (str pointer in a1)
$asm.Label("uart_puts")
$asm.ADDI("sp", "sp", -16)
$asm.SW("ra", 12, "sp")
$asm.SW("a1", 8, "sp")

$asm.Label("puts_loop")
$asm.LW("a1", 8, "sp")
$asm.LBU("a0", 0, "a1")
$asm.BEQ("a0", "zero", "puts_done")
$asm.JAL("ra", "uart_putc")
$asm.LW("a1", 8, "sp")
$asm.ADDI("a1", "a1", 1)
$asm.SW("a1", 8, "sp")
$asm.JAL("zero", "puts_loop")

$asm.Label("puts_done")
$asm.LW("ra", 12, "sp")
$asm.ADDI("sp", "sp", 16)
$asm.RET()

# Main Program
$asm.Label("main")
# 1. Initialize SP = 0x10007FF0
$asm.LUI("sp", 0x10008)
$asm.ADDI("sp", "sp", -16)

# 2. UART Setup: Base 0x80000000
$asm.LUI("s0", 0x80000)
$asm.ADDI("t0", "zero", 434)
$asm.SW("t0", 8, "s0")            # BAUDDIV = 434
$asm.ADDI("t0", "zero", 3)
$asm.SW("t0", 12, "s0")           # CTRL = 3 (tx_en, rx_en)

# 3. Print Boot Message
$asm.LA("a1", "msg_boot")
$asm.JAL("ra", "uart_puts")

# 4. Program Matrix Multiplier (Base 0x80004000)
$asm.LUI("s1", 0x80004)
# DIM_MNK: M=2, N=1, K=2 -> 0x00020102
$asm.LUI("t0", 0x20)
$asm.ADDI("t0", "t0", 0x102)
$asm.SW("t0", 8, "s1")            # MAT_REG_DIM_MNK

# Write Inputs X: [1.5, -0.5] -> [0x00018000, 0xFFFF8000]
$asm.SW("zero", 20, "s1")         # MAT_REG_BUF_INDEX = 0
$asm.LUI("t0", 0x18)              # 0x00018000
$asm.SW("t0", 24, "s1")           # MAT_REG_IN_DATA
$asm.LUI("t0", 0xFFFF8)           # 0xFFFF8000
$asm.SW("t0", 24, "s1")           # MAT_REG_IN_DATA

# Write Weights W: [[2.0, 1.0], [-1.0, 3.0]]
$asm.SW("zero", 20, "s1")         # MAT_REG_BUF_INDEX = 0
$asm.LUI("t0", 0x20)              # 0x00020000
$asm.SW("t0", 28, "s1")           # MAT_REG_W_DATA
$asm.LUI("t0", 0x10)              # 0x00010000
$asm.SW("t0", 28, "s1")           # MAT_REG_W_DATA
$asm.LUI("t0", 0xFFFF0)           # 0xFFFF0000
$asm.SW("t0", 28, "s1")           # MAT_REG_W_DATA
$asm.LUI("t0", 0x30)              # 0x00030000
$asm.SW("t0", 28, "s1")           # MAT_REG_W_DATA

# Write Biases B: [0.25, 0.50] -> [0x00004000, 0x00008000]
$asm.SW("zero", 20, "s1")         # MAT_REG_BUF_INDEX = 0
$asm.LUI("t0", 0x4)               # 0x00004000
$asm.SW("t0", 32, "s1")           # MAT_REG_BIAS_DATA
$asm.LUI("t0", 0x8)               # 0x00008000
$asm.SW("t0", 32, "s1")           # MAT_REG_BIAS_DATA

# Start Matrix Multiplier
$asm.ADDI("t0", "zero", 1)
$asm.SW("t0", 0, "s1")            # MAT_REG_CTRL = 1

# 5. Wait for Matrix Multiplier Completion
$asm.Label("wait_mat")
$asm.LW("t0", 4, "s1")            # MAT_REG_STATUS
$asm.ANDI("t0", "t0", 1)          # bit 0: done
$asm.BEQ("t0", "zero", "wait_mat")

# 6. Read Raw Outputs from Matrix Multiplier
$asm.SW("zero", 20, "s1")         # MAT_REG_BUF_INDEX = 0
$asm.LW("s2", 36, "s1")           # Y[0] (expect 0x0002C000)
$asm.LW("s3", 36, "s1")           # Y[1] (expect 0xFFFD8000)

# 7. Configure Activation Unit (Base 0x80005000)
$asm.LUI("s1", 0x80005)
$asm.ADDI("t0", "zero", 2)
$asm.SW("t0", 8, "s1")            # ACT_REG_VEC_LEN = 2
$asm.SW("zero", 16, "s1")         # ACT_REG_BUF_INDEX = 0
$asm.SW("s2", 20, "s1")           # ACT_REG_IN_DATA = Y[0]
$asm.SW("s3", 20, "s1")           # ACT_REG_IN_DATA = Y[1]

# Start Activation Unit with ReLU (func = 00, start = 1 -> CTRL = 1)
$asm.ADDI("t0", "zero", 1)
$asm.SW("t0", 0, "s1")            # ACT_REG_CTRL = 1

# 8. Wait for Activation Unit Completion
$asm.Label("wait_act")
$asm.LW("t0", 4, "s1")            # ACT_REG_STATUS
$asm.ANDI("t0", "t0", 1)          # bit 0: done
$asm.BEQ("t0", "zero", "wait_act")

# 9. Read Final Activated Outputs
$asm.SW("zero", 16, "s1")         # ACT_REG_BUF_INDEX = 0
$asm.LW("s4", 24, "s1")           # Z[0] (expect 0x0002C000)
$asm.LW("s5", 24, "s1")           # Z[1] (expect 0x00000000)

# 10. Check results
$asm.LUI("t0", 0x2C)              # 0x0002C000
$asm.BNE("s4", "t0", "test_fail")
$asm.BNE("s5", "zero", "test_fail")

# PASS
$asm.Label("test_pass")
$asm.LA("a1", "msg_pass")
$asm.JAL("ra", "uart_puts")
$asm.LUI("s1", 0x80002)           # GPIO
$asm.ADDI("t0", "zero", -1)
$asm.SW("t0", 8, "s1")            # GPIO DIR = 0xFFFF
$asm.LUI("t0", 0xAA)
$asm.ADDI("t0", "t0", 0x55)
$asm.SW("t0", 4, "s1")            # GPIO OUT = 0xAA55
$asm.JAL("zero", "halt")

# FAIL
$asm.Label("test_fail")
$asm.LA("a1", "msg_fail")
$asm.JAL("ra", "uart_puts")
$asm.LUI("s1", 0x80002)
$asm.ADDI("t0", "zero", -1)
$asm.SW("t0", 8, "s1")
$asm.LUI("t0", 0xDEAD)
$asm.SW("t0", 4, "s1")

$asm.Label("halt")
$asm.JAL("zero", "halt")

# String Constants
$asm.Label("msg_boot")
$asm.AddString("`n[SoC] VeeR-EL2 RISC-V Neural Network Inference Accelerator Active!`n")

$asm.Label("msg_pass")
$asm.AddString("`n====================================================`n[SoC] Output Vector Verified!`n[SoC] === TEST PASSED ===`n====================================================`n")

$asm.Label("msg_fail")
$asm.AddString("`n[SoC] === TEST FAILED ===`n")

# Build and write hex lines
$hexLines = $asm.BuildHex()
$outPath = "NN_Accelerator_SoC\sw\main.hex"
[System.IO.File]::WriteAllLines($outPath, $hexLines)

Write-Host "Generated $($hexLines.Length) 32-bit instructions into $outPath"
