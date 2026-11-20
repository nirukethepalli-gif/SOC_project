// SPDX-License-Identifier: Apache-2.0
// AXI4-Lite Address Decoder (axi4lite_decoder)
// Custom Address Mapping for RISC-V Neural Network Accelerator SoC:
//   SLV 0: IMEM               (0x0000_0000 - 0x0000_7FFF, 32 KB)
//   SLV 1: DMEM               (0x1000_0000 - 0x1000_7FFF, 32 KB)
//   SLV 2: UART               (0x8000_0000 - 0x8000_0FFF, 4 KB)
//   SLV 3: Timer              (0x8000_1000 - 0x8000_1FFF, 4 KB)
//   SLV 4: GPIO               (0x8000_2000 - 0x8000_2FFF, 4 KB)
//   SLV 5: DMA Controller IP  (0x8000_3000 - 0x8000_3FFF, 4 KB)
//   SLV 6: Matrix Multiplier  (0x8000_4000 - 0x8000_4FFF, 4 KB)
//   SLV 7: Activation Unit IP (0x8000_5000 - 0x8000_5FFF, 4 KB)
//   SLV 8: Error Slave (DECERR for all unmapped accesses)

`timescale 1ns/1ps

module axi4lite_decoder #(
    parameter int NSLV = 9
)(
    input  logic [31:0]      addr,
    output logic [NSLV-1:0]  sel,
    output logic             dec_err
);

    // Slave indices
    localparam int SLV_IMEM  = 0;
    localparam int SLV_DMEM  = 1;
    localparam int SLV_UART  = 2;
    localparam int SLV_TIMER = 3;
    localparam int SLV_GPIO  = 4;
    localparam int SLV_DMA   = 5;
    localparam int SLV_MAT   = 6;
    localparam int SLV_ACT   = 7;
    localparam int SLV_ERR   = 8;

    always_comb begin
        sel     = '0;
        dec_err = 1'b0;

        case (addr[31:28])
            4'h0: begin // IMEM (0x0000_0000 - 0x0000_7FFF)
                sel[SLV_IMEM] = 1'b1;
            end

            4'h1: begin // DMEM (0x1000_0000 - 0x1000_7FFF)
                sel[SLV_DMEM] = 1'b1;
            end

            4'h8: begin // Peripherals & Accelerators (0x8000_xxxx)
                case (addr[15:12])
                    4'h0: sel[SLV_UART]  = 1'b1; // 0x8000_0000
                    4'h1: sel[SLV_TIMER] = 1'b1; // 0x8000_1000
                    4'h2: sel[SLV_GPIO]  = 1'b1; // 0x8000_2000
                    4'h3: sel[SLV_DMA]   = 1'b1; // 0x8000_3000 (DMA Controller)
                    4'h4: sel[SLV_MAT]   = 1'b1; // 0x8000_4000 (Matrix Multiplier)
                    4'h5: sel[SLV_ACT]   = 1'b1; // 0x8000_5000 (Activation Unit)
                    default: begin
                        sel[SLV_ERR] = 1'b1;
                        dec_err      = 1'b1;
                    end
                endcase
            end

            default: begin
                sel[SLV_ERR] = 1'b1;
                dec_err      = 1'b1;
            end
        endcase
    end

endmodule
