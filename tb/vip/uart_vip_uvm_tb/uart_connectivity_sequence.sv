// SPDX-License-Identifier: Apache-2.0
// UART Connectivity Sequence
// Transmits the test transaction 8'hA5 at 115200 baud, 8-N-1 into the DUT.

`ifndef UART_CONNECTIVITY_SEQUENCE_SV
`define UART_CONNECTIVITY_SEQUENCE_SV

class uart_connectivity_sequence extends uvm_sequence #(uart_vip_item);

    `uvm_object_utils(uart_connectivity_sequence)

    logic [7:0] data = 8'hA5;
    int unsigned baud_rate = 115200;
    int unsigned clk_freq_hz = 50_000_000;

    function new(string name = "uart_connectivity_sequence");
        super.new(name);
    endfunction

    virtual task body();
        uart_vip_item req;
        `uvm_info(get_type_name(),
            $sformatf("Starting UART Connectivity Sequence: data=0x%02X, baud=%0d, 8-N-1",
                data, baud_rate), UVM_LOW)

        req = uart_vip_item::type_id::create("req");
        start_item(req);

        if (!req.randomize() with {
            req.data        == local::data;
            req.baud_rate   == local::baud_rate;
            req.clk_freq_hz == local::clk_freq_hz;
            req.data_bits   == 8;
            req.stop_bits   == 1;
            req.parity_en   == 0;
            req.parity_type == 0;
        }) begin
            `uvm_fatal(get_type_name(), "Randomization failed for uart_vip_item!")
        end

        `uvm_info(get_type_name(),
            $sformatf("Sending item to driver: %s", req.convert2string()), UVM_LOW)
        finish_item(req);

        `uvm_info(get_type_name(),
            $sformatf("UART Connectivity Sequence completed for data=0x%02X", data), UVM_LOW)
    endtask

endclass : uart_connectivity_sequence

`endif // UART_CONNECTIVITY_SEQUENCE_SV
