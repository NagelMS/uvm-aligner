class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  uvm_analysis_port #(apb_seq_item) ap;

  apb_sequencer sqr;
  apb_driver    drv;
  apb_monitor   mon;

  function new(string name = "apb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = apb_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sqr = apb_sequencer::type_id::create("sqr", this);
      drv = apb_driver::type_id::create("drv", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    ap = mon.ap;
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass

