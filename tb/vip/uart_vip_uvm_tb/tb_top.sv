module tb_top;
import uvm_pkg::*; import uart_vip_pkg::*;
uart_vip_if vif();
initial run_test("uart_vip_test");
endmodule
