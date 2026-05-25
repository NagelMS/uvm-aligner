///////////////////////////////////////////////////////////////////////////////
// File:        apb_basic_test.sv
// Description: Test temporal para ejercitar el agente APB.
//              Tests 1 y 2: accesos de registro via agente.
//              Test 3: flujo MD manejado directo desde el TB (sin agente MD).
///////////////////////////////////////////////////////////////////////////////
`ifndef APB_BASIC_TEST_SV
`define APB_BASIC_TEST_SV

// ── Secuencia: Tests 1 y 2 (lectura/escritura de registros) ──────────────────
class apb_reg_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_reg_seq)

  function new(string name = "apb_reg_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item tr;

    // ── Test 1: CTRL default (SIZE=1, OFFSET=0) ────────────────────────────
    `uvm_info("SEQ", "\n=== Test 1: CTRL default value (SIZE=1, OFFSET=0) ===", UVM_LOW)
    tr = apb_seq_item::type_id::create("tr");
    start_item(tr);
    tr.addr  = 16'h0000;
    tr.write = 1'b0;
    finish_item(tr);
    if (tr.data === 32'h0000_0001)
      `uvm_info("SEQ",  $sformatf("PASS T1: CTRL = 0x%08h", tr.data), UVM_LOW)
    else
      `uvm_error("SEQ", $sformatf("FAIL T1: expected 0x00000001, got 0x%08h", tr.data))

    // ── Test 2: Write CTRL SIZE=4, OFFSET=0 ───────────────────────────────
    `uvm_info("SEQ", "\n=== Test 2: Write CTRL SIZE=4, OFFSET=0 ===", UVM_LOW)
    tr = apb_seq_item::type_id::create("tr");
    start_item(tr);
    tr.addr  = 16'h0000;
    tr.write = 1'b1;
    tr.data  = 32'h0000_0004;
    finish_item(tr);

    tr = apb_seq_item::type_id::create("tr");
    start_item(tr);
    tr.addr  = 16'h0000;
    tr.write = 1'b0;
    finish_item(tr);
    if (tr.data === 32'h0000_0004)
      `uvm_info("SEQ",  $sformatf("PASS T2: CTRL = 0x%08h", tr.data), UVM_LOW)
    else
      `uvm_error("SEQ", $sformatf("FAIL T2: expected 0x00000004, got 0x%08h", tr.data))
  endtask

endclass


// ── Test ──────────────────────────────────────────────────────────────────────
class apb_basic_test extends uvm_test;
  `uvm_component_utils(apb_basic_test)

  apb_agent agent;

  function new(string name = "apb_basic_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db #(uvm_active_passive_enum)::set(this, "agent", "is_active", UVM_ACTIVE);
    agent = apb_agent::type_id::create("agent", this);
  endfunction

  task run_phase(uvm_phase phase);
    apb_reg_seq seq;
    phase.raise_objection(this);

    seq = apb_reg_seq::type_id::create("seq");
    seq.start(agent.sqr);

    // Dar tiempo al Test 3 (flujo MD manual en el TB) para que complete
    #500;

    phase.drop_objection(this);
  endtask

endclass

`endif
