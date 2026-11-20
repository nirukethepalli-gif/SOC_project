// SPDX-License-Identifier: Apache-2.0
// AXI4-Lite Protocol Assertions per Section 14.3 of SoC Specification v2.0

`timescale 1ns/1ps

module axi4lite_assertions #(
    parameter string PORT_NAME = "AXI4LITE_PORT",
    parameter bit    IS_PERIPHERAL = 1'b0
)(
    input logic        aclk,
    input logic        aresetn,

    input logic [31:0] awaddr,
    input logic [2:0]  awprot,
    input logic        awvalid,
    input logic        awready,

    input logic [31:0] wdata,
    input logic [3:0]  wstrb,
    input logic        wvalid,
    input logic        wready,

    input logic [1:0]  bresp,
    input logic        bvalid,
    input logic        bready,

    input logic [31:0] araddr,
    input logic [2:0]  arprot,
    input logic        arvalid,
    input logic        arready,

    input logic [31:0] rdata,
    input logic [1:0]  rresp,
    input logic        rvalid,
    input logic        rready
);

`ifndef SYNTHESIS
    // -------------------------------------------------------------------------
    // Rule 1: VALID must remain asserted until READY is high
    // -------------------------------------------------------------------------
    property p_awvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> awvalid;
    endproperty
    assert property (p_awvalid_stable) else $error("[%s] AWVALID dropped without AWREADY!", PORT_NAME);

    property p_wvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> wvalid;
    endproperty
    assert property (p_wvalid_stable) else $error("[%s] WVALID dropped without WREADY!", PORT_NAME);

    property p_arvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> arvalid;
    endproperty
    assert property (p_arvalid_stable) else $error("[%s] ARVALID dropped without ARREADY!", PORT_NAME);

    property p_bvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> bvalid;
    endproperty
    assert property (p_bvalid_stable) else $error("[%s] BVALID dropped without BREADY!", PORT_NAME);

    property p_rvalid_stable;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> rvalid;
    endproperty
    assert property (p_rvalid_stable) else $error("[%s] RVALID dropped without RREADY!", PORT_NAME);

    // -------------------------------------------------------------------------
    // Rule 2 & 3: Payloads must remain stable while VALID is high and READY low
    // -------------------------------------------------------------------------
    property p_awpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) |=> $stable(awaddr) && $stable(awprot);
    endproperty
    assert property (p_awpayload_stable) else $error("[%s] AW payload changed while stalled!", PORT_NAME);

    property p_wpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) |=> $stable(wdata) && $stable(wstrb);
    endproperty
    assert property (p_wpayload_stable) else $error("[%s] W payload changed while stalled!", PORT_NAME);

    property p_arpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) |=> $stable(araddr) && $stable(arprot);
    endproperty
    assert property (p_arpayload_stable) else $error("[%s] AR payload changed while stalled!", PORT_NAME);

    property p_rpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (rvalid && !rready) |=> $stable(rdata) && $stable(rresp);
    endproperty
    assert property (p_rpayload_stable) else $error("[%s] R payload changed while stalled!", PORT_NAME);

    property p_bpayload_stable;
        @(posedge aclk) disable iff (!aresetn)
        (bvalid && !bready) |=> $stable(bresp);
    endproperty
    assert property (p_bpayload_stable) else $error("[%s] BRESP changed while stalled!", PORT_NAME);

    // -------------------------------------------------------------------------
    // Rule 4, 5, 6: Response bookkeeping
    // -------------------------------------------------------------------------
    int unsigned outstanding_writes;
    int unsigned outstanding_reads;
    bit aw_seen, w_seen;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            outstanding_writes <= 0;
            outstanding_reads  <= 0;
            aw_seen            <= 1'b0;
            w_seen             <= 1'b0;
        end else begin
            if (awvalid && awready) aw_seen <= 1'b1;
            if (wvalid && wready)   w_seen  <= 1'b1;

            if ((awvalid && awready || aw_seen) && (wvalid && wready || w_seen)) begin
                outstanding_writes <= outstanding_writes + 1;
                aw_seen            <= 1'b0;
                w_seen             <= 1'b0;
            end

            if (bvalid && bready) begin
                if (outstanding_writes == 0 && !(aw_seen && w_seen)) begin
                    $error("[%s] B response returned without preceding AW+W!", PORT_NAME);
                end else if (outstanding_writes > 0) begin
                    outstanding_writes <= outstanding_writes - 1;
                end
            end

            if (arvalid && arready) begin
                outstanding_reads <= outstanding_reads + 1;
            end
            if (rvalid && rready) begin
                if (outstanding_reads == 0) begin
                    $error("[%s] R response returned without preceding AR!", PORT_NAME);
                end else begin
                    outstanding_reads <= outstanding_reads - 1;
                end
            end
        end
    end

    // Rule 6: BVALID never rises before both AW and W handshaked
    property p_bvalid_after_aw_w;
        @(posedge aclk) disable iff (!aresetn)
        $rose(bvalid) |-> (outstanding_writes > 0 || (aw_seen && w_seen));
    endproperty
    assert property (p_bvalid_after_aw_w) else $error("[%s] BVALID rose before AW and W completed!", PORT_NAME);

    // -------------------------------------------------------------------------
    // Rule 7: Reset state
    // -------------------------------------------------------------------------
    property p_reset_valid_low;
        @(posedge aclk)
        !aresetn |-> (!awvalid && !wvalid && !arvalid && !bvalid && !rvalid);
    endproperty
    assert property (p_reset_valid_low) else $error("[%s] VALID asserted during reset!", PORT_NAME);

    // -------------------------------------------------------------------------
    // Rule 8: Max stall duration of 32 cycles
    // -------------------------------------------------------------------------
    property p_aw_stall_max;
        @(posedge aclk) disable iff (!aresetn)
        (awvalid && !awready) [*33] |-> 0;
    endproperty
    assert property (p_aw_stall_max) else $error("[%s] AW stalled > 32 cycles!", PORT_NAME);

    property p_w_stall_max;
        @(posedge aclk) disable iff (!aresetn)
        (wvalid && !wready) [*33] |-> 0;
    endproperty
    assert property (p_w_stall_max) else $error("[%s] W stalled > 32 cycles!", PORT_NAME);

    property p_ar_stall_max;
        @(posedge aclk) disable iff (!aresetn)
        (arvalid && !arready) [*33] |-> 0;
    endproperty
    assert property (p_ar_stall_max) else $error("[%s] AR stalled > 32 cycles!", PORT_NAME);

    // -------------------------------------------------------------------------
    // Rule 9: WSTRB never 4'b0000 on peripheral ports
    // -------------------------------------------------------------------------
    if (IS_PERIPHERAL) begin : gen_peripheral_check
        property p_wstrb_nonzero;
            @(posedge aclk) disable iff (!aresetn)
            wvalid |-> (wstrb != 4'b0000);
        endproperty
        assert property (p_wstrb_nonzero) else $error("[%s] WSTRB == 0 on peripheral!", PORT_NAME);
    end

`endif

endmodule

