///////////////////////////////////////////////////////////////////////////////
// File:        apb_agent.sv
// Description: Agente APB UVM. Contiene sequencer, driver y monitor.
//              Expone analysis_port para que el predictor RAL lo conecte.
//              Soporta modo activo (drv+sqr+mon) y pasivo (solo mon).
///////////////////////////////////////////////////////////////////////////////
`ifndef APB_AGENT_SV
`define APB_AGENT_SV

class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)

  // Puerto de análisis expuesto al ambiente (se conecta al predictor RAL)
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
    // El ap del agente apunta directamente al ap del monitor
    ap = mon.ap;
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction

endclass

`endif
