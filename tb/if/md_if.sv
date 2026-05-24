interface md_if #(
  parameter int ALGN_DATA_WIDTH   = 32,
  parameter int ALGN_OFFSET_WIDTH = (ALGN_DATA_WIDTH <= 8) ? 1 : $clog2(ALGN_DATA_WIDTH/8),
  parameter int ALGN_SIZE_WIDTH   = $clog2(ALGN_DATA_WIDTH/8) + 1
)(
  input logic clk
);

  logic                          reset_n;
  logic                          valid;
  logic [ALGN_DATA_WIDTH-1:0]   data;
  logic [ALGN_OFFSET_WIDTH-1:0] offset;
  logic [ALGN_SIZE_WIDTH-1:0]   size;
  logic                          ready;
  logic                          err;

  // Puertos RX del Alineador
  modport md_rx (
    input  clk, reset_n,
    output valid, data, offset, size,
    input  ready, err
  );

  // Puertos TX del Alineador
  modport md_tx (
    input  clk, reset_n,
    input  valid, data, offset, size,
    output ready, err
  );

  // Puertos del monitor solo observa las señales
  modport md_mon (
    input clk, reset_n,
    input valid, data, offset, size, ready, err
  );

endinterface
