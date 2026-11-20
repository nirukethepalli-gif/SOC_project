module tb_top;
import uvm_pkg::*; import timer_vip_pkg::*;
timer_vip_if vif();
initial run_test("timer_vip_test");
endmodule
