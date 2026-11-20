// SPDX-License-Identifier: Apache-2.0
// UART VIP Driver
// Generates cycle-accurate protocol-level serial frames on uart_rx.
// Standard 8-N-1 format: Start (LOW), 8 data bits LSB first, Stop (HIGH).

`ifndef UART_VIP_DRIVER_SV
`define UART_VIP_DRIVER_SV

class uart_vip_driver extends uvm_driver #(uart_vip_item);

    virtual uart_vip_if vif;

    `uvm_component_utils(uart_vip_driver)

    function new(string name = "uart_vip_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (vif == null) begin
            void'(uvm_config_db#(virtual uart_vip_if)::get(this, "", "uart_vip_vif", vif));
        end
    endfunction

    task run_phase(uvm_phase phase);
        if (vif == null) begin
            `uvm_fatal(get_type_name(), "Virtual interface vif is not set!")
        end

        // Ensure UART line starts in idle state (HIGH)
        vif.uart_rx <= 1'b1;

        // Wait for reset release
        `uvm_info(get_type_name(), "Waiting for reset release...", UVM_LOW)
        wait (vif.rst_n === 1'b1);
        repeat (20) @(posedge vif.clk);
        `uvm_info(get_type_name(), "Reset released. Driver ready.", UVM_LOW)

        forever begin
            seq_item_port.get_next_item(req);
            drive_frame(req);
            seq_item_port.item_done();
        end
    endtask

    // -------------------------------------------------------------------------
    // drive_frame: Serializes req into standard UART frame
    // -------------------------------------------------------------------------
    virtual task drive_frame(uart_vip_item item);
        int unsigned bit_cycles;
        time start_time, end_time;

        if (item.baud_rate > 0 && item.clk_freq_hz > 0) begin
            bit_cycles = item.clk_freq_hz / item.baud_rate;
        end else begin
            bit_cycles = 434; // Default for 50MHz @ 115200 baud
        end

        start_time = $time;
        `uvm_info(get_type_name(),
            $sformatf({"=== BEGIN UART FRAME TX ===\n",
                    "  Data       : 0x%02X (%08b, LSB first: %0b,%0b,%0b,%0b,%0b,%0b,%0b,%0b)\n",
                    "  Baud Rate  : %0d baud\n",
                    "  Bit Cycles : %0d clk ticks (%0.2f us @ 50MHz)\n",
                    "  Format     : %0d-N-%0d\n",
                    "  Start Time : %0t"},
                    item.data, item.data,
                    item.data[0], item.data[1], item.data[2], item.data[3],
                    item.data[4], item.data[5], item.data[6], item.data[7],
                    item.baud_rate, bit_cycles, (bit_cycles * 20.0) / 1000.0,
                    item.data_bits, item.stop_bits, start_time), UVM_LOW)

        // 1. START BIT (LOW)
        @(posedge vif.clk);
        vif.uart_rx <= 1'b0;
        `uvm_info(get_type_name(), $sformatf("Driving START bit (0) at %0t for %0d cycles", $time, bit_cycles), UVM_MEDIUM)
        repeat (bit_cycles) @(posedge vif.clk);

        // 2. DATA BITS (LSB first)
        for (int i = 0; i < item.data_bits; i++) begin
            vif.uart_rx <= item.data[i];
            `uvm_info(get_type_name(),
                $sformatf("Driving DATA bit %0d = %0b at %0t for %0d cycles", i, item.data[i], $time, bit_cycles), UVM_MEDIUM)
            repeat (bit_cycles) @(posedge vif.clk);
        end

        // 3. OPTIONAL PARITY BIT
        if (item.parity_en) begin
            bit parity_val = ^item.data ^ item.parity_type;
            vif.uart_rx <= parity_val;
            `uvm_info(get_type_name(),
                $sformatf("Driving PARITY bit = %0b at %0t", parity_val, $time), UVM_MEDIUM)
            repeat (bit_cycles) @(posedge vif.clk);
        end

        // 4. STOP BIT (HIGH)
        vif.uart_rx <= 1'b1;
        `uvm_info(get_type_name(),
            $sformatf("Driving STOP bit (1) at %0t for %0d cycles", $time, item.stop_bits * bit_cycles), UVM_MEDIUM)
        repeat (item.stop_bits * bit_cycles) @(posedge vif.clk);

        // 5. POST-FRAME IDLE GAP (HIGH)
        vif.uart_rx <= 1'b1;
        repeat (bit_cycles) @(posedge vif.clk);

        end_time = $time;
        `uvm_info(get_type_name(),
            $sformatf("=== END UART FRAME TX === (Duration: %0t to %0t = %0.2f us)\n",
                start_time, end_time, (end_time - start_time) / 1000.0), UVM_LOW)
    endtask

endclass : uart_vip_driver

`endif // UART_VIP_DRIVER_SV
