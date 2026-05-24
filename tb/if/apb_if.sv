interface apb_if #(
  parameter int APB_ADDR_WIDTH = 16,
  parameter int APB_DATA_WIDTH = 32
)(
  input logic clk
);

  logic                       reset_n;
  logic [APB_ADDR_WIDTH-1:0] paddr;
  logic                       pwrite;
  logic                       psel;
  logic                       penable;
  logic [APB_DATA_WIDTH-1:0] pwdata;
  logic                       pready;
  logic [APB_DATA_WIDTH-1:0] prdata;
  logic                       pslverr;
  logic                       irq;

  // Driver: maneja reset y el bus, lee las respuestas del DUT
  modport apb_drv (
    input  clk,
    output reset_n,
    output paddr, pwrite, psel, penable, pwdata,
    input  pready, prdata, pslverr, irq
  );

  // Monitor: solo observa todas las señales
  modport apb_mon (
    input clk,
    input reset_n,
    input paddr, pwrite, psel, penable, pwdata,
    input pready, prdata, pslverr, irq
  );

endinterface
