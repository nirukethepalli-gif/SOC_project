	imescale 1ns/1ps
module tb_top;
    import uvm_pkg::*;
    import activation_vip_pkg::*;
    logic clk = 0; always #5 clk = ~clk;
    activation_vip_if vif();
    assign vif.clk = clk;
    initial begin
        uvm_config_db#(virtual activation_vip_if)::set(null, "*", "vif", vif);
        run_test("activation_vip_test");
    end
endmodule
