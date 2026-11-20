// SPDX-License-Identifier: Apache-2.0
// UART VIP Monitor
// Observes uart_rx line, samples bits at midpoint, reconstructs frame,
// and broadcasts reconstructed transaction via analysis port.

`ifndef UART_VIP_MONITOR_SV
`define UART_VIP_MONITOR_SV

class uart_vip_monitor extends uvm_monitor;

    virtual uart_vip_if vif;
    uvm_analysis_port #(uart_vip_item) ap;

    `uvm_component_utils(uart_vip_monitor)

    function new(string name = "uart_vip_monitor", uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
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

        // Wait for reset release
        wait (vif.rst_n === 1'b1);
        repeat (20) @(posedge vif.clk);
        `uvm_info(get_type_name(), "Reset released. Monitor active.", UVM_LOW)

        forever begin
            collect_frame();
        end
    endtask

    // -------------------------------------------------------------------------
    // collect_frame: Midpoint sampling & reconstruction of UART frame
    // -------------------------------------------------------------------------
    virtual task collect_frame();
        int unsigned bit_cycles = 434; // 115200 baud @ 50 MHz
        logic [7:0]  collected_data;
        bit          stop_bit_val;
        time         frame_start_time;

        // 1. Wait for line to be HIGH (idle) before detecting start bit
        while (vif.uart_rx !== 1'b1) begin
            @(posedge vif.clk);
        end

        // 2. Wait for falling edge indicating Start bit
        @(negedge vif.uart_rx);
        frame_start_time = $time;
        `uvm_info(get_type_name(),
            $sformatf("Detected falling edge on uart_rx at %0t (START bit initiated)", frame_start_time), UVM_LOW)

        // 3. Wait to start bit midpoint (bit_cycles / 2)
        repeat (bit_cycles / 2) @(posedge vif.clk);
        if (vif.uart_rx !== 1'b0) begin
            `uvm_warning(get_type_name(),
                $sformatf("Glitch on start bit at %0t (expected 0, got %0b) — ignoring frame", $time, vif.uart_rx))
            return;
        end
        `uvm_info(get_type_name(),
            $sformatf("Verified valid START bit (0) at midpoint %0t", $time), UVM_MEDIUM)

        // 4. Sample 8 data bits at their midpoints (LSB first)
        for (int i = 0; i < 8; i++) begin
            repeat (bit_cycles) @(posedge vif.clk);
            collected_data[i] = vif.uart_rx;
            `uvm_info(get_type_name(),
                $sformatf("Sampled bit %0d = %0b at midpoint %0t", i, collected_data[i], $time), UVM_MEDIUM)
        end

        // 5. Sample Stop bit at midpoint
        repeat (bit_cycles) @(posedge vif.clk);
        stop_bit_val = vif.uart_rx;
        if (stop_bit_val !== 1'b1) begin
            `uvm_error(get_type_name(),
                $sformatf("FRAMING ERROR: Stop bit is %0b (expected 1) at %0t", stop_bit_val, $time))
        end else begin
            `uvm_info(get_type_name(),
                $sformatf("Verified valid STOP bit (1) at midpoint %0t", $time), UVM_MEDIUM)
        end

        // 6. Wait for DUT FSM to process stop bit and commit data into FIFO
        repeat (200) @(posedge vif.clk);

        // 7. Create transaction and broadcast via analysis port
        begin
            uart_vip_item item = uart_vip_item::type_id::create("item");
            item.data        = collected_data;
            item.baud_rate   = 115200;
            item.clk_freq_hz = 50_000_000;
            item.data_bits   = 8;
            item.stop_bits   = 1;
            item.parity_en   = 0;

            `uvm_info(get_type_name(),
                $sformatf({"=== UART MONITOR RECONSTRUCTED FRAME ===\n",
                        "  Data       : 0x%02X (%08b, ASCII='%c')\n",
                        "  Framing    : %s\n",
                        "  Duration   : %0t to %0t\n"},
                        collected_data, collected_data,
                        (collected_data >= 32 && collected_data < 127) ? collected_data : "?",
                        (stop_bit_val === 1'b1) ? "VALID (Stop=1)" : "ERROR (Stop=0)",
                        frame_start_time, $time), UVM_LOW)

            ap.write(item);
        end
    endtask

endclass : uart_vip_monitor

`endif // UART_VIP_MONITOR_SV
