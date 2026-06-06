`ifndef MD_AGENT_SV
`define MD_AGENT_SV

class md_agent #(
  parameter int ALGN_DATA_WIDTH = 32
) extends uvm_agent;

  `uvm_component_param_utils(md_agent #(ALGN_DATA_WIDTH))

  md_sequencer #(ALGN_DATA_WIDTH) sqr;
  md_rx_driver #(ALGN_DATA_WIDTH) rx_drv;
  md_tx_driver #(ALGN_DATA_WIDTH) tx_drv;

    md_monitor #(ALGN_DATA_WIDTH, 1) rx_mon;  // IS_RX=1
  md_monitor #(ALGN_DATA_WIDTH, 0) tx_mon;  // IS_RX=0

  uvm_analysis_port #(md_seq_item #(ALGN_DATA_WIDTH)) rx_ap;
  uvm_analysis_port #(md_seq_item #(ALGN_DATA_WIDTH)) tx_ap;

  function new(string name = "md_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // build_phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    rx_mon = md_monitor #(ALGN_DATA_WIDTH, 1)::type_id::create("rx_mon", this);
    tx_mon = md_monitor #(ALGN_DATA_WIDTH, 0)::type_id::create("tx_mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      sqr    = md_sequencer #(ALGN_DATA_WIDTH)::type_id::create("sqr",    this);
      rx_drv = md_rx_driver #(ALGN_DATA_WIDTH)::type_id::create("rx_drv", this);
      tx_drv = md_tx_driver #(ALGN_DATA_WIDTH)::type_id::create("tx_drv", this);
    end
  endfunction

  // connect_phase
  function void connect_phase(uvm_phase phase);
    rx_ap = rx_mon.ap;
    tx_ap = tx_mon.ap;

    if (get_is_active() == UVM_ACTIVE) begin
      rx_drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass

`endif
