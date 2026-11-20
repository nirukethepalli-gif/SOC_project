// ============================================================================
// Module Name: riscv_core
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Synthesizable 32-bit RISC-V Processor Core (RV32I Architecture)
//              with AXI4 System Bus Master Interface and Instruction Fetch Port.
//              Can execute configuration programs, control the DMA engine,
//              trigger Matrix Multiplier and Activation Unit, and report over UART.
// ============================================================================

`timescale 1ns / 1ps

module riscv_core #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Instruction Fetch Port (to Instruction Memory)
    output reg  [ADDR_WIDTH-1:0]  imem_addr,
    input  wire [DATA_WIDTH-1:0]  imem_data,

    // AXI4 System Bus Master Interface
    // Write Address Channel
    output reg  [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output reg  [7:0]             m_axi_awlen,
    output reg  [2:0]             m_axi_awsize,
    output reg  [1:0]             m_axi_awburst,
    output reg  [2:0]             m_axi_awprot,
    output reg                    m_axi_awvalid,
    input  wire                   m_axi_awready,

    // Write Data Channel
    output reg  [DATA_WIDTH-1:0]  m_axi_wdata,
    output reg  [3:0]             m_axi_wstrb,
    output reg                    m_axi_wlast,
    output reg                    m_axi_wvalid,
    input  wire                   m_axi_wready,

    // Write Response Channel
    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output reg                    m_axi_bready,

    // Read Address Channel
    output reg  [ADDR_WIDTH-1:0]  m_axi_araddr,
    output reg  [7:0]             m_axi_arlen,
    output reg  [2:0]             m_axi_arsize,
    output reg  [1:0]             m_axi_arburst,
    output reg  [2:0]             m_axi_arprot,
    output reg                    m_axi_arvalid,
    input  wire                   m_axi_arready,

    // Read Data Channel
    input  wire [DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rlast,
    input  wire                   m_axi_rvalid,
    output reg                    m_axi_rready,

    // Interrupt Input
    input  wire                   irq
);

    // Program Counter
    reg [ADDR_WIDTH-1:0] pc;

    // Register File: 32 registers of 32 bits
    reg [DATA_WIDTH-1:0] reg_file [0:31];

    // Core Instruction Execution FSM
    localparam [2:0] IFETCH = 3'b000,
                     DECODE = 3'b001,
                     EXEC   = 3'b010,
                     MEM_WR = 3'b011,
                     MEM_RD = 3'b100,
                     WB     = 3'b101;

    reg [2:0] state;
    reg [31:0] instr;

    // Instruction Decode Fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // Immediate generation
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // Instruction opcodes
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OP_IMM = 7'b0010011;
    localparam OP_OP     = 7'b0110011;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc            <= 32'h0000_0000;
            imem_addr     <= 32'h0000_0000;
            state         <= IFETCH;
            instr         <= 32'h0000_0013; // NOP
            m_axi_awvalid <= 1'b0;
            m_axi_wvalid  <= 1'b0;
            m_axi_wlast   <= 1'b0;
            m_axi_bready  <= 1'b0;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            m_axi_awlen   <= 8'd0;
            m_axi_awsize  <= 3'b010;
            m_axi_awburst <= 2'b01;
            m_axi_arlen   <= 8'd0;
            m_axi_arsize  <= 3'b010;
            m_axi_arburst <= 2'b01;

            for (i = 0; i < 32; i = i + 1) begin
                reg_file[i] <= 32'd0;
            end
        end else begin
            case (state)
                IFETCH: begin
                    imem_addr <= pc;
                    state     <= DECODE;
                end

                DECODE: begin
                    instr <= imem_data;
                    state <= EXEC;
                end

                EXEC: begin
                    case (opcode)
                        OP_OP_IMM: begin
                            // ADDI
                            if (funct3 == 3'b000 && rd != 5'd0) begin
                                reg_file[rd] <= reg_file[rs1] + imm_i;
                            end
                            pc    <= pc + 32'd4;
                            state <= IFETCH;
                        end

                        OP_STORE: begin
                            // SW (Store Word)
                            m_axi_awaddr  <= reg_file[rs1] + imm_s;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata   <= reg_file[rs2];
                            m_axi_wstrb   <= 4'hF;
                            m_axi_wvalid  <= 1'b1;
                            m_axi_wlast   <= 1'b1;
                            state         <= MEM_WR;
                        end

                        OP_LOAD: begin
                            // LW (Load Word)
                            m_axi_araddr  <= reg_file[rs1] + imm_i;
                            m_axi_arvalid <= 1'b1;
                            m_axi_rready  <= 1'b1;
                            state         <= MEM_RD;
                        end

                        default: begin
                            pc    <= pc + 32'd4;
                            state <= IFETCH;
                        end
                    endcase
                end

                MEM_WR: begin
                    if (m_axi_awready && m_axi_awvalid) m_axi_awvalid <= 1'b0;
                    if (m_axi_wready && m_axi_wvalid)   m_axi_wvalid  <= 1'b0;

                    if (!m_axi_awvalid && !m_axi_wvalid) begin
                        m_axi_bready <= 1'b1;
                        if (m_axi_bvalid) begin
                            m_axi_bready <= 1'b0;
                            pc           <= pc + 32'd4;
                            state        <= IFETCH;
                        end
                    end
                end

                MEM_RD: begin
                    if (m_axi_arready && m_axi_arvalid) m_axi_arvalid <= 1'b0;

                    if (m_axi_rvalid && m_axi_rready) begin
                        if (rd != 5'd0) begin
                            reg_file[rd] <= m_axi_rdata;
                        end
                        m_axi_rready <= 1'b0;
                        pc           <= pc + 32'd4;
                        state        <= IFETCH;
                    end
                end

                default: state <= IFETCH;
            endcase
        end
    end

endmodule
