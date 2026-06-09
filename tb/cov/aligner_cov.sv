/module aligner_cov #(
  parameter int ALGN_DATA_WIDTH = 32,
  parameter int FIFO_DEPTH      = 8
)(
  input logic        clk,
  input logic        reset_n,

  // APB
  input logic [15:0] paddr,
  input logic        pwrite,
  input logic        psel,
  input logic        penable,
  input logic [31:0] pwdata,
  input logic        pready,
  input logic [31:0] prdata,
  input logic        pslverr,

  // MD RX  (ALGN_DATA_WIDTH=32 → offset[1:0], size[2:0])
  input logic        md_rx_valid,
  input logic [31:0] md_rx_data,
  input logic [1:0]  md_rx_offset,
  input logic [2:0]  md_rx_size,
  input logic        md_rx_ready,
  input logic        md_rx_err,

  // MD TX
  input logic        md_tx_valid,
  input logic [31:0] md_tx_data,
  input logic [1:0]  md_tx_offset,
  input logic [2:0]  md_tx_size,
  input logic        md_tx_ready,
  input logic        md_tx_err,

  // IRQ
  input logic        irq
);



  // Transferencia APB completada sin error
  wire apb_ok     = psel & penable & pready & !pslverr;
  // Escritura legal al registro CTRL (addr 0x0000)
  wire ctrl_wr    = apb_ok &  pwrite & ({paddr[15:2], 2'b00} == 16'h0000);
  // Lectura del registro STATUS (addr 0x000C)
  wire status_rd  = apb_ok & !pwrite & ({paddr[15:2], 2'b00} == 16'h000C);
  // Transferencia RX completada
  wire rx_xfer    = md_rx_valid & md_rx_ready;

  // Sombra de CTRL.SIZE para la comparación rx_vs_ctrl
  logic [2:0] ctrl_size;
  always_ff @(posedge clk or negedge reset_n)
    if (!reset_n) ctrl_size <= 3'd1;   // reset default del DUT
    else if (ctrl_wr) ctrl_size <= pwdata[2:0];

  // Relación entre el tamaño del paquete RX y la configuración CTRL
  typedef enum logic [1:0] {
    RX_LT_CTRL = 2'd0,
    RX_EQ_CTRL = 2'd1,
    RX_GT_CTRL = 2'd2
  } rx_vs_ctrl_e;

  rx_vs_ctrl_e rx_vs_ctrl;
  always_comb
    if      (md_rx_size < ctrl_size)  rx_vs_ctrl = RX_LT_CTRL;
    else if (md_rx_size == ctrl_size) rx_vs_ctrl = RX_EQ_CTRL;
    else                              rx_vs_ctrl = RX_GT_CTRL;

  // Samplea en cada escritura legal al registro CTRL.
  covergroup cg_ctrl @(posedge clk iff ctrl_wr);

    // Tamaños legales del DUT
    cp_size: coverpoint pwdata[2:0] {
      bins size_1 = {3'd1};
      bins size_2 = {3'd2};
      bins size_4 = {3'd4};
    }

    // Offsets posibles
    cp_offset: coverpoint pwdata[9:8] {
      bins offset_0 = {2'd0};
      bins offset_1 = {2'd1};
      bins offset_2 = {2'd2};
      bins offset_3 = {2'd3};
    }

    // Cruz: todas las combinaciones legales de (size, offset)
    // Las ilegales se excluyen del objetivo de cobertura.
    cx_size_offset: cross cp_size, cp_offset {
      ignore_bins illegal_2x1 = binsof(cp_size.size_2) && binsof(cp_offset.offset_1);
      ignore_bins illegal_2x3 = binsof(cp_size.size_2) && binsof(cp_offset.offset_3);
      ignore_bins illegal_4x1 = binsof(cp_size.size_4) && binsof(cp_offset.offset_1);
      ignore_bins illegal_4x2 = binsof(cp_size.size_4) && binsof(cp_offset.offset_2);
      ignore_bins illegal_4x3 = binsof(cp_size.size_4) && binsof(cp_offset.offset_3);
    }

    // Corner case: cambio de CTRL mientras hay un paquete RX en vuelo
    cp_ctrl_with_rx: coverpoint md_rx_valid {
      bins sin_trafico = {1'b0};
      bins con_trafico = {1'b1};
    }

  endgroup


  // Samplea en cada lectura del registro STATUS para capturar el estado real.
  covergroup cg_fifo_lvls @(posedge clk iff status_rd);

    cp_rx_lvl: coverpoint prdata[11:8] {
      bins empty = {4'd0};
      bins low   = {[4'd1 : 4'd3]};
      bins high  = {[4'd4 : 4'd7]};
      bins full  = {FIFO_DEPTH[3:0]};
    }

    cp_tx_lvl: coverpoint prdata[19:16] {
      bins empty = {4'd0};
      bins low   = {[4'd1 : 4'd3]};
      bins high  = {[4'd4 : 4'd7]};
      bins full  = {FIFO_DEPTH[3:0]};
    }

    // Cruz completa: incluye el caso corner de ambas FIFOs llenas
    cx_rx_tx_lvl: cross cp_rx_lvl, cp_tx_lvl;

  endgroup

  // Samplea cada ciclo en que hay actividad en la interfaz.
  covergroup cg_rx @(posedge clk iff (md_rx_valid | md_rx_ready));

    // Estados del handshake
    cp_handshake: coverpoint {md_rx_valid, md_rx_ready} {
      bins transfer    = {2'b11};  // paquete aceptado
      bins bp_dut_full = {2'b10};  // DUT aplica backpressure (RX FIFO lleno)
      bins src_idle    = {2'b01};  // DUT listo pero fuente sin datos
    }

    // Tamaños de paquete observados (incluye size=3 que puede ser ilegal)
    cp_rx_size: coverpoint md_rx_size {
      bins size_1 = {3'd1};
      bins size_2 = {3'd2};
      bins size_3 = {3'd3};
      bins size_4 = {3'd4};
    }

    // Respuesta de error del DUT (paquete ilegal rechazado)
    cp_rx_err: coverpoint md_rx_err {
      bins no_err = {1'b0};
      bins err    = {1'b1};
    }

    // Relación rx_size vs ctrl_size (solo en transferencias reales)
    cp_rx_vs_ctrl: coverpoint rx_vs_ctrl iff rx_xfer {
      bins lt_ctrl = {RX_LT_CTRL};
      bins eq_ctrl = {RX_EQ_CTRL};
      bins gt_ctrl = {RX_GT_CTRL};
    }

    cx_size_err:     cross cp_rx_size, cp_rx_err;
    cx_size_vs_ctrl: cross cp_rx_size, cp_rx_vs_ctrl;

  endgroup

  // Samplea cada ciclo en que hay actividad en la interfaz.
  covergroup cg_tx @(posedge clk iff (md_tx_valid | md_tx_ready));

    cp_handshake: coverpoint {md_tx_valid, md_tx_ready} {
      bins transfer = {2'b11};  // paquete entregado
      bins stall    = {2'b10};  // receptor aplica backpressure (TX FIFO acumula)
      bins underrun = {2'b01};  // receptor listo pero TX FIFO vacío
    }

    cp_tx_size: coverpoint md_tx_size {
      bins size_1 = {3'd1};
      bins size_2 = {3'd2};
      bins size_4 = {3'd4};
    }

    cp_tx_offset: coverpoint md_tx_offset {
      bins offset_0 = {2'd0};
      bins offset_1 = {2'd1};
      bins offset_2 = {2'd2};
      bins offset_3 = {2'd3};
    }

    // Cruz: todas las combinaciones de (size, offset) que produce el alineador
    cx_tx_size_offset: cross cp_tx_size, cp_tx_offset;

  endgroup


  // Samplea únicamente cuando irq está activo (pulso combinatorial de 1 ciclo).
  covergroup cg_irq @(posedge clk iff irq);

    cp_irq_pulse: coverpoint irq {
      bins pulso = {1'b1};
    }

    // Contexto en el momento del pulso IRQ
    cp_tx_active: coverpoint md_tx_valid {
      bins tx_idle   = {1'b0};
      bins tx_active = {1'b1};
    }
    cp_rx_active: coverpoint md_rx_valid {
      bins rx_idle   = {1'b0};
      bins rx_active = {1'b1};
    }

  endgroup

  // ── Sequences ─────────────────────────────────────────────────────────────
  // Transferencia RX completada (valid && ready en el mismo ciclo)
  sequence s_rx_xfer;
    md_rx_valid && md_rx_ready;
  endsequence

  // Transferencia TX completada
  sequence s_tx_xfer;
    md_tx_valid && md_tx_ready;
  endsequence

  // Fase SETUP del bus APB (psel=1, penable=0)
  sequence s_apb_setup;
    psel && !penable;
  endsequence

  // Escritura legal completada al registro CTRL
  sequence s_ctrl_wr_done;
    psel && penable && pready && !pslverr && pwrite &&
    ({paddr[15:2], 2'b00} == 16'h0000);
  endsequence

  // Lectura del registro IRQ completada
  sequence s_irq_rd_done;
    psel && penable && pready && !pwrite &&
    ({paddr[15:2], 2'b00} == 16'h00F4);
  endsequence


  // CP-1: Dos transferencias RX back-to-back (sin ciclo idle entre ellas)
  property p_rx_back_to_back;
    @(posedge clk) s_rx_xfer ##1 s_rx_xfer;
  endproperty
  cov_rx_back_to_back: cover property (p_rx_back_to_back);

  // CP-2: Backpressure RX ≥ 2 ciclos seguido de una transferencia
  property p_rx_backpressure_2;
    @(posedge clk) (md_rx_valid && !md_rx_ready) [*2] ##1 s_rx_xfer;
  endproperty
  cov_rx_backpressure_2: cover property (p_rx_backpressure_2);

  // CP-3: Stall TX ≥ 4 ciclos consecutivos
  property p_tx_stall_4;
    @(posedge clk) (md_tx_valid && !md_tx_ready) [*4];
  endproperty
  cov_tx_stall_4: cover property (p_tx_stall_4);

  // CP-4: Cambio de CTRL mientras hay un paquete RX en vuelo (corner case)
  property p_ctrl_change_mid_traffic;
    @(posedge clk) s_ctrl_wr_done && md_rx_valid;
  endproperty
  cov_ctrl_change_mid_traffic: cover property (p_ctrl_change_mid_traffic);

  // CP-5: Pulso IRQ seguido de lectura del registro IRQ (dentro de 10 ciclos)
  property p_irq_then_irq_rd;
    @(posedge clk) irq ##[1:10] s_irq_rd_done;
  endproperty
  cov_irq_then_irq_rd: cover property (p_irq_then_irq_rd);

  // CP-6: Transición APB SETUP → ACCESS en ciclos consecutivos
  property p_apb_setup_to_access;
    @(posedge clk) s_apb_setup ##1 (psel && penable);
  endproperty
  cov_apb_setup_to_access: cover property (p_apb_setup_to_access);

  // CP-7: Recuperación de error RX: paquete ilegal seguido de uno válido
  property p_rx_err_recovery;
    @(posedge clk)
      (md_rx_err && md_rx_valid && md_rx_ready) ##[1:4] s_rx_xfer;
  endproperty
  cov_rx_err_recovery: cover property (p_rx_err_recovery);

  // CP-8: Respuesta APB de 2 ciclos (solo ocurre en escrituras ilegales a CTRL)
  property p_apb_2cycle_response;
    @(posedge clk)
      (psel && penable && !pready) ##1 (psel && penable && pready);
  endproperty
  cov_apb_2cycle_response: cover property (p_apb_2cycle_response);


  cg_ctrl      m_cg_ctrl;
  cg_fifo_lvls m_cg_fifo_lvls;
  cg_rx        m_cg_rx;
  cg_tx        m_cg_tx;
  cg_irq       m_cg_irq;

  initial begin
    m_cg_ctrl      = new();
    m_cg_fifo_lvls = new();
    m_cg_rx        = new();
    m_cg_tx        = new();
    m_cg_irq       = new();
  end

endmodule

// ── Bind al DUT ───────────────────────────────────────────────────────────────
// Se instancia aligner_cov dentro de cada instancia de cfs_aligner sin
// modificar el RTL. Los puertos se conectan explícitamente por nombre.
bind cfs_aligner aligner_cov #(
  .ALGN_DATA_WIDTH(ALGN_DATA_WIDTH),
  .FIFO_DEPTH     (FIFO_DEPTH)
) u_aligner_cov (
  .clk         (clk),
  .reset_n     (reset_n),
  .paddr       (paddr),
  .pwrite      (pwrite),
  .psel        (psel),
  .penable     (penable),
  .pwdata      (pwdata),
  .pready      (pready),
  .prdata      (prdata),
  .pslverr     (pslverr),
  .md_rx_valid (md_rx_valid),
  .md_rx_data  (md_rx_data),
  .md_rx_offset(md_rx_offset),
  .md_rx_size  (md_rx_size),
  .md_rx_ready (md_rx_ready),
  .md_rx_err   (md_rx_err),
  .md_tx_valid (md_tx_valid),
  .md_tx_data  (md_tx_data),
  .md_tx_offset(md_tx_offset),
  .md_tx_size  (md_tx_size),
  .md_tx_ready (md_tx_ready),
  .md_tx_err   (md_tx_err),
  .irq         (irq)
);
