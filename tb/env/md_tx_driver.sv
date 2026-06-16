`ifndef MD_TX_DRIVER_SV
`define MD_TX_DRIVER_SV

typedef enum int {
  MD_TX_ALWAYS_READY = 0,  // Acepta todo inmediatamente
  MD_TX_ALWAYS_STALL = 1,  // Nunca acepta 
  MD_TX_RANDOM       = 2,  // Ready aleatorio
  MD_TX_FIXED_DELAY  = 3,  // Ready después de bp_delay ciclos de espera
  MD_TX_WITH_ERR     = 4   // Simula errores
} md_tx_bp_mode_e;

// Driver para el lado MD TX del Alineador, con capacidad de simular diferentes condiciones de backpressure y errores
class md_tx_driver #(
  parameter int ALGN_DATA_WIDTH = 32
) extends uvm_driver #(md_seq_item #(ALGN_DATA_WIDTH));

  `uvm_component_param_utils(md_tx_driver #(ALGN_DATA_WIDTH))

  virtual md_if #(ALGN_DATA_WIDTH) vif;

  // Configuración de backpressure
  // bp_mode: política activa. Se puede cambiar entre tests.
  md_tx_bp_mode_e bp_mode = MD_TX_ALWAYS_READY;

  // bp_delay: ciclos de espera cuando bp_mode = MD_TX_FIXED_DELAY.
  int unsigned bp_delay = 2;

  function new(string name = "md_tx_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // build_phase: obtiene la interfaz virtual y lee la configuración de backpressure desde config_db
  function void build_phase(uvm_phase phase);
    int mode_int;
    super.build_phase(phase);

    if (!uvm_config_db #(virtual md_if #(ALGN_DATA_WIDTH))::get(
          this, "", "md_tx_vif", vif))
      `uvm_fatal("NO_VIF",
        "md_tx_driver: no se encontró md_tx_vif en config_db. \
         Verifica el set() en aligner_tb.sv")

    if (uvm_config_db #(int)::get(this, "", "bp_mode", mode_int))
      bp_mode = md_tx_bp_mode_e'(mode_int);

    if (uvm_config_db #(int unsigned)::get(this, "", "bp_delay", bp_delay))
      ; // ya asignado
  endfunction

  // run_phase: ciclo eterno de control del ready para simular diferentes condiciones de backpressure
  task run_phase(uvm_phase phase);
    // Inicializar: el receptor empieza listo (ready=1) y sin error.
    @(posedge vif.clk); #1;
    vif.ready <= 1'b1;
    vif.err   <= 1'b0;

    // Esperar liberación del reset
    if (!vif.reset_n) @(posedge vif.reset_n);
    repeat(2) @(posedge vif.clk);

    // Loop eterno de control del lado TX
    forever begin
      @(posedge vif.clk); #1;
      _apply_backpressure();
    end
  endtask

  // Lógica para aplicar backpressure según el modo configurado, controlando la señal ready y opcionalmente err en la interfaz MD TX
  task _apply_backpressure();
    case (bp_mode)

      // Siempre listo: acepta cualquier dato inmediatamente
      MD_TX_ALWAYS_READY: begin
        vif.ready <= 1'b1;
      end

      // Siempre parado: nunca acepta (llena el TX FIFO)
      MD_TX_ALWAYS_STALL: begin
        vif.ready <= 1'b0;
      end

      // Aleatorio: proba 50/50 de aceptar cada ciclo 
      MD_TX_RANDOM: begin
        vif.ready <= $urandom_range(0, 1);
      end

      // Delay fijo: espera bp_delay ciclos antes de aceptar 
      MD_TX_FIXED_DELAY: begin
        if (vif.valid) begin
          // Hay un paquete esperando — aplicar el delay
          vif.ready <= 1'b0;
          repeat(bp_delay) @(posedge vif.clk);
          #1;
          vif.ready <= 1'b1;
          @(posedge vif.clk);
          #1;
          vif.ready <= 1'b0;
        end else begin
          vif.ready <= 1'b1; // Sin datos: permanecer listo
        end
      end

      MD_TX_WITH_ERR: begin
        vif.ready <= 1'b1;
        vif.err   <= (vif.valid) ? $urandom_range(0, 1) : 1'b0;
      end

      default: vif.ready <= 1'b1;
    endcase
  endtask

  // Función para cambiar el modo de backpressure durante la simulación, con reporte informativo. Se puede llamar desde las secuencias para probar diferentes condiciones dinámicamente.
  function void set_bp_mode(md_tx_bp_mode_e mode, int unsigned delay = 0);
    bp_mode = mode;
    if (delay > 0) bp_delay = delay;
    `uvm_info("MD_TX_DRV",
      $sformatf("Backpressure mode cambiado a %s (delay=%0d)",
                mode.name(), bp_delay),
      UVM_MEDIUM)
  endfunction

endclass

`endif
