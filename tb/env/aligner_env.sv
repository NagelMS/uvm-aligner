`ifndef ALIGNER_ENV_SV
`define ALIGNER_ENV_SV

// Ambiente UVM para el alineador, que incluye un agente APB, un modelo de registros RAL, 
// un adaptador RAL-APB, un predictor de registros, un agente MD y un scoreboard.
class aligner_env extends uvm_env;
  `uvm_component_utils(aligner_env)

  // Componentes del ambiente
  apb_agent                         apb_agt;
  ALIGNER                           regmodel;
  apb_ral_adapter                   adapter;
  uvm_reg_predictor #(apb_seq_item) predictor;
  md_agent  #(32)                   md_agt;
  scoreboard #(8, 32)               scb;

  function new(string name = "aligner_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Etapa de construcción: crea los componentes del ambiente, configura el agente APB y el agente MD como activos, 
  // y pasa el modelo de registros al scoreboard.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Agente APB activo
    uvm_config_db #(uvm_active_passive_enum)::set(
      this, "apb_agt", "is_active", UVM_ACTIVE);
    apb_agt = apb_agent::type_id::create("apb_agt", this);

    // Modelo de registros RAL
    regmodel = new("regmodel");
    regmodel.build();
    regmodel.lock_model();

    // Adaptador RAL-APB y predictor de registros
    adapter   = apb_ral_adapter::type_id::create("adapter", this);
    predictor = uvm_reg_predictor #(apb_seq_item)::type_id::create("predictor", this);

    // Agente MD activo
    uvm_config_db #(uvm_active_passive_enum)::set(
      this, "md_agt", "is_active", UVM_ACTIVE);
    md_agt = md_agent #(32)::type_id::create("md_agt", this);

    // Scoreboard: pasar el RAL antes de que build_phase del scb lo pida
    uvm_config_db #(ALIGNER)::set(this, "scb", "ral", regmodel);
    scb = scoreboard #(8, 32)::type_id::create("scb", this);
  endfunction

  // Etapa de conexión: conecta el modelo de registros al adaptador y al predictor, conecta el monitor APB al predictor
  function void connect_phase(uvm_phase phase);
    // RAL frente al adaptador y al predictor
    regmodel.default_map.set_sequencer(apb_agt.sqr, adapter);
    regmodel.default_map.set_auto_predict(0);

    // RAL espejo para el predictor
    predictor.map     = regmodel.default_map;
    predictor.adapter = adapter;
    apb_agt.ap.connect(predictor.bus_in);

    // Monitor APB conectado al scoreboard
    apb_agt.ap.connect(scb.m_analysis_imp_apb_bus);

    // MD monitors conectados al scoreboard
    md_agt.rx_ap.connect(scb.m_analysis_imp_md_rx);
    md_agt.tx_ap.connect(scb.m_analysis_imp_md_tx);
  endfunction

endclass

`endif
