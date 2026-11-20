// ============================================================================
// Module Name: function_selector
// Project:     RISC-V Based SoC for Lightweight NN Inference Acceleration
// Description: Multiplexes activation function outputs based on func_sel:
//              2'b00: ReLU
//              2'b01: Sigmoid
//              2'b10: Tanh
//              2'b11: Bypass (Linear)
// ============================================================================

`timescale 1ns / 1ps

module function_selector #(
    parameter DATA_WIDTH = 32
)(
    input  wire [1:0]                     func_sel,

    input  wire signed [DATA_WIDTH-1:0]   relu_data,
    input  wire                           relu_valid,

    input  wire signed [DATA_WIDTH-1:0]   sigmoid_data,
    input  wire                           sigmoid_valid,

    input  wire signed [DATA_WIDTH-1:0]   tanh_data,
    input  wire                           tanh_valid,

    input  wire signed [DATA_WIDTH-1:0]   bypass_data,
    input  wire                           bypass_valid,

    output reg  signed [DATA_WIDTH-1:0]   selected_data,
    output reg                            selected_valid
);

    always @(*) begin
        case (func_sel)
            2'b00: begin
                selected_data  = relu_data;
                selected_valid = relu_valid;
            end
            2'b01: begin
                selected_data  = sigmoid_data;
                selected_valid = sigmoid_valid;
            end
            2'b10: begin
                selected_data  = tanh_data;
                selected_valid = tanh_valid;
            end
            2'b11: begin
                selected_data  = bypass_data;
                selected_valid = bypass_valid;
            end
            default: begin
                selected_data  = relu_data;
                selected_valid = relu_valid;
            end
        endcase
    end

endmodule
