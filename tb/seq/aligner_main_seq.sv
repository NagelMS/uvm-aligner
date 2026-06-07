///////////////////////////////////////////////////////////////////////////////
// aligner_main_seq.sv
//
// Secuencia principal del cfs_aligner. Sus knobs cubren la mayoría de los
// casos del README:
//
//   Flujo válido          rx_size_mode = RX_SIZE_RAND   (default)
//   RX > CTRL size        rx_size_mode = RX_SIZE_GT_CTRL
//   RX < CTRL size        rx_size_mode = RX_SIZE_LT_CTRL
//   Cambios de CTRL       num_ctrl_changes > 0  (randomizados via UVM RNG)
//   Lectura activa STATUS poll_status_en = 1  (hilo concurrente)
//   Paquete RX ilegal     rx_size_mode = RX_SIZE_ILLEGAL
//   Saturación CNT_DROP   rx_size_mode = RX_SIZE_ILLEGAL + n_packets alto
//   CTRL write ilegal     illegal_ctrl_write_en = 1
//   CLR bit (CNT_DROP)    clear_fifo_cnt_en = 1
//   FIFO RX/TX lleno      bp_mode = MD_TX_ALWAYS_STALL + n_packets alto
//   IRQ W1C               irq_clear_en = 1 + irqen_val apropiado
//
// Se lanza sobre env.md_agt.sqr.
// Operaciones RAL usan internamente el APB sequencer del default_map.
///////////////////////////////////////////////////////////////////////////////

typedef enum int {
  RX_SIZE_RAND,        // aleatorio legal (default)
  RX_SIZE_MATCH_CTRL,  // rx_size == ctrl_size  (passthrough directo)
  RX_SIZE_GT_CTRL,     // rx_size > ctrl_size   (fragmentación en TX)
  RX_SIZE_LT_CTRL,     // rx_size < ctrl_size   (acumulación en TX)
  RX_SIZE_ILLEGAL      // combos ilegales de size/offset en RX
} rx_size_mode_e;


