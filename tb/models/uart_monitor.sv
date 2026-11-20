// SPDX-License-Identifier: Apache-2.0
// Behavioural UART Monitor for testbench console output
// Decodes 8-N-1 UART output from soc_top and displays strings

`timescale 1ns/1ps

module uart_monitor #(
    parameter int CLK_FREQ_HZ = 50_000_000,
    parameter int BAUD_RATE   = 115_200
)(
    input logic clk,
    input logic rst_n,
    input logic uart_tx
);

    real bit_period_ns;
    string line_buf = "";

    initial begin
        bit_period_ns = (1.0e9 / real'(BAUD_RATE));
    end

    // Monitor process
    initial begin
        logic [7:0] rx_byte;
        forever begin
            // Wait for start bit (falling edge)
            @(negedge uart_tx);
            #(bit_period_ns * 1.5); // Sample middle of first data bit

            for (int i = 0; i < 8; i++) begin
                rx_byte[i] = uart_tx;
                #(bit_period_ns);
            end

            // Middle of stop bit
            if (rx_byte == 8'h0A) begin // Newline '\n'
                $display("[UART CONSOLE] %s", line_buf);
                line_buf = "";
            end else if (rx_byte != 8'h0D) begin // Ignore '\r'
                line_buf = {line_buf, string'(rx_byte)};
            end
        end
    end

endmodule

