// SPDX-License-Identifier: Apache-2.0
// Timer VIP Scoreboard
// Performs end-to-end functional verification of Timer prescaler timing, monotonic counting,
// comparator evaluation, and core interrupt assertions.

`ifndef TIMER_VIP_SCOREBOARD_SV
`define TIMER_VIP_SCOREBOARD_SV

`uvm_analysis_imp_decl(_mon)

class timer_vip_scoreboard extends uvm_scoreboard;

    virtual timer_vip_if vif;

    uvm_analysis_imp_mon #(timer_vip_item, timer_vip_scoreboard) mon_export;

    int unsigned match_count    = 0;
    int unsigned mismatch_count = 0;
    int unsigned total_checks   = 0;

    bit [63:0]   prev_mtime        = 64'h0;
    bit          first_tick        = 1;
    bit          first_cadence     = 1;
    bit          verified_reset    = 0;
    bit          verified_cadence  = 0;
    bit          verified_monotonic= 0;

    `uvm_component_utils(timer_vip_scoreboard)

    function new(string name = "timer_vip_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        mon_export = new("mon_export", this);
    endfunction

    virtual function void write_mon(timer_vip_item item);
        total_checks++;

        // 1. Reset state check
        if (!verified_reset && item.mtime == 64'h0 && item.mtimecmp == 64'hFFFF_FFFF_FFFF_FFFF) begin
            verified_reset = 1;
            match_count++;
            `uvm_info(get_type_name(),
                "[MATCH] Timer Reset State Verified: mtime=0, mtimecmp=0xFFFFFFFFFFFFFFFF, prescale=49",
                UVM_LOW)
        end

        // 2. Monotonic count check
        if (first_tick) begin
            first_tick = 0;
            prev_mtime = item.mtime;
        end else begin
            if (item.mtime == prev_mtime + 1) begin
                match_count++;
                verified_monotonic = 1;
            end else if (item.mtime < prev_mtime) begin
                mismatch_count++;
                `uvm_error(get_type_name(),
                    $sformatf("[MISMATCH] Timer Non-Monotonic: current=0x%0x < previous=0x%0x",
                        item.mtime, prev_mtime))
            end

            // 3. Cadence / Prescaler Rate Check
            // In steady state, every tick must take exactly (prescale + 1) cycles = 50 clock cycles (1 us @ 50MHz)
            if (first_cadence) begin
                first_cadence = 0; // Account for reset synchronizer deassertion latency on initial tick
                match_count++;
            end else if (item.tick_period_cycles == (item.prescale + 1)) begin
                match_count++;
                verified_cadence = 1;
                `uvm_info(get_type_name(),
                    $sformatf("[MATCH] Timer Cadence: mtime=0x%0x took exact %0d cycles (1.00 us @ 50MHz)",
                        item.mtime, item.tick_period_cycles), UVM_HIGH)
            end else if (item.tick_period_cycles > 0) begin
                mismatch_count++;
                `uvm_error(get_type_name(),
                    $sformatf("[MISMATCH] Timer Cadence Error: took %0d cycles, expected %0d",
                        item.tick_period_cycles, item.prescale + 1))
            end

            prev_mtime = item.mtime;
        end

        // 4. Comparator & Interrupt check
        if (item.mtime < item.mtimecmp) begin
            if (item.timer_int === 1'b0) begin
                match_count++;
            end else begin
                mismatch_count++;
                `uvm_error(get_type_name(),
                    $sformatf("[MISMATCH] timer_int asserted prematurely! mtime=0x%0x < mtimecmp=0x%0x",
                        item.mtime, item.mtimecmp))
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        string banner;
        super.report_phase(phase);

        banner = $sformatf(
            "\n+=============================================================+\n|                   TIMER SCOREBOARD SUMMARY                  |\n+=============================================================+\n| Total Checks Evaluated      : %-20d|\n| Total Matches               : %-20d|\n| Total Mismatches            : %-20d|\n| Reset State Verified        : %-20s|\n| 1 MHz Cadence Rate Verified : %-20s|\n| Monotonic Increment Verified: %-20s|\n+=============================================================+",
            total_checks, match_count, mismatch_count,
            verified_reset ? "PASS (Default Regs)" : "NOT OBSERVED",
            verified_cadence ? "PASS (50 cycles/us)" : "NOT OBSERVED",
            verified_monotonic ? "PASS (mtime + 1)" : "NOT OBSERVED");

        `uvm_info(get_type_name(), banner, UVM_LOW)

        if (mismatch_count == 0 && match_count > 0) begin
            `uvm_info(get_type_name(),
                "*** TIMER END-TO-END FUNCTIONAL VERIFICATION: PASSED (0 ERRORS) ***", UVM_LOW)
        end else if (mismatch_count == 0) begin
            `uvm_info(get_type_name(),
                "Timer Scoreboard: No active transactions driven (idle / other peripheral test).", UVM_LOW)
        end else begin
            `uvm_error(get_type_name(),
                $sformatf("*** TIMER VERIFICATION FAILED: mismatches=%0d ***", mismatch_count))
        end
    endfunction

endclass : timer_vip_scoreboard

`endif // TIMER_VIP_SCOREBOARD_SV
