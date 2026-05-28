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
    apb_reg_seq seq;
    phase.raise_objection(this);

    seq          = apb_reg_seq::type_id::create("seq");
    seq.regmodel = env.regmodel;
    seq.start(env.apb_agt.sqr);

    // Dar tiempo al Test 3 (flujo MD manual en el TB) para que complete
    #500;

    phase.drop_objection(this);
  endtask

endclass
