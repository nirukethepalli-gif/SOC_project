class timer_vip_env extends uvm_env;
timer_vip_agent agent; timer_vip_scoreboard sb;
`uvm_component_utils(timer_vip_env)
function new(string n,uvm_component p);super.new(n,p);endfunction
function void build_phase(uvm_phase phase); agent=timer_vip_agent::type_id::create("agent",this); sb=timer_vip_scoreboard::type_id::create("sb",this); endfunction
endclass
