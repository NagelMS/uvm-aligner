`uvm_analysis_imp_decl(_md_rx)
`uvm_analysis_imp_decl(_md_tx)
`uvm_analysis_imp_decl(_apb_bus)

class scoreboard #(
  parameter int DEPTH = 8,
  parameter int WIDTH = 32
) extends uvm_scoreboard;
  `uvm_component_param_utils(scoreboard #(DEPTH, WIDTH))

  int m_checks_failed_count = 0;
  int m_checks_passed_count = 0;

  // Refleja el valor de CTRL en el DUT; se actualiza al ver escrituras APB.
  // Inicial = reset del DUT: SIZE=1, OFFSET=0.
  int size_config   = 1;
  int offset_config = 0;

  typedef struct {
    logic [31:0] data_tx;
    logic [1:0]  offset_tx;
    logic [2:0]  size_tx;
  } expected_tx_t;

  byte unsigned  m_rx_byte_q[$];
  expected_tx_t  m_expected_tx_q[$];

  ALIGNER m_ral;

  uvm_analysis_imp_apb_bus #(apb_seq_item,         scoreboard #(DEPTH, WIDTH)) m_analysis_imp_apb_bus;
  uvm_analysis_imp_md_rx   #(md_seq_item #(WIDTH),  scoreboard #(DEPTH, WIDTH)) m_analysis_imp_md_rx;
  uvm_analysis_imp_md_tx   #(md_seq_item #(WIDTH),  scoreboard #(DEPTH, WIDTH)) m_analysis_imp_md_tx;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db #(ALIGNER)::get(this, "", "ral", m_ral))
      `uvm_fatal("SCB", "RAL no se encuentra en config_db; instanciar en el ambiente")

    m_analysis_imp_apb_bus = new("m_analysis_imp_apb_bus", this);
    m_analysis_imp_md_rx   = new("m_analysis_imp_md_rx",   this);
    m_analysis_imp_md_tx   = new("m_analysis_imp_md_tx",   this);
  endfunction

  // ── APB write/read dispatch ───────────────────────────────────────────────

  function void write_apb_bus(apb_seq_item item);
    logic [15:0] apb_addr = {item.addr[15:2], 2'b00};
    if (item.write) check_apb_write(item, apb_addr);
    else            check_apb_read (item, apb_addr);
  endfunction

  // Drena paquetes completos pendientes con la config actual antes del cambio.
  // Los bytes residuales se preservan: el DUT mantiene su buffer interno
  // y los reusa bajo la nueva configuración de CTRL.
  function void flush_on_ctrl_change();
    generate_expected_tx();
    if (m_rx_byte_q.size() > 0)
      `uvm_info("SCB",
        $sformatf("CTRL change: %0d bytes residuales pasan a nueva config",
                  m_rx_byte_q.size()), UVM_MEDIUM)
  endfunction

  function void check_apb_write(apb_seq_item item, logic [15:0] addr);
    case (addr)
      16'h0000: begin
        logic [2:0] new_size   = item.data[2:0];
        logic [1:0] new_offset = item.data[9:8];
        case (new_size)
          3'd1: begin
            check_pslverr(item, 1'b0, "Combinacion size=1 valida");
            flush_on_ctrl_change();
            size_config   = int'(new_size);
            offset_config = int'(new_offset);
            generate_expected_tx();
          end
          3'd2: begin
            if (new_offset == 2'd0 || new_offset == 2'd2) begin
              check_pslverr(item, 1'b0, "Combinacion size=2 y offset validos");
              flush_on_ctrl_change();
              size_config   = int'(new_size);
              offset_config = int'(new_offset);
              generate_expected_tx();
            end else
              check_pslverr(item, 1'b1, "Combinacion size=2 y offset invalidos");
          end
          3'd4: begin
            if (new_offset == 2'd0) begin
              check_pslverr(item, 1'b0, "Combinacion size=4 y offset=0 validos");
              flush_on_ctrl_change();
              size_config   = int'(new_size);
              offset_config = int'(new_offset);
              generate_expected_tx();
            end else
              check_pslverr(item, 1'b1, "Combinacion size=4 y offset invalidos");
          end
          default: check_pslverr(item, 1'b1, "Size invalido");
        endcase
      end
      16'h000C: check_pslverr(item, 1'b1, "STATUS es RO; escritura debe generar slverr");
      16'h00F0: check_pslverr(item, 1'b0, "IRQEN: direccion valida para escritura");
      16'h00F4: check_pslverr(item, 1'b0, "IRQ: direccion valida para escritura");
      default:  check_pslverr(item, 1'b1, "Direccion no mapeada; escritura debe generar slverr");
    endcase
  endfunction

  function void check_apb_read(apb_seq_item item, logic [15:0] addr);
    uvm_reg        registro;
    uvm_reg_data_t mirror_val;

    case (addr)
      16'h0000, 16'h000C, 16'h00F0, 16'h00F4: begin
        check_pslverr(item, 1'b0,
          $sformatf("Lectura en 0x%04h no debe generar slverr", addr));

        if (!item.slverr) begin
          registro = m_ral.default_map.get_reg_by_offset(addr);
          if (registro == null) begin
            `uvm_error("SCB", $sformatf("RAL: sin registro en 0x%04h", addr))
            m_checks_failed_count++;
            return;
          end
          mirror_val = registro.get();
          if (addr == 16'h0000)
            mirror_val[16] = 1'b0;  // CLR es WO; siempre lee 0
          check_field(item.data, mirror_val[31:0],
            $sformatf("data vs RAL mirror en 0x%04h", addr));
        end
      end
      default: check_pslverr(item, 1'b1, "Direccion no mapeada; lectura debe generar slverr");
    endcase
  endfunction

  function void check_pslverr(apb_seq_item item, logic exp_error, string msg);
    if (item.slverr !== exp_error) begin
      `uvm_error("SCB",
        $sformatf("%s: slverr obtuvo %0b esperaba %0b", msg, item.slverr, exp_error))
      m_checks_failed_count++;
    end else begin
      `uvm_info("SCB", $sformatf("PASS: %s", msg), UVM_HIGH)
      m_checks_passed_count++;
    end
  endfunction

  function void check_field(logic [31:0] obtenido, logic [31:0] esperado, string msg);
    if (obtenido !== esperado) begin
      `uvm_error("SCB",
        $sformatf("%s: obtenido 0x%08h esperado 0x%08h", msg, obtenido, esperado))
      m_checks_failed_count++;
    end else begin
      `uvm_info("SCB", $sformatf("PASS: %s", msg), UVM_HIGH)
      m_checks_passed_count++;
    end
  endfunction

  // ── MD RX: acumula bytes y genera TX esperado ─────────────────────────────

  function void write_md_rx(md_seq_item #(WIDTH) item);
    int unsigned rx_size   = int'(item.size);
    int unsigned rx_offset = int'(item.offset);

    if (!rx_valido(rx_offset, rx_size)) begin
      if (!item.err) begin
        `uvm_error("SCB",
          $sformatf("RX ilegal (offset=%0d size=%0d): esperaba err=1, obtuvo 0",
                    rx_offset, rx_size))
        m_checks_failed_count++;
      end else begin
        `uvm_info("SCB",
          $sformatf("PASS: deteccion correcta de RX ilegal (offset=%0d size=%0d)",
                    rx_offset, rx_size), UVM_MEDIUM)
        m_checks_passed_count++;
      end
      return;
    end

    if (item.err) begin
      `uvm_error("SCB",
        $sformatf("RX valido (offset=%0d size=%0d): inesperado err=1",
                  rx_offset, rx_size))
      m_checks_failed_count++;
    end else
      m_checks_passed_count++;

    for (int b = rx_offset; b < rx_offset + rx_size; b++)
      m_rx_byte_q.push_back(item.data[b*8 +: 8]);

    generate_expected_tx();
  endfunction

  function automatic bit rx_valido(int unsigned offset, int unsigned size);
    if (size == 0) return 0;
    return ((4 + offset) % size == 0);
  endfunction

  function void generate_expected_tx();
    automatic int unsigned tx_size   = int'(size_config);
    automatic int unsigned tx_offset = int'(offset_config);

    while (tx_size > 0 && m_rx_byte_q.size() >= tx_size) begin
      expected_tx_t exp;
      exp.data_tx   = '0;
      exp.offset_tx = tx_offset[1:0];
      exp.size_tx   = tx_size[2:0];
      for (int b = 0; b < tx_size; b++)
        exp.data_tx[(tx_offset + b)*8 +: 8] = m_rx_byte_q.pop_front();
      m_expected_tx_q.push_back(exp);
    end
  endfunction

  // ── MD TX: verifica contra el TX esperado ────────────────────────────────

  function void write_md_tx(md_seq_item #(WIDTH) item);
    expected_tx_t exp;

    if (m_expected_tx_q.size() == 0) begin
      `uvm_error("SCB", "TX inesperado: la cola de esperados está vacía")
      m_checks_failed_count++;
      return;
    end

    exp = m_expected_tx_q.pop_front();

    if (item.offset !== exp.offset_tx) begin
      `uvm_error("SCB",
        $sformatf("MD TX offset: obtenido %0d esperado %0d",
                  item.offset, exp.offset_tx))
      m_checks_failed_count++;
    end else
      m_checks_passed_count++;

    if (item.size !== exp.size_tx) begin
      `uvm_error("SCB",
        $sformatf("MD TX size: obtenido %0d esperado %0d",
                  item.size, exp.size_tx))
      m_checks_failed_count++;
    end else
      m_checks_passed_count++;

    begin
      automatic int unsigned sz  = int'(exp.size_tx);
      automatic int unsigned off = int'(exp.offset_tx);
      logic [31:0] mask = '0;
      for (int b = off; b < off + sz; b++)
        mask[b*8 +: 8] = 8'hFF;

      if ((item.data & mask) !== (exp.data_tx & mask)) begin
        `uvm_error("SCB",
          $sformatf("MD TX data: obtenido 0x%08h esperado 0x%08h (mask 0x%08h)",
                    item.data & mask, exp.data_tx & mask, mask))
        m_checks_failed_count++;
      end else
        m_checks_passed_count++;
    end

    if (item.err) begin
      `uvm_error("SCB", "md_tx_err=1 inesperado en transferencia normal")
      m_checks_failed_count++;
    end else
      m_checks_passed_count++;

    `uvm_info("SCB",
      $sformatf("TX correcto: data=0x%08h offset=%0d size=%0d",
                item.data, item.offset, item.size), UVM_MEDIUM)
  endfunction

  // ── Reporte final ─────────────────────────────────────────────────────────

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB", $sformatf(
      {"\n============================================\n",
       "  ALIGNER SCOREBOARD SUMMARY\n",
       "  Checks PASSED : %0d\n",
       "  Checks FAILED : %0d\n",
       "============================================"},
      m_checks_passed_count, m_checks_failed_count), UVM_NONE)
  endfunction

endclass
