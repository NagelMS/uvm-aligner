///////////////////////////////////////////////////////////////////////////////
// File:        aligner_env.sv
// Description: Ambiente UVM para el cfs_aligner. Contiene el agente APB,
//              el modelo de registros RAL (ALIGNER), el adaptador APB↔RAL
//              y el predictor explícito.
//
//              Conexiones de RAL (Paso 7 del libro, Fig. 20.5):
//                regmodel ←→ adapter ←→ apb_agt.sqr   (frente: escrituras RAL)
//                apb_agt.ap → predictor → regmodel     (espejo: observar el bus)
///////////////////////////////////////////////////////////////////////////////
`ifndef ALIGNER_ENV_SV
`define ALIGNER_ENV_SV

class aligner_env extends uvm_env;
  `uvm_component_utils(aligner_env)

  // ── Componentes ───────────────────────────────────────────────────────────
  apb_agent                         apb_agt;
  ALIGNER                           regmodel;
  apb_ral_adapter                   adapter;
  uvm_reg_predictor #(apb_seq_item) predictor;
  md_agent #(32)                    md_agent;

  function new(string name = "aligner_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // ── Build Phase ───────────────────────────────────────────────────────────
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Agente APB en modo activo
    uvm_config_db #(uvm_active_passive_enum)::set(
      this, "apb_agt", "is_active", UVM_ACTIVE);
    apb_agt = apb_agent::type_id::create("apb_agt", this);

    // Modelo de registros: crear, construir y bloquear
    regmodel = ALIGNER::type_id::create("regmodel", this);
    regmodel.build();
    regmodel.lock_model();

    // Adaptador RAL↔APB
    adapter = apb_ral_adapter::type_id::create("adapter", this);

    // Predictor explícito parametrizado con el tipo de transacción del bus
    predictor = uvm_reg_predictor #(apb_seq_item)::type_id::create(
      "predictor", this);

    // Agente MD en modo activo
    uvm_config_db #(uvm_active_passive_enum)::set(
      this, "md_agt", "is_active", UVM_ACTIVE);
    md_agt = md_agent #(32)::type_id::create("md_agt", this);
  endfunction

  // ── Connect Phase ─────────────────────────────────────────────────────────
  function void connect_phase(uvm_phase phase);
    // 1. Vincular el mapa RAL al sequencer APB a través del adaptador
    //    (permite hacer regmodel.CTRL.write/read desde secuencias)
    regmodel.default_map.set_sequencer(apb_agt.sqr, adapter);

    // 2. Desactivar predicción implícita — usamos predictor explícito
    //    (el predictor observa TODO el bus, no solo las operaciones RAL)
    regmodel.default_map.set_auto_predict(0);

    // 3. Configurar el predictor con el mapa y el adaptador
    predictor.map     = regmodel.default_map;
    predictor.adapter = adapter;

    // 4. Monitor → predictor: cada transacción APB actualiza el espejo RAL
    apb_agt.ap.connect(predictor.bus_in);
  endfunction

endclass

`endif
