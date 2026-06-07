class apb_reg_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_reg_seq)

  ALIGNER regmodel;

  function new(string name = "apb_reg_seq");
    super.new(name);
  endfunction

  task body();
    uvm_status_e   status;
    uvm_reg_data_t val;

    // ── Test 1: CTRL default (SIZE=1, OFFSET=0) ────────────────────────────
    `uvm_info("SEQ", "\n=== Test 1: CTRL default value (SIZE=1, OFFSET=0) ===", UVM_LOW)
    regmodel.CTRL.read(status, val);
    if (val[2:0] === 3'h1 && val[9:8] === 2'h0)
      `uvm_info("SEQ",  $sformatf("PASS T1: CTRL = 0x%08h", val), UVM_LOW)
    else
      `uvm_error("SEQ", $sformatf("FAIL T1: expected SIZE=1 OFFSET=0, got 0x%08h", val))

    // ── Test 2: Write CTRL SIZE=4, OFFSET=0, read back ────────────────────
    `uvm_info("SEQ", "\n=== Test 2: Write CTRL SIZE=4, OFFSET=0 ===", UVM_LOW)
    regmodel.CTRL.write(status, 32'h0000_0004);
    regmodel.CTRL.read(status, val);
    if (val[2:0] === 3'h4)
      `uvm_info("SEQ",  $sformatf("PASS T2: CTRL = 0x%08h", val), UVM_LOW)
    else
      `uvm_error("SEQ", $sformatf("FAIL T2: expected SIZE=4, got 0x%08h", val))
  endtask

endclass


class md_passthrough_seq extends uvm_sequence #(md_seq_item #(32));
  `uvm_object_utils(md_passthrough_seq)

  function new(string name = "md_passthrough_seq");
    super.new(name);
  endfunction

  task body();
    md_seq_item #(32) tr;

    `uvm_info("SEQ", "\n=== Test 3: RX→TX passthrough (0xDEADBEEF, size=4) ===", UVM_LOW)
    tr = md_seq_item #(32)::type_id::create("tr");
    start_item(tr);
    tr.data   = 32'hDEAD_BEEF;
    tr.size   = 3'd4;
    tr.offset = 2'd0;
    tr.err    = 1'b0;
    finish_item(tr);
  endtask

endclass


class apb_basic_test extends uvm_test;
  `uvm_component_utils(apb_basic_test)

  aligner_env env;

  function new(string name = "apb_basic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = aligner_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_reg_seq        apb_seq;
    md_passthrough_seq md_seq;
    phase.raise_objection(this);

    // Tests 1 y 2: configuración de registros via RAL
    apb_seq          = apb_reg_seq::type_id::create("apb_seq");
    apb_seq.regmodel = env.regmodel;
    apb_seq.start(env.apb_agt.sqr);

    // Test 3: flujo MD RX→TX; el scoreboard verifica el TX automáticamente
    md_seq = md_passthrough_seq::type_id::create("md_seq");
    md_seq.start(env.md_agt.sqr);

    // Margen para que el TX llegue y el scoreboard lo procese
    #500;

    phase.drop_objection(this);
  endtask

endclass
