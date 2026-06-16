// Secuenciador UVM para el agente del Alineador, especializado en transacciones de tipo apb_seq_item.
class apb_sequencer extends uvm_sequencer #(apb_seq_item);
  `uvm_component_utils(apb_sequencer)

  function new(string name = "apb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass
