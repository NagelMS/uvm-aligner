`ifndef MD_MONITOR_SV
`define MD_MONITOR_SV

class md_monitor #(
  parameter int ALGN_DATA_WIDTH = 32,
  parameter bit IS_RX           = 1    // 1=lado RX, 0=lado TX
) extends uvm_monitor;

  `uvm_component_param_utils(md_monitor #(ALGN_DATA_WIDTH, IS_RX))

  uvm_analysis_port #(md_seq_item #(ALGN_DATA_WIDTH)) ap;

  virtual md_if #(ALGN_DATA_WIDTH) vif;

  function new(string name = "md_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // build_phase
  function void build_phase(uvm_phase phase);
    string vif_key;
    super.build_phase(phase);

    ap = new("ap", this);

    vif_key = IS_RX ? "md_rx_vif" : "md_tx_vif";

    if (!uvm_config_db #(virtual md_if #(ALGN_DATA_WIDTH))::get(
          this, "", vif_key, vif))
      `uvm_fatal("NO_VIF",
        $sformatf("md_monitor (IS_RX=%0b): no se encontró '%s' en config_db.",
                  IS_RX, vif_key))
  endfunction

  // run_phase
  task run_phase(uvm_phase phase);
    md_seq_item #(ALGN_DATA_WIDTH) tr;
    string side = IS_RX ? "RX" : "TX";

    // Esperar que el reset termine antes de empezar a observar.
    if (!vif.reset_n) @(posedge vif.reset_n);
    repeat(2) @(posedge vif.clk);

    forever begin
      @(posedge vif.clk);

      // Condición de handshake
      // valid y ready deben ser 1 para capturar datos
      if (vif.valid === 1'b1 && vif.ready === 1'b1) begin

        tr = md_seq_item #(ALGN_DATA_WIDTH)::type_id::create("tr");

        tr.data    = vif.data;
        tr.offset  = vif.offset;
        tr.size    = vif.size;
        tr.err     = vif.err;
        tr.got_err = vif.err;

        // Log de la transacción observada
        `uvm_info($sformatf("MD_%s_MON", side),
          $sformatf("[%s] Transferencia detectada: %s", side,
                    tr.convert2string()),
          UVM_HIGH)

        // Publicar en el analysis port para que el scoreboard detecte la transacción
        ap.write(tr);
      end
    end
  endtask

endclass

`endif
