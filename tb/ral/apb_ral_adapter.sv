///////////////////////////////////////////////////////////////////////////////
// File:        apb_ral_adapter.sv
// Description: Adaptador RAL↔APB. Convierte entre uvm_reg_bus_op (operación
//              abstracta del modelo de registros) y apb_seq_item (transacción
//              concreta del bus APB).
//
//              reg2bus(): RAL le pide una escritura/lectura → crea apb_seq_item
//              bus2reg(): el monitor publica un apb_seq_item → RAL lo ingiere
///////////////////////////////////////////////////////////////////////////////
`ifndef APB_RAL_ADAPTER_SV
`define APB_RAL_ADAPTER_SV

class apb_ral_adapter extends uvm_reg_adapter;
  `uvm_object_utils(apb_ral_adapter)

  function new(string name = "apb_ral_adapter");
    super.new(name);
    supports_byte_enable = 0;  // APB no tiene byte enables en este DUT
    provides_responses   = 0;  // el driver actualiza el item antes de item_done
  endfunction

  // ── Modelo de registros → transacción APB ────────────────────────────────
  virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    apb_seq_item tr = apb_seq_item::type_id::create("tr");
    tr.addr  = rw.addr[15:0];
    tr.data  = rw.data[31:0];
    tr.write = (rw.kind == UVM_WRITE);
    return tr;
  endfunction

  // ── Transacción APB → modelo de registros ────────────────────────────────
  virtual function void bus2reg(uvm_sequence_item bus_item,
                                ref uvm_reg_bus_op rw);
    apb_seq_item tr;
    if (!$cast(tr, bus_item))
      `uvm_fatal("BUS2REG", "apb_ral_adapter: tipo de item incorrecto")
    rw.kind   = tr.write ? UVM_WRITE : UVM_READ;
    rw.addr   = tr.addr;
    rw.data   = tr.data;
    rw.status = tr.slverr ? UVM_NOT_OK : UVM_IS_OK;
  endfunction

endclass

`endif
