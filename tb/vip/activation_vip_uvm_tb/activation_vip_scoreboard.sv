ifndef ACTIVATION_VIP_SCOREBOARD_SV
define ACTIVATION_VIP_SCOREBOARD_SV
class activation_vip_scoreboard extends uvm_scoreboard;
    uvm_component_utils(activation_vip_scoreboard)
    virtual activation_vip_if vif;
    uvm_analysis_imp #(activation_vip_item, activation_vip_scoreboard) item_export;
    function new(string name = "activation_vip_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_export = new("item_export", this);
    endfunction
    function void write(activation_vip_item item); endfunction
endclass
endif
