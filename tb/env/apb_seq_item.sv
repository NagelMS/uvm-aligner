///////////////////////////////////////////////////////////////////////////////
// File:        apb_seq_item.sv
// Description: Transaccion APB. Representa una escritura o lectura al DUT.
//              Los campos addr/data/write son compatibles con uvm_reg_bus_op
//              para que el adaptador RAL pueda convertirlos directamente.
///////////////////////////////////////////////////////////////////////////////
`ifndef APB_SEQ_ITEM_SV
`define APB_SEQ_ITEM_SV

class apb_seq_item extends uvm_sequence_item;

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(data,   UVM_ALL_ON)
    `uvm_field_int(write,  UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  rand logic [15:0] addr;
  rand logic [31:0] data;
  rand logic        write;   // 1 = escritura, 0 = lectura
       logic        slverr;  // respuesta del DUT (no aleatorizable)

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("[APB] %s addr=0x%04h data=0x%08h slverr=%0b",
                     write ? "WR" : "RD", addr, data, slverr);
  endfunction

endclass

`endif
