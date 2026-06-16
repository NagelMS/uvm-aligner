`ifndef MD_SEQUENCER_SV
`define MD_SEQUENCER_SV

// Secuenciador para transacciones MD RX y MD TX, con un ancho de datos parametrizable. 
// Se conecta a los drivers MD RX y MD TX para generar transacciones de prueba.
class md_sequencer #(
  parameter int ALGN_DATA_WIDTH = 32
) extends uvm_sequencer #(md_seq_item #(ALGN_DATA_WIDTH));

  `uvm_component_param_utils(md_sequencer #(ALGN_DATA_WIDTH))

  function new(string name = "md_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass

`endif
