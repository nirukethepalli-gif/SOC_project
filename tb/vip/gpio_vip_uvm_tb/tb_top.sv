module tb_top;
import uvm_pkg::*; import gpio_vip_pkg::*;
gpio_vip_if vif();
initial run_test("gpio_vip_test");
endmodule
