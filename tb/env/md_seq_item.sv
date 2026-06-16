`ifndef MD_SEQ_ITEM_SV
`define MD_SEQ_ITEM_SV

// Clase de item de secuencia para transacciones MD RX y MD TX, con campos para datos, offset, tamaño, error y un flag de error recibido.
class md_seq_item #(
  parameter int ALGN_DATA_WIDTH   = 32,
  parameter int ALGN_OFFSET_WIDTH = (ALGN_DATA_WIDTH <= 8) ? 1 : $clog2(ALGN_DATA_WIDTH/8),
  parameter int ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8) + 1
) extends uvm_sequence_item;

  localparam int BUS_BYTES = ALGN_DATA_WIDTH / 8;

  // Registro de la fábrica
  `uvm_object_param_utils_begin(md_seq_item #(ALGN_DATA_WIDTH))
    `uvm_field_int(data,    UVM_ALL_ON)
    `uvm_field_int(offset,  UVM_ALL_ON)
    `uvm_field_int(size,    UVM_ALL_ON)
    `uvm_field_int(err,     UVM_ALL_ON)
    `uvm_field_int(got_err, UVM_ALL_ON)
  `uvm_object_utils_end

  rand logic [ALGN_DATA_WIDTH-1:0]   data;

  rand logic [ALGN_OFFSET_WIDTH-1:0] offset;

  rand logic [ALGN_SIZE_WIDTH-1:0]   size;

  rand logic                         err;

  logic                              got_err;

  function new(string name = "md_seq_item");
    super.new(name);
  endfunction

  // Restricciones 
  constraint c_size_nonzero {
    size != 0;
  }

  constraint c_size_max {
    size <= BUS_BYTES;
  }

  constraint c_offset_range {
    offset < BUS_BYTES;
  }

  constraint c_legal_combo {
    (BUS_BYTES + offset) % size == 0;
  }

  constraint c_err_default {
    err == 1'b0;
  }

  // convert2string: imprime el item de manera legible en los logs UVM.
  function string convert2string();
    return $sformatf(
      "[MD] data=0x%0h offset=%0d size=%0d err=%0b got_err=%0b",
      data, offset, size, err, got_err
    );
  endfunction

  // is_legal: función para verificar si la combinación de offset y size es legal según las reglas de alineación del bus. 
  function bit is_legal();
    if (size == 0) return 0;
    return (((BUS_BYTES + offset) % size) == 0);
  endfunction

endclass

`endif
