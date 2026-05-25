///////////////////////////////////////////////////////////////////////////////
// File:        apb_sequencer.sv
// Description: Sequencer APB. Pasa apb_seq_item del test al driver.
//              El RAL adapter lo usará como target cuando se conecte.
///////////////////////////////////////////////////////////////////////////////
`ifndef APB_SEQUENCER_SV
`define APB_SEQUENCER_SV

class apb_sequencer extends uvm_sequencer #(apb_seq_item);
  `uvm_component_utils(apb_sequencer)

  function new(string name = "apb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass

`endif
