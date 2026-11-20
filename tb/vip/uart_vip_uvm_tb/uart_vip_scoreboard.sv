// SPDX-License-Identifier: Apache-2.0
// UART VIP Scoreboard
// Performs end-to-end verification of UART transactions:
// 1. Compares expected data against monitor-decoded data.
// 2. Probes the actual SoC DUT UART hardware FIFO and status registers.
// 3. Verifies framing integrity and absence of errors.

`ifndef UART_VIP_SCOREBOARD_SV
`define UART_VIP_SCOREBOARD_SV

class uart_vip_scoreboard extends uvm_scoreboard;

    virtual uart_vip_if vif;
    uvm_analysis_imp #(uart_vip_item, uart_vip_scoreboard) mon_export;

    logic [7:0]  expected_data   = 8'hA5;
    int unsigned match_count     = 0;
    int unsigned mismatch_count  = 0;
    int unsigned total_received  = 0;

    `uvm_component_utils(uart_vip_scoreboard)

    function new(string name = "uart_vip_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        mon_export = new("mon_export", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (vif == null) begin
            void'(uvm_config_db#(virtual uart_vip_if)::get(this, "", "uart_vip_vif", vif));
        end
    endfunction

    // -------------------------------------------------------------------------
    // write: Callback from monitor analysis port
    // -------------------------------------------------------------------------
    virtual function void write(uart_vip_item item);
        bit mon_data_match;
        bit dut_fifo_match;
        bit dut_wptr_match;
        bit framing_match;
        bit overrun_match;
        bit overall_pass;
        string msg;

        logic [7:0] probed_dut_fifo0;
        logic [7:0] probed_dut_last_rx;
        logic       probed_dut_committed;
        logic [4:0] probed_dut_count;
        logic [3:0] probed_dut_wptr;
        logic [3:0] probed_dut_rptr;
        logic       probed_dut_frame_err;
        logic       probed_dut_overrun;

        total_received++;

        // 1. Check Monitor Decoded Data
        mon_data_match = (item.data === expected_data);

        // 2. Probe SoC DUT UART Hardware State
        if (vif != null) begin
            probed_dut_fifo0     = vif.dut_rx_data;          // rx_fifo[0]
            probed_dut_last_rx   = vif.dut_last_rx_byte;     // Byte committed by RX FSM
            probed_dut_committed = vif.dut_rx_committed;     // 1 when receiver pushed byte
            probed_dut_count     = vif.dut_rx_count;
            probed_dut_wptr      = vif.dut_rx_wptr;
            probed_dut_rptr      = vif.dut_rx_rptr;
            probed_dut_frame_err = vif.dut_status_frame_err;
            probed_dut_overrun   = vif.dut_status_overrun;
        end else begin
            probed_dut_fifo0     = 8'hxx;
            probed_dut_last_rx   = 8'hxx;
            probed_dut_committed = 1'b0;
            probed_dut_count     = 5'b0;
            probed_dut_wptr      = 4'b0;
            probed_dut_rptr      = 4'b0;
            probed_dut_frame_err = 1'b0;
            probed_dut_overrun   = 1'b0;
        end

        dut_fifo_match  = probed_dut_committed &&
                          (probed_dut_last_rx === expected_data) &&
                          (probed_dut_fifo0 === expected_data);
        dut_wptr_match  = (probed_dut_wptr >= 1);
        framing_match   = (probed_dut_frame_err === 1'b0);
        overrun_match   = (probed_dut_overrun === 1'b0);

        overall_pass = mon_data_match && dut_fifo_match && dut_wptr_match && framing_match && overrun_match;

        if (overall_pass) begin
            match_count++;
            msg = $sformatf(
                "\n+========================================================================+\n|             UART SCOREBOARD: END-TO-END VERIFICATION MATCH             |\n+========================================================================+\n| Parameter              | Expected      | Observed      | Status        |\n+------------------------+---------------+---------------+---------------+\n| Injected VIP Data      | 0x%02X (8'hA5)  | 0x%02X          | MATCH         |\n| Monitor Decoded Byte   | 0x%02X (8'hA5)  | 0x%02X          | MATCH         |\n| DUT RX FSM Latched Byte| 0x%02X (8'hA5)  | 0x%02X          | MATCH         |\n| DUT Hardware FIFO[0]   | 0x%02X (8'hA5)  | 0x%02X          | MATCH         |\n| DUT RX Write Pointer   | >= 1          | %0d             | MATCH         |\n| DUT RX Committed Flag  | 1 (Committed) | %0b             | MATCH         |\n| DUT CPU Popped (rptr)  | Observed      | %0d             | MATCH         |\n| DUT Frame Error Flag   | 0 (No Error)  | %0b             | MATCH         |\n| DUT Overrun Error Flag | 0 (No Error)  | %0b             | MATCH         |\n+========================================================================+\n| RESULT: PASS — Hardware peripheral received & decoded exact byte!      |\n+========================================================================+\n",
                expected_data, item.data,
                expected_data, item.data,
                expected_data, probed_dut_last_rx,
                expected_data, probed_dut_fifo0,
                probed_dut_wptr,
                probed_dut_committed,
                probed_dut_rptr,
                probed_dut_frame_err,
                probed_dut_overrun);
            `uvm_info(get_type_name(), msg, UVM_LOW)
        end else begin
            mismatch_count++;
            msg = $sformatf(
                "\n+========================================================================+\n|            UART SCOREBOARD: END-TO-END VERIFICATION MISMATCH           |\n+========================================================================+\n| Field                  | Expected      | Observed      | Match?        |\n+------------------------+---------------+---------------+---------------+\n| Monitor Decoded Byte   | 0x%02X          | 0x%02X          | %s        |\n| DUT RX FSM Latched Byte| 0x%02X          | 0x%02X          | %s        |\n| DUT Hardware FIFO[0]   | 0x%02X          | 0x%02X          | %s        |\n| DUT RX Write Pointer   | >= 1          | %0d             | %s        |\n| DUT RX Committed Flag  | 1             | %0b             | %s        |\n| DUT Frame Error Flag   | 0             | %0b             | %s        |\n| DUT Overrun Error Flag | 0             | %0b             | %s        |\n+========================================================================+\n",
                expected_data, item.data, mon_data_match ? "PASS " : "FAIL!",
                expected_data, probed_dut_last_rx, (probed_dut_last_rx === expected_data) ? "PASS " : "FAIL!",
                expected_data, probed_dut_fifo0, (probed_dut_fifo0 === expected_data) ? "PASS " : "FAIL!",
                probed_dut_wptr, dut_wptr_match ? "PASS " : "FAIL!",
                probed_dut_committed, probed_dut_committed ? "PASS " : "FAIL!",
                probed_dut_frame_err, framing_match ? "PASS " : "FAIL!",
                probed_dut_overrun, overrun_match ? "PASS " : "FAIL!");
            `uvm_error(get_type_name(), msg)
        end
    endfunction

    // -------------------------------------------------------------------------
    // report_phase: Final verification sign-off
    // -------------------------------------------------------------------------
    virtual function void report_phase(uvm_phase phase);
        string summary_msg;
        super.report_phase(phase);
        summary_msg = $sformatf(
            "\n+-------------------------------------------------------------+\n|                   UART SCOREBOARD SUMMARY                   |\n+-------------------------------------------------------------+\n| Total Transactions Received : %-4d                          |\n| Total Matches               : %-4d                          |\n| Total Mismatches            : %-4d                          |\n+-------------------------------------------------------------+\n",
            total_received, match_count, mismatch_count);
        `uvm_info(get_type_name(), summary_msg, UVM_LOW)

        if (total_received == 0) begin
            `uvm_info(get_type_name(),
                "UART Scoreboard: No transactions received (idle / integration construction check).", UVM_LOW)
        end else if (mismatch_count == 0 && match_count > 0) begin
            `uvm_info(get_type_name(),
                "*** UART END-TO-END FUNCTIONAL VERIFICATION: PASSED (0 ERRORS) ***", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(),
                "*** UART END-TO-END FUNCTIONAL VERIFICATION: FAILED ***")
        end
    endfunction

endclass : uart_vip_scoreboard

`endif // UART_VIP_SCOREBOARD_SV
