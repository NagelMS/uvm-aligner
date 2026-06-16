// Test UVM para el módulo cfs_aligner.
 // Configura una secuencia de prueba con parámetros personalizables a través de plusargs, 
 // y verifica el comportamiento del módulo bajo diferentes condiciones de tráfico, control y backpressure.
class aligner_base_test extends uvm_test;
  `uvm_component_utils(aligner_base_test)

  aligner_env env;

  // Parámetros de prueba con valores por defecto, sobreescribibles por plusargs
  int unsigned ctrl_size               = 4;
  int unsigned ctrl_offset             = 0;
  int unsigned irqen_val_i             = 0;

  int unsigned n_packets               = 4;
  int unsigned inter_pkt_cycles        = 0;
  int          rx_size_mode_i          = 0;

  int          bp_mode_i               = 0;
  int unsigned bp_delay                = 0;

  bit          poll_status_en          = 0;
  int unsigned poll_period_cycles      = 5;

  bit          irq_clear_en            = 0;
  bit          illegal_ctrl_en         = 0;
  int unsigned illegal_ctrl_size       = 3;
  int unsigned illegal_ctrl_off        = 0;
  bit          clear_fifo_cnt_en       = 0;
  bit          illegal_status_write_en = 0;

  int unsigned num_ctrl_changes   = 0;

  // Constructor
  function new(string name = "aligner_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: creación de componentes y lectura de plusargs para configuración de la prueba
  function void build_phase(uvm_phase phase);
    int tmp;
    super.build_phase(phase);
    env = aligner_env::type_id::create("env", this);

    // Registro de control
    if ($value$plusargs("CTRL_SIZE=%d",          tmp)) ctrl_size          = tmp;
    if ($value$plusargs("CTRL_OFFSET=%d",        tmp)) ctrl_offset        = tmp;
    if ($value$plusargs("IRQEN=%d",              tmp)) irqen_val_i        = tmp;

    // Tráfico RX
    if ($value$plusargs("NUM_PACKETS=%d",        tmp)) n_packets          = tmp;
    if ($value$plusargs("INTER_PKT_CYCLES=%d",   tmp)) inter_pkt_cycles   = tmp;
    if ($value$plusargs("RX_SIZE_MODE=%d",       tmp)) rx_size_mode_i     = tmp;

    // Backpressure TX
    if ($value$plusargs("BP_MODE=%d",            tmp)) bp_mode_i          = tmp;
    if ($value$plusargs("BP_DELAY=%d",           tmp)) bp_delay           = tmp;

    // Monitoreo de STATUS
    if ($value$plusargs("POLL_STATUS=%d",        tmp)) poll_status_en     = bit'(tmp);
    if ($value$plusargs("POLL_PERIOD_CYCLES=%d", tmp)) poll_period_cycles = tmp;

    // Casos esquina
    if ($value$plusargs("IRQ_CLEAR=%d",          tmp)) irq_clear_en       = bit'(tmp);
    if ($value$plusargs("ILLEGAL_CTRL=%d",       tmp)) illegal_ctrl_en    = bit'(tmp);
    if ($value$plusargs("ILLEGAL_CTRL_SIZE=%d",  tmp)) illegal_ctrl_size  = tmp;
    if ($value$plusargs("ILLEGAL_CTRL_OFFSET=%d",tmp)) illegal_ctrl_off   = tmp;
    if ($value$plusargs("CLEAR_FIFO_CNT=%d",     tmp)) clear_fifo_cnt_en  = bit'(tmp);
    //Escritura ilegal de status
    if ($value$plusargs("ILLEGAL_STATUS_WRITE=%d", tmp)) illegal_status_write_en = bit'(tmp);
    // Cambios de CTRL durante la ejecución
    if ($value$plusargs("NUM_CTRL_CHANGES=%d",   tmp)) num_ctrl_changes   = tmp;

    // Reporte de configuración de la prueba
    `uvm_info("TEST", $sformatf(
      {"\n=== aligner_base_test plusargs leídos ===\n",
       "  CTRL_SIZE=%0d  CTRL_OFFSET=%0d  IRQEN=0x%02h\n",
       "  NUM_PACKETS=%0d  INTER_PKT_CYCLES=%0d  RX_SIZE_MODE=%0d\n",
       "  BP_MODE=%0d  BP_DELAY=%0d\n",
       "  POLL_STATUS=%0b  POLL_PERIOD_CYCLES=%0d\n",
       "  IRQ_CLEAR=%0b  ILLEGAL_CTRL=%0b  CLEAR_FIFO_CNT=%0b\n",
       "  NUM_CTRL_CHANGES=%0d"},
      ctrl_size, ctrl_offset, irqen_val_i,
      n_packets, inter_pkt_cycles, rx_size_mode_i,
      bp_mode_i, bp_delay,
      poll_status_en, poll_period_cycles,
      irq_clear_en, illegal_ctrl_en, clear_fifo_cnt_en,
      num_ctrl_changes),
      UVM_MEDIUM)

    if (bp_mode_i == 4)
      uvm_config_db #(bit)::set(this, "env.scb", "ignore_tx_err", 1'b1);
  endfunction

  // Run phase: creación y configuración de la secuencia principal de prueba, y lanzamiento de la secuencia
  task run_phase(uvm_phase phase);
    aligner_main_seq seq;
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this, 2000);

    // Si CTRL_SIZE=0, se randomiza un tamaño legal (1, 2 o 4) y un offset compatible
    if (ctrl_size == 0) begin
      int unsigned legal_sizes[3] = '{1, 2, 4};
      int unsigned pick;
      void'(std::randomize(pick) with { pick inside {[0:2]}; });
      ctrl_size = legal_sizes[pick];
      case (ctrl_size)
        1: void'(std::randomize(ctrl_offset) with { ctrl_offset inside {[0:3]}; });
        2: void'(std::randomize(ctrl_offset) with { ctrl_offset inside {0, 2}; });
        4: ctrl_offset = 0;
      endcase
      `uvm_info("TEST",
        $sformatf("CTRL_SIZE=0 → randomized size=%0d offset=%0d", ctrl_size, ctrl_offset),
        UVM_MEDIUM)
    end

    // Configuración de la secuencia principal de prueba con los parámetros leídos y randomizados, y lanzamiento de la secuencia
    seq = aligner_main_seq::type_id::create("seq");

    seq.regmodel = env.regmodel;
    seq.tx_drv   = env.md_agt.tx_drv;

    seq.ctrl_size         = ctrl_size;
    seq.ctrl_offset       = ctrl_offset;
    seq.irqen_val         = irqen_val_i[4:0];

    seq.n_packets         = n_packets;
    seq.inter_pkt_cycles  = inter_pkt_cycles;
    seq.rx_size_mode      = rx_size_mode_e'(rx_size_mode_i);

    seq.bp_mode           = md_tx_bp_mode_e'(bp_mode_i);
    seq.bp_delay          = bp_delay;

    seq.poll_status_en     = poll_status_en;
    seq.poll_period_cycles = poll_period_cycles;
    seq.irq_clear_en       = irq_clear_en;

    seq.illegal_ctrl_write_en = illegal_ctrl_en;
    seq.illegal_ctrl_size     = illegal_ctrl_size;
    seq.illegal_ctrl_offset   = illegal_ctrl_off;
    seq.clear_fifo_cnt_en     = clear_fifo_cnt_en;
    
    seq.illegal_status_write_en      = illegal_status_write_en;

    seq.num_ctrl_changes  = num_ctrl_changes;

    seq.start(env.md_agt.sqr);
    phase.drop_objection(this);
  endtask

endclass
