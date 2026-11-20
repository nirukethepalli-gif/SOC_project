// SPDX-License-Identifier: Apache-2.0
// Unit Testbench: tb_matrix_multiplier.sv
// Target Simulator: Synopsys VCS
// Verifies Custom IP 1: Matrix Multiplier at base 0x8000_4000

`timescale 1ns/1ps

module tb_matrix_multiplier;

    localparam time CLK_PERIOD = 10ns;
    logic clk;
    logic rst_n;

    // AXI4-Lite Slave Ports
    logic [31:0] s_awaddr;
    logic [2:0]  s_awprot;
    logic        s_awvalid;
    logic        s_awready;
    logic [31:0] s_wdata;
    logic [3:0]  s_wstrb;
    logic        s_wvalid;
    logic        s_wready;
    logic [1:0]  s_bresp;
    logic        s_bvalid;
    logic        s_bready;
    logic [31:0] s_araddr;
    logic [2:0]  s_arprot;
    logic        s_arvalid;
    logic        s_arready;
    logic [31:0] s_rdata;
    logic [1:0]  s_rresp;
    logic        s_rvalid;
    logic        s_rready;

    // DMA loading ports (tied low for unit test)
    logic        dma_in_wr_en;
    logic [7:0]  dma_in_wr_addr;
    logic [31:0] dma_in_wr_data;
    logic        dma_w_wr_en;
    logic [9:0]  dma_w_wr_addr;
    logic [31:0] dma_w_wr_data;
    logic        dma_bias_wr_en;
    logic [7:0]  dma_bias_wr_addr;
    logic [31:0] dma_bias_wr_data;
    logic        dma_out_rd_en;
    logic [7:0]  dma_out_rd_addr;
    logic [31:0] dma_out_rd_data;

    // Streaming port
    logic [31:0] stream_act_data;
    logic        stream_act_valid;
    logic        stream_act_ready;

    // Status
    logic        busy;
    logic        done;
    logic        irq;

    int error_count = 0;

    // Q16.16 Constants
    localparam signed [31:0] Q_ONE_HALF  = 32'h0000_8000; //  0.5
    localparam signed [31:0] Q_ONE       = 32'h0001_0000; //  1.0
    localparam signed [31:0] Q_ONE_PT_5  = 32'h0001_8000; //  1.5
    localparam signed [31:0] Q_TWO       = 32'h0002_0000; //  2.0
    localparam signed [31:0] Q_THREE     = 32'h0003_0000; //  3.0
    localparam signed [31:0] Q_SIX       = 32'h0006_0000; //  6.0
    localparam signed [31:0] Q_QUARTER   = 32'h0000_4000; //  0.25
    localparam signed [31:0] Q_NEG_1_PT5 = -Q_ONE_PT_5;   // -1.5
    localparam signed [31:0] Q_NEG_HALF  = -Q_ONE_HALF;   // -0.5
    localparam signed [31:0] Q_NEG_0_75  = -32'h0000_C000;// -0.75

    // DUT Instantiation
    matrix_multiplier u_dut (
        .aclk             (clk),
        .aresetn          (rst_n),
        .s_awaddr         (s_awaddr),
        .s_awprot         (s_awprot),
        .s_awvalid        (s_awvalid),
        .s_awready        (s_awready),
        .s_wdata          (s_wdata),
        .s_wstrb          (s_wstrb),
        .s_wvalid         (s_wvalid),
        .s_wready         (s_wready),
        .s_bresp          (s_bresp),
        .s_bvalid         (s_bvalid),
        .s_bready         (s_bready),
        .s_araddr         (s_araddr),
        .s_arprot         (s_arprot),
        .s_arvalid        (s_arvalid),
        .s_arready        (s_arready),
        .s_rdata          (s_rdata),
        .s_rresp          (s_rresp),
        .s_rvalid         (s_rvalid),
        .s_rready         (s_rready),
        .dma_in_wr_en     (dma_in_wr_en),
        .dma_in_wr_addr   (dma_in_wr_addr),
        .dma_in_wr_data   (dma_in_wr_data),
        .dma_w_wr_en      (dma_w_wr_en),
        .dma_w_wr_addr    (dma_w_wr_addr),
        .dma_w_wr_data    (dma_w_wr_data),
        .dma_bias_wr_en   (dma_bias_wr_en),
        .dma_bias_wr_addr (dma_bias_wr_addr),
        .dma_bias_wr_data (dma_bias_wr_data),
        .dma_out_rd_en    (dma_out_rd_en),
        .dma_out_rd_addr  (dma_out_rd_addr),
        .dma_out_rd_data  (dma_out_rd_data),
        .stream_act_data  (stream_act_data),
        .stream_act_valid (stream_act_valid),
        .stream_act_ready (stream_act_ready),
        .busy             (busy),
        .done             (done),
        .irq              (irq)
    );

    // Clock Generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // AXI Tasks
    task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        s_awaddr  <= addr;
        s_awprot  <= 3'b000;
        s_awvalid <= 1'b1;
        s_wdata   <= data;
        s_wstrb   <= 4'hF;
        s_wvalid  <= 1'b1;
        s_bready  <= 1'b1;
        @(posedge clk);
        while (!(s_awready && s_wready)) @(posedge clk);
        s_awvalid <= 1'b0;
        s_wvalid  <= 1'b0;
        while (!s_bvalid) @(posedge clk);
        @(posedge clk);
        s_bready  <= 1'b0;
    endtask

    task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        s_araddr  <= addr;
        s_arprot  <= 3'b000;
        s_arvalid <= 1'b1;
        s_rready  <= 1'b1;
        @(posedge clk);
        while (!s_arready) @(posedge clk);
        s_arvalid <= 1'b0;
        while (!s_rvalid) @(posedge clk);
        data = s_rdata;
        @(posedge clk);
        s_rready  <= 1'b0;
    endtask

    logic [31:0] rdata;
    logic signed [31:0] y0_res, y1_res;

    initial begin
        $display("==========================================================");
        $display(" [RUN] tb_matrix_multiplier (VCS Synopsys Target)");
        $display("==========================================================");

        clk   = 0;
        rst_n = 0;
        s_awaddr = '0; s_awprot = '0; s_awvalid = 0;
        s_wdata = '0; s_wstrb = '0; s_wvalid = 0; s_bready = 0;
        s_araddr = '0; s_arprot = '0; s_arvalid = 0; s_rready = 0;
        dma_in_wr_en = 0; dma_in_wr_addr = 0; dma_in_wr_data = 0;
        dma_w_wr_en = 0; dma_w_wr_addr = 0; dma_w_wr_data = 0;
        dma_bias_wr_en = 0; dma_bias_wr_addr = 0; dma_bias_wr_data = 0;
        dma_out_rd_en = 0; dma_out_rd_addr = 0;
        stream_act_ready = 1'b1;

        #(CLK_PERIOD * 4);
        rst_n = 1;
        #(CLK_PERIOD * 4);

        // Configure Dimensions: M=2, N=1, K=2 -> {M[23:16], N[15:8], K[7:0]} = 0x0002_0102
        axi_write(32'h8000_4008, 32'h0002_0102);

        // Load Input Vector X = [1.0, 2.0]
        axi_write(32'h8000_4014, 32'd0);
        axi_write(32'h8000_4020, Q_ONE);
        axi_write(32'h8000_4020, Q_TWO);

        // Load Weight Matrix W = [[2.0, -1.5], [0.5, 3.0]]
        axi_write(32'h8000_4014, 32'd0);
        axi_write(32'h8000_4024, Q_TWO);
        axi_write(32'h8000_4024, Q_NEG_1_PT5);
        axi_write(32'h8000_4024, Q_ONE_HALF);
        axi_write(32'h8000_4024, Q_THREE);

        // Load Bias Vector B = [0.25, -0.5]
        axi_write(32'h8000_4014, 32'd0);
        axi_write(32'h8000_4028, Q_QUARTER);
        axi_write(32'h8000_4028, Q_NEG_HALF);

        // Start Matrix Multiplier
        axi_write(32'h8000_4000, 32'h0000_0001);

        // Poll Done
        rdata = '0;
        while ((rdata & 32'h1) == 0) begin
            axi_read(32'h8000_4004, rdata);
            #(CLK_PERIOD * 2);
        end

        // Read Output Elements
        axi_write(32'h8000_4014, 32'd0);
        axi_read(32'h8000_402C, rdata); y0_res = rdata;
        axi_write(32'h8000_4014, 32'd1);
        axi_read(32'h8000_402C, rdata); y1_res = rdata;

        $display(" Y[0] = 0x%08X (Expected: 0x%08X, -0.75)", y0_res, Q_NEG_0_75);
        $display(" Y[1] = 0x%08X (Expected: 0x%08X, +6.00)", y1_res, Q_SIX);

        if (y0_res !== Q_NEG_0_75) error_count++;
        if (y1_res !== Q_SIX)      error_count++;

        if (error_count == 0) begin
            $display("=== [TEST] tb_matrix_multiplier: PASS ===");
        end else begin
            $display("=== [TEST] tb_matrix_multiplier: FAIL (%0d errors) ===", error_count);
        end

        #(CLK_PERIOD * 10);
        $finish;
    end

endmodule
