class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name = "apb_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual apb_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NO_VIF", "apb_driver: no se encontró apb_vif en config_db")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item req;
    _idle();
    // Esperar que el reset sea liberado antes de aceptar items
    if (!vif.reset_n) @(posedge vif.reset_n);
    repeat(2) @(posedge vif.clk);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.write)
        _do_write(req);
      else
        _do_read(req);
      seq_item_port.item_done();
    end
  endtask


  task _idle();
    @(posedge vif.clk); #1;
    vif.paddr   <= '0;
    vif.pwrite  <= 1'b0;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwdata  <= '0;
  endtask

  task _do_write(apb_seq_item req);
    // SETUP phase
    @(posedge vif.clk); #1;
    vif.paddr   <= req.addr;
    vif.pwdata  <= req.data;
    vif.pwrite  <= 1'b1;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;
    // ACCESS phase
    @(posedge vif.clk); #1;
    vif.penable <= 1'b1;
    // Esperar pready (puede tener wait states)
    @(posedge vif.clk);
    while (!vif.pready) @(posedge vif.clk);
    req.slverr = vif.pslverr;
    // De-assert
    #1;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite  <= 1'b0;
  endtask

  task _do_read(apb_seq_item req);
    // SETUP phase
    @(posedge vif.clk); #1;
    vif.paddr   <= req.addr;
    vif.pwrite  <= 1'b0;
    vif.psel    <= 1'b1;
    vif.penable <= 1'b0;
    // ACCESS phase
    @(posedge vif.clk); #1;
    vif.penable <= 1'b1;
    // Esperar pready
    @(posedge vif.clk);
    while (!vif.pready) @(posedge vif.clk);
    req.data   = vif.prdata;
    req.slverr = vif.pslverr;
    // De-assert
    #1;
    vif.psel    <= 1'b0;
    vif.penable <= 1'b0;
  endtask

endclass
