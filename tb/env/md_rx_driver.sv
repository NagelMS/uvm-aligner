`ifndef MD_RX_DRIVER_SV
`define MD_RX_DRIVER_SV

// Driver para el lado MD RX del Alineador, con un ancho de datos parametrizable.
class md_rx_driver #(
  parameter int ALGN_DATA_WIDTH = 32
) extends uvm_driver #(md_seq_item #(ALGN_DATA_WIDTH));

  `uvm_component_param_utils(md_rx_driver #(ALGN_DATA_WIDTH))

  virtual md_if #(ALGN_DATA_WIDTH) vif;

  // Constructor
  function new(string name = "md_rx_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Etapa de construcción: obtiene la interfaz virtual desde config_db y reporta un error fatal si no se encuentra.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual md_if #(ALGN_DATA_WIDTH))::get(
          this, "", "md_rx_vif", vif))
      `uvm_fatal("NO_VIF",
        "md_rx_driver: no se encontró md_rx_vif en config_db. \
         Verifica el set() en aligner_tb.sv")
  endfunction

  // Etapa de ejecución: ciclo infinito de espera por items del sequencer, conducción de la transferencia MD RX y notificación al sequencer.
  task run_phase(uvm_phase phase);
    md_seq_item #(ALGN_DATA_WIDTH) req;

    // Llevar las señales a idle antes de esperar el reset
    _drive_idle();

    // Esperar a que el reset sea liberado.
    if (!vif.reset_n) @(posedge vif.reset_n);

    // Dar 2 ciclos de margen después del reset
    repeat(2) @(posedge vif.clk);

    forever begin
      // Pedir el próximo item al sequencer
      seq_item_port.get_next_item(req);

      // Ejecutar la transferencia MD
      _drive_transfer(req);

      // Notificar al sequencer que el item fue procesado.
      seq_item_port.item_done();
    end
  endtask

  // Etapa de conducción a idle: lleva las señales a estado inactivo antes de esperar el reset.
  task _drive_idle();
    @(posedge vif.clk); #1;
    vif.valid  <= 1'b0;
    vif.data   <= '0;
    vif.offset <= '0;
    vif.size   <= '0;
  endtask

  // Etapa de conducción de transferencia: envía los datos MD RX al DUT y espera el handshake.
  task _drive_transfer(md_seq_item #(ALGN_DATA_WIDTH) req);
    @(posedge vif.clk); #1;
    vif.valid  <= 1'b1;
    vif.data   <= req.data;
    vif.offset <= req.offset;
    vif.size   <= req.size;

    // Esperar el handshake
    @(posedge vif.clk);
    while (!vif.ready) @(posedge vif.clk);

    req.got_err = vif.err;

    `uvm_info("MD_RX_DRV",
      $sformatf("[RX] Handshake completo: %s", req.convert2string()),
      UVM_HIGH)

    // Bajar valid
    #1;
    vif.valid <= 1'b0;
  endtask

endclass

`endif