class aligner_main_seq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(aligner_main_seq)

  // ── Handles (asignados por el test antes de start) ────────────────────────
  ALIGNER            regmodel;
  md_tx_driver #(32) tx_drv;

  // ── Configuración inicial de registros ────────────────────────────────────
  int unsigned ctrl_size        = 4;
  int unsigned ctrl_offset      = 0;
  bit [4:0]    irqen_val        = 5'h00;

  // ── Tráfico RX ────────────────────────────────────────────────────────────
  int unsigned   n_packets        = 4;
  int unsigned   inter_pkt_cycles = 0;
  rx_size_mode_e rx_size_mode     = RX_SIZE_RAND;

  // ── Cambios de CTRL durante la ejecución ─────────────────────────────────
  // Con num_ctrl_changes > 0 la secuencia randomiza un nuevo combo legal
  // de (size, offset) cada n_packets/(num_ctrl_changes+1) paquetes.
  int unsigned num_ctrl_changes = 0;

  rand bit [2:0] rnd_ctrl_size;
  rand bit [1:0] rnd_ctrl_offset;

  constraint c_legal_ctrl_change {
    rnd_ctrl_size inside {3'd1, 3'd2, 3'd4};
    (rnd_ctrl_size == 3'd4) -> (rnd_ctrl_offset == 2'd0);
    (rnd_ctrl_size == 3'd2) -> (rnd_ctrl_offset inside {2'd0, 2'd2});
  }

  // ── Control de backpressure TX ────────────────────────────────────────────
  md_tx_bp_mode_e bp_mode  = MD_TX_ALWAYS_READY;
  int unsigned    bp_delay = 0;

  // ── Monitoreo concurrente de STATUS ───────────────────────────────────────
  bit          poll_status_en     = 0;
  int unsigned poll_period_cycles = 5;

  // ── Manejo de IRQ al final ────────────────────────────────────────────────
  bit irq_clear_en = 0;

  // ── Casos esquina via RAL ─────────────────────────────────────────────────
  bit          illegal_ctrl_write_en = 0;
  int unsigned illegal_ctrl_size     = 3;
  int unsigned illegal_ctrl_offset   = 0;
  bit          clear_fifo_cnt_en     = 0;

  function new(string name = "aligner_main_seq");
    super.new(name);
  endfunction

  // ══════════════════════════════════════════════════════════════════════════
  // Tareas de registros
  // ══════════════════════════════════════════════════════════════════════════

  task configure_ctrl(int unsigned size, int unsigned offset);
    uvm_status_e   status;
    uvm_reg_data_t val = (32'(offset) << 8) | 32'(size);
    regmodel.CTRL.write(status, val);
    if (status != UVM_IS_OK)
      `uvm_error("SEQ",
        $sformatf("CTRL write FAILED size=%0d off=%0d", size, offset))
    else
      `uvm_info("SEQ",
        $sformatf("CTRL <- 0x%08h  (size=%0d  offset=%0d)", val, size, offset), UVM_MEDIUM)
  endtask

  task configure_irqen();
    uvm_status_e status;
    regmodel.IRQEN.write(status, 32'(irqen_val));
    if (status != UVM_IS_OK)
      `uvm_error("SEQ", "IRQEN write FAILED")
    else
      `uvm_info("SEQ",
        $sformatf("IRQEN <- 0x%02h  [RX_E=%0b RX_F=%0b TX_E=%0b TX_F=%0b DROP=%0b]",
                  irqen_val,
                  irqen_val[0], irqen_val[1], irqen_val[2],
                  irqen_val[3], irqen_val[4]), UVM_MEDIUM)
  endtask

  task read_status();
    uvm_status_e   status;
    uvm_reg_data_t val;
    regmodel.STATUS.read(status, val);
    `uvm_info("SEQ",
      $sformatf("STATUS: CNT_DROP=%0d  RX_LVL=%0d  TX_LVL=%0d",
                val[7:0], val[11:8], val[19:16]), UVM_MEDIUM)
  endtask

  task handle_irq();
    uvm_status_e   status;
    uvm_reg_data_t irq_val;
    regmodel.IRQ.read(status, irq_val);
    `uvm_info("SEQ",
      $sformatf("IRQ: 0x%08h  [RX_E=%0b RX_F=%0b TX_E=%0b TX_F=%0b DROP=%0b]",
                irq_val,
                irq_val[0], irq_val[1], irq_val[2],
                irq_val[3], irq_val[4]), UVM_MEDIUM)
    if (irq_val != '0) begin
      regmodel.IRQ.write(status, irq_val);
      `uvm_info("SEQ", "IRQ flags cleared (W1C)", UVM_MEDIUM)
    end
  endtask

  task do_illegal_ctrl_write();
    uvm_status_e   status;
    uvm_reg_data_t val = (32'(illegal_ctrl_offset) << 8) | 32'(illegal_ctrl_size);
    `uvm_info("SEQ",
      $sformatf("[ILLEGAL CTRL] size=%0d off=%0d (debe dar slverr)",
                illegal_ctrl_size, illegal_ctrl_offset), UVM_LOW)
    regmodel.CTRL.write(status, val);
    if (status == UVM_IS_OK)
      `uvm_warning("SEQ", "CTRL write ilegal NO generó slverr – revisar DUT")
    else
      `uvm_info("SEQ", "CTRL write ilegal rechazado correctamente (slverr)", UVM_LOW)
  endtask

  // Espera a que el DUT drene sus FIFOs antes de cambiar CTRL.
  // Garantiza que no queden bytes en tránsito al momento del cambio.
  task wait_for_drain();
    uvm_status_e   status;
    uvm_reg_data_t val;
    do begin
      regmodel.STATUS.read(status, val);
    end while (val[11:8] != 0 || val[19:16] != 0);  // RX_LVL==0 && TX_LVL==0
    `uvm_info("SEQ", "DUT drenado: RX_LVL=0 TX_LVL=0", UVM_MEDIUM)
  endtask

  task do_clear_fifo_cnt();
    uvm_status_e   status;
    uvm_reg_data_t val;
    regmodel.CTRL.read(status, val);
    val[16] = 1'b1;
    regmodel.CTRL.write(status, val);
    `uvm_info("SEQ", "CTRL.CLR=1 → CNT_DROP limpiado", UVM_MEDIUM)
  endtask

  // ══════════════════════════════════════════════════════════════════════════
  // Tarea de inyección de un paquete RX
  // ══════════════════════════════════════════════════════════════════════════

  task send_pkt(int unsigned idx);
    md_seq_item #(32) tr;
    bit ok;

    tr = md_seq_item #(32)::type_id::create($sformatf("pkt%0d", idx));
    start_item(tr);

    case (rx_size_mode)
      RX_SIZE_RAND:
        ok = tr.randomize();

      RX_SIZE_MATCH_CTRL:
        ok = tr.randomize() with { err == 1'b0; size == ctrl_size; };

      RX_SIZE_GT_CTRL: begin
        if (ctrl_size < 4)
          ok = tr.randomize() with { err == 1'b0; size > ctrl_size; };
        else begin
          `uvm_warning("SEQ", "RX_SIZE_GT_CTRL: ctrl_size ya es máximo (4)")
          ok = tr.randomize() with { err == 1'b0; size == 4; };
        end
      end

      RX_SIZE_LT_CTRL: begin
        if (ctrl_size > 1)
          ok = tr.randomize() with { err == 1'b0; size < ctrl_size; size > 0; };
        else begin
          `uvm_warning("SEQ", "RX_SIZE_LT_CTRL: ctrl_size ya es mínimo (1)")
          ok = tr.randomize() with { err == 1'b0; size == 1; };
        end
      end

      RX_SIZE_ILLEGAL: begin
        tr.c_legal_combo.constraint_mode(0);
        tr.c_err_default.constraint_mode(0);
        ok = tr.randomize() with { size > 1; };
        tr.c_legal_combo.constraint_mode(1);
        tr.c_err_default.constraint_mode(1);
      end

      default:
        ok = tr.randomize();
    endcase

    if (!ok)
      `uvm_fatal("SEQ", $sformatf("randomize() falló en pkt%0d", idx))

    finish_item(tr);
    `uvm_info("SEQ",
      $sformatf("[RX %0d/%0d] %s", idx+1, n_packets, tr.convert2string()), UVM_MEDIUM)
  endtask

  // ══════════════════════════════════════════════════════════════════════════
  // Body: orquestación principal
  // ══════════════════════════════════════════════════════════════════════════
  task body();
    bit          traffic_done = 0;
    int unsigned ctrl_change_interval;

    `uvm_info("SEQ", $sformatf(
      {"\n=== aligner_main_seq START ===\n",
       "  CTRL   : size=%0d  offset=%0d\n",
       "  IRQEN  : 0x%02h\n",
       "  PKTs   : %0d  gap=%0d cyc  rx_mode=%s\n",
       "  BP     : %s (delay=%0d)\n",
       "  num_ctrl_changes=%0d  poll_status=%0b(%0d cyc)\n",
       "  irq_clear=%0b  illegal_ctrl=%0b  clr_cnt=%0b"},
      ctrl_size, ctrl_offset, irqen_val,
      n_packets, inter_pkt_cycles, rx_size_mode.name(),
      bp_mode.name(), bp_delay,
      num_ctrl_changes, poll_status_en, poll_period_cycles,
      irq_clear_en, illegal_ctrl_write_en, clear_fifo_cnt_en), UVM_LOW)

    ctrl_change_interval = (num_ctrl_changes > 0)
                           ? n_packets / (num_ctrl_changes + 1)
                           : 0;

    // ── 1. Setup inicial ──────────────────────────────────────────────────
    configure_ctrl(ctrl_size, ctrl_offset);
    configure_irqen();

    // ── 2. Opcional: write ilegal a CTRL (pre-tráfico) ────────────────────
    if (illegal_ctrl_write_en)
      do_illegal_ctrl_write();

    // ── 3. Configurar backpressure TX ─────────────────────────────────────
    if (tx_drv != null)
      tx_drv.set_bp_mode(bp_mode, bp_delay);

    // ── 4. Tráfico RX + monitoreo concurrente de STATUS ───────────────────
    fork

      begin  // hilo de tráfico
        for (int i = 0; i < n_packets; i++) begin

          // Cambio de CTRL en los puntos calculados
          if (ctrl_change_interval > 0 &&
              i > 0 && (i % ctrl_change_interval) == 0) begin
            wait_for_drain();  // asegura FIFOs vacíos antes de cambiar config
            if (!this.randomize(rnd_ctrl_size, rnd_ctrl_offset))
              `uvm_fatal("SEQ", "Fallo al randomizar combo de CTRL")
            ctrl_size   = rnd_ctrl_size;
            ctrl_offset = rnd_ctrl_offset;
            configure_ctrl(ctrl_size, ctrl_offset);
          end

          if (i > 0 && inter_pkt_cycles > 0)
            #(inter_pkt_cycles * 10);

          send_pkt(i);
        end
        traffic_done = 1;
      end

      begin  // hilo de STATUS
        while (!traffic_done) begin
          if (poll_status_en)
            read_status();
          #(poll_period_cycles * 10);
        end
      end

    join

    // ── 5. Post-tráfico ───────────────────────────────────────────────────
    if (clear_fifo_cnt_en)
      do_clear_fifo_cnt();

    read_status();

    if (irq_clear_en)
      handle_irq();

    `uvm_info("SEQ", "=== aligner_main_seq DONE ===", UVM_LOW)
  endtask

endclass
