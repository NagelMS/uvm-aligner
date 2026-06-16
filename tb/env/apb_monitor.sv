// Monitor UVM para el Alineador, que observa las señales del bus APB, detecta las transferencias completas
class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  uvm_analysis_port #(apb_seq_item) ap;

  virtual apb_if vif;

  function new(string name = "apb_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Etapa de construcción: obtiene la interfaz virtual desde config_db y reporta un error fatal si no se encuentra.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NO_VIF", "apb_monitor: no se encontró apb_vif en config_db")
  endfunction

  // Etapa de ejecución: ciclo infinito de observación de las señales APB, detección de transferencias completas (psel=1, penable=1, pready=1) y publicación de transacciones en el analysis port.
  task run_phase(uvm_phase phase);
    apb_seq_item tr;
    forever begin
      // Esperar flanco donde la transferencia APB completa
      @(posedge vif.clk);
      if (vif.psel && vif.penable && vif.pready) begin
        tr = apb_seq_item::type_id::create("tr");
        tr.addr   = vif.paddr;
        tr.write  = vif.pwrite;
        tr.data   = vif.pwrite ? vif.pwdata : vif.prdata;
        tr.slverr = vif.pslverr;
        `uvm_info("APB_MON", tr.convert2string(), UVM_HIGH)
        ap.write(tr);
      end
    end
  endtask

endclass
