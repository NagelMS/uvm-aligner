`uvm_analysis_imp_decl(_md_rx)
`uvm_analysis_imp_decl(_md_tx)
`uvm_analysis_imp_decl(_apb_bus)

class scoreboard #(parameter DEPTH = 8, WIDTH = 32)extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    //Contadores internos para fallos y exitos
    int m_checks_failed_count = 0;
    int m_checks_passed_count = 0;
    //int m_drop_count          = 0;

    //Variables internas
    int size_config   = 0;
    int offset_config = 0;

    typedef struct {
    logic [31:0] data_tx;
    logic [1:0]  offset_tx;
    logic [2:0]  size_tx;
    } expected_tx_t;

    //Colas
    byte unsigned m_rx_byte_q[$];
    expected_tx_t m_expected_tx_q[$];

    //Modelo del RAL
    ALIGNER m_ral;

    //Analysis ports
    uvm_analysis_imp_apb_bus #(apb_seq_item, scoreboard)    m_analysis_imp_apb_bus;
    uvm_analysis_imp_md_rx   #(md_seq_item,  scoreboard)    m_analysis_imp_md_rx;
    uvm_analysis_imp_md_tx   #(md_seq_item,  scoreboard)    m_analysis_imp_md_tx;

    //Constructor
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //Fase Build
    function void build_phase(uvm_component phase);
        super.build_phase(phase);

        //Extraer el RAL del config_db
        if(!uvm_config_db #(ALIGNER)::get(this, "", "ral", m_ral))
            `uvm_fatal("SCB", "RAL no se encuentra en config_db, instanciar en el ambiente")
        
        m_analysis_imp_apb_bus = new("m_analysis_imp_apb_bus", this);
        m_analysis_imp_md_rx   = new("m_analysis_imp_md_rx", this);
        m_analysis_imp_md_tx   = new("m_analysis_imp_md_tx", this);

    endfunction


    function void write_apb_bus(apb_seq_item item);
        logic [15:0] apb_addr = {item.addr[15:2], 2'b00};

        if(item.write) begin
            check_apb_write(item, apb_addr);
        end 
        else begin
            check_apb_read(item, apb_addr);
        end
    endfunction

    function void check_apb_write(apb_seq_item item, logic [15:0] addr);
        case(addr)
        //Control (0x0000) no error en escritura
            16'h0000: begin
                logic [2:0] new_size   = item.data[2:0];
                logic [1:0] new_offset = item.data[9:8];
                logic       new_clr    = item.data[16];

                //Size = 0 es ilegal
                case(new_size)
                    3'd1: begin
                        check_pslverr(item, 1'b0, "Combinacion size y offset validos");
                        size_config   = int'(new_size);
                        offset_config = int'(new_offset);
                    end
                    3'd2: begin
                        if(new_offset == 2'd0 or new_offset == 2'd2)begin
                            check_pslverr(item, 1'b0, "Combinacion size y offset validos");
                            size_config   = int'(new_size);
                            offset_config = int'(new_offset);
                        end
                        else check_pslverr(item, 1'b1, "Combinacion size y offset invalidos");
                    end
                    3'd4: begin
                        if(new_offset == 2'd0)begin
                            check_pslverr(item, 1'b0, "Combinacion size y offset validos");
                            size_config   = int'(new_size);
                            offset_config = int'(new_offset);
                        end
                        else check_pslverr(item, 1'b1, "Combinacion size y offset invalidos");
                    end
                    default: begin 
                        check_pslverr(item, 1'b1, "Size invalido");
                    end
                endcase
            end
        //Status (0x000C) error en escritura
            16'h000C: begin
                check_pslverr(item, 1'b1, "No se debe escribir en STATUS, direccion invalida");
            end
        //IRQEN (0x00F0)
            16'h00F0: begin
                check_pslverr(item, 1'b0, "Direccion valida para escritura");
            end
        //IRQ (0x00F4)
            16'h00F4: begin
                check_pslverr(item, 1'b0, "Direccion valida para escritura");
            end
        //Direcciones no mapeadas
            default: check_pslverr(item, 1'b1, "Direccion invalida para escritura");
        endcase 
    endfunction

    function void check_apb_read(apb_seq_item item, logic [15:0] addr);
        uvm_reg registro;
        uvm_reg_data_t mirror_val;

        case(addr)
        //Control (0x0000) Status (0x000C) IRQEN (0x00F0) IRQ (0x00F4) direcciones validas
            16'h0000, 16'h000C, 16'h00F0, 16'h00F4: begin
                check_pslverr(item, 1'b0, $sformatf("Lectura en direccion 0x%04h no genera error", addr));

                if(!item.pslverr)begin
                    registro = m_ral.default_map.get_reg_by_offset(addr);
                    if(registro == null) begin
                        `uvm_error("SCB", $sformatf("RAL: no hay registro encontrado en 0x%04h", word_addr))
                        m_checks_failed_count++;
                        return;
                    end

                    mirror_val = registro.get();
                    if (addr == 16'h0000) begin
                        mirror_val[16] = 1'b0; // CLR bit siempre lee 0
                    end

                    check_field(item.data, mirror_val, $sformatf("data vs RAL mirror en 0x%04h", addr));
                end
            end
        
        //Direcciones no mapeadas
            default: check_pslverr(item, 1'b1, "Direcciones invalidas para lectura")
        endcase 
    endfunction

    function void check_pslverr(apb_seq_item item, logic exp_error, string msg);
        if(item.pslverr !== exp_error) begin
            `uvm_error("SCB", $sformatf("%s , pslverr obtuvo  %0b  esperaba %0b", msg, item.pslverr, exp_err))
            m_checks_failed_count++;
        end
        else begin
            `uvm_info("SCB", $sformatf("PASS: %s", msg), UVM_HIGH)
            m_checks_passed_count++;
        end
    endfunction

    function void check_field(logic [31:0] dato_obtenido, logic [31:0] dato_esperado, string msg);
        if (dato_obtenido !== dato_esperado) begin
            `uvm_error("SCB", $sformatf("%s : dato_obtenido 0x%08h  dato_esperado 0x%08h", msg, dato_obtenido, dato_esperado))
            m_checks_failed_count++;
        end 
        else begin
            `uvm_info("SCB", $sformatf("PASS: %s", msg), UVM_HIGH)
            m_checks_passed_count++;
        end
    endfunction

    function void write_md_rx(md_seq_item item);
        int unsigned rx_size   = int'(item.size);
        int unsigned rx_offset = int'(item.offset);

        //Verificar si es invalido el dato de entrada:
        if (!rx_valido(rx_offset, rx_size)) begin
            //Se espera rx_err = 1
            if (!item.err) begin
                `uvm_error("SCB", $sformatf("Error en el sistema, rx no valido (offset=%0d size=%0d): se esperaba md_rx_err=1, se obtuvo 0", rx_offset, rx_size))
                m_checks_failed_count++;
            end 
            else begin
                `uvm_info("SCB", $sformatf("PASS: deteccion correcta de rx ilegal (offset=%0d size=%0d)", rx_offset, rx_size), UVM_MEDIUM)
                m_checks_passed_count++;
            end

            return; // transferencia invalida no genera valor
        end
        //Transferencia valida
        if (item.err) begin
            `uvm_error("SCB", $sformatf("Transferencia era valida MD RX (offset=%0d size=%0d): inesperador error md_rx_err=1", rx_offset, rx_size))
            m_checks_failed_count++;
        end 
        else begin
            m_checks_passed_count++;
        end
        //Extrae los bytes validos del bus y los coloca en cola
        for (int b = rx_offset; b < rx_offset + rx_size; b++)begin
            m_rx_byte_q.push_back(item.data[b*8 +: 8]);
        end

        // Generar el tx esperado requiere que se cumpla la configuracion actual del RAL
        generate_expected_tx();
    endfunction

    function automatic bit rx_valido(int unsigned offset, int unsigned size);
        if (size == 0) return 0;
        return ((4 + offset) % size == 0);
    endfunction

    function void generate_expected_tx();

        automatic int unsigned tx_size   = int'(size_config);
        automatic int unsigned tx_offset = int'(offset_config);

        while (m_rx_byte_q.size() >= tx_size) begin
            expected_tx_t exp;
            exp.data_tx   = '0;
            exp.offset_tx = tx_offset[1:0];
            exp.size_tx   = tx_size[2:0];

            for (int b = 0; b < tx_size; b++)begin
                exp.data_tx[(tx_offset + b)*8 +: 8] = m_rx_byte_q.pop_front();
            end
            m_expected_tx_q.push_back(exp);
        end
  endfunction

  function void write_md_tx(md_seq_item item);

    expected_tx_t exp;

    if (m_expected_tx_q.size() == 0) begin
      `uvm_error("SCB", "Unexpected MD TX transfer – expected queue is empty")
      m_checks_failed_count++;
      return;
    end

    exp = m_expected_tx_q.pop_front();

    // -- offset --------------------------------------------------------------
    if (item.offset !== exp.offset_tx) begin
      `uvm_error("SCB",
        $sformatf("MD TX offset distintos: se obtiene: %0d  se espera: %0d",
                  item.offset, exp.offset_tx))
      m_checks_failed_count++;
    end else begin
      m_checks_passed_count++;
    end

    // -- size ----------------------------------------------------------------
    if (item.size !== exp.size) begin
      `uvm_error("SCB",
        $sformatf("MD TX size distinto: se obtiene: %0d  se espera: %0d",
                  item.size, exp.size))
      m_checks_failed_count++;
    end else begin
      m_checks_passed_count++;
    end

    // -- data (only valid byte lanes) ----------------------------------------
    begin
      automatic int unsigned sz  = int'(exp.size);
      automatic int unsigned off = int'(exp.offset);
      logic [31:0] mask = '0;
      for (int b = off; b < off + sz; b++)
        mask[b*8 +: 8] = 8'hFF;

      if ((item.data & mask) !== (exp.data & mask)) begin
        `uvm_error("SCB",
          $sformatf("MD TX data distinto: se obtiene: 0x%08h  se espera: 0x%08h  (mask 0x%08h)",
                    item.data & mask, exp.data & mask, mask))
        m_checks_failed_count++;
      end else begin
        m_checks_passed_count++;
      end
    end

    // -- md_tx_err must be 0 on a normal transfer ----------------------------
    if (item.err) begin
      `uvm_error("SCB", "Unexpected md_tx_err=1 on TX transfer")
      m_checks_failed_count++;
    end else begin
      m_checks_passed_count++;
    end

    `uvm_info("SCB",
      $sformatf("TX correcto: data=0x%08h offset=%0d size=%0d",
                item.data, item.offset, item.size), UVM_HIGH)

  endfunction

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