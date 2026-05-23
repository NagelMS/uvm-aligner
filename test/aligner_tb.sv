///////////////////////////////////////////////////////////////////////////////
// File:        aligner_tb.sv
// Description: Dummy testbench for cfs_aligner.

///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module aligner_tb;

  localparam ALGN_DATA_WIDTH   = 32;
  localparam FIFO_DEPTH        = 8;
  localparam APB_ADDR_WIDTH    = 16;
  localparam APB_DATA_WIDTH    = 32;
  localparam ALGN_OFFSET_WIDTH = 2;   
  localparam ALGN_SIZE_WIDTH   = 3;   

  reg clk;
  reg reset_n;

  reg  [APB_ADDR_WIDTH-1:0]   paddr;
  reg                          pwrite;
  reg                          psel;
  reg                          penable;
  reg  [APB_DATA_WIDTH-1:0]   pwdata;
  wire                         pready;
  wire [APB_DATA_WIDTH-1:0]   prdata;
  wire                         pslverr;

  reg                           md_rx_valid;
  reg  [ALGN_DATA_WIDTH-1:0]   md_rx_data;
  reg  [ALGN_OFFSET_WIDTH-1:0] md_rx_offset;
  reg  [ALGN_SIZE_WIDTH-1:0]   md_rx_size;
  wire                          md_rx_ready;
  wire                          md_rx_err;

  wire                          md_tx_valid;
  wire [ALGN_DATA_WIDTH-1:0]   md_tx_data;
  wire [ALGN_OFFSET_WIDTH-1:0] md_tx_offset;
  wire [ALGN_SIZE_WIDTH-1:0]   md_tx_size;
  reg                           md_tx_ready;
  reg                           md_tx_err;

  wire irq;

  cfs_aligner #(
    .ALGN_DATA_WIDTH(ALGN_DATA_WIDTH),
    .FIFO_DEPTH     (FIFO_DEPTH)
  ) dut (
    .clk         (clk),
    .reset_n     (reset_n),
    .paddr       (paddr),
    .pwrite      (pwrite),
    .psel        (psel),
    .penable     (penable),
    .pwdata      (pwdata),
    .pready      (pready),
    .prdata      (prdata),
    .pslverr     (pslverr),
    .md_rx_valid (md_rx_valid),
    .md_rx_data  (md_rx_data),
    .md_rx_offset(md_rx_offset),
    .md_rx_size  (md_rx_size),
    .md_rx_ready (md_rx_ready),
    .md_rx_err   (md_rx_err),
    .md_tx_valid (md_tx_valid),
    .md_tx_data  (md_tx_data),
    .md_tx_offset(md_tx_offset),
    .md_tx_size  (md_tx_size),
    .md_tx_ready (md_tx_ready),
    .md_tx_err   (md_tx_err),
    .irq         (irq)
  );


  initial clk = 1'b0;
  always  #5 clk = ~clk;

  task automatic apb_write(
    input [APB_ADDR_WIDTH-1:0] addr,
    input [APB_DATA_WIDTH-1:0] data
  );
    @(posedge clk);
    paddr   <= addr;
    pwrite  <= 1'b1;
    psel    <= 1'b1;
    penable <= 1'b0;
    pwdata  <= data;
    @(posedge clk);
    penable <= 1'b1;
    @(posedge clk);
    while (!pready) @(posedge clk);
    $display("[APB WR] addr=0x%04h  data=0x%08h  slverr=%0b", addr, data, pslverr);
    psel    <= 1'b0;
    penable <= 1'b0;
    pwrite  <= 1'b0;
  endtask

  task automatic apb_read(
    input  [APB_ADDR_WIDTH-1:0] addr,
    output [APB_DATA_WIDTH-1:0] rdata
  );
    @(posedge clk);
    paddr   <= addr;
    pwrite  <= 1'b0;
    psel    <= 1'b1;
    penable <= 1'b0;
    @(posedge clk);
    penable <= 1'b1;
    @(posedge clk);
    while (!pready) @(posedge clk);
    rdata = prdata;
    $display("[APB RD] addr=0x%04h  data=0x%08h", addr, rdata);
    psel    <= 1'b0;
    penable <= 1'b0;
  endtask

  int errors = 0;


  initial begin

    paddr        = '0;
    pwrite       = 1'b0;
    psel         = 1'b0;
    penable      = 1'b0;
    pwdata       = '0;
    md_rx_valid  = 1'b0;
    md_rx_data   = '0;
    md_rx_offset = '0;
    md_rx_size   = '0;
    md_tx_ready  = 1'b1;   
    md_tx_err    = 1'b0;
    reset_n      = 1'b0;

    $display("\n[TB] Applying reset...");
    repeat(5) @(posedge clk);
    reset_n = 1'b1;
    repeat(3) @(posedge clk);
    $display("[TB] Reset released.");


    $display("\n=== Test 1: CTRL default value (SIZE=1, OFFSET=0) ===");
    begin
      automatic logic [APB_DATA_WIDTH-1:0] rd;
      apb_read(16'h0000, rd);

      if (rd === 32'h0000_0001)
        $display("PASS: CTRL = 0x%08h", rd);
      else begin
        $display("FAIL: Expected CTRL=0x00000001, got 0x%08h", rd);
        errors++;
      end
    end


    $display("\n=== Test 2: Write CTRL SIZE=4, OFFSET=0 ===");
    apb_write(16'h0000, 32'h0000_0004);
    begin
      automatic logic [APB_DATA_WIDTH-1:0] rd;
      apb_read(16'h0000, rd);
      if (rd === 32'h0000_0004)
        $display("PASS: CTRL = 0x%08h", rd);
      else begin
        $display("FAIL: Expected CTRL=0x00000004, got 0x%08h", rd);
        errors++;
      end
    end


    $display("\n=== Test 3: RX packet flow through aligner");
    fork
      begin
        @(posedge clk);
        md_rx_valid  <= 1'b1;
        md_rx_data   <= 32'hDEAD_BEEF;
        md_rx_offset <= 2'd0;
        md_rx_size   <= 3'd4;

        do @(posedge clk); while (!md_rx_ready);
        $display("[RX] Handshake done: data=0x%08h size=%0d offset=%0d err=%0b",
                 md_rx_data, md_rx_size, md_rx_offset, md_rx_err);
        @(posedge clk);
        md_rx_valid <= 1'b0;
      end

      begin
        @(posedge md_tx_valid);
        $display("[TX] Received:  data=0x%08h size=%0d offset=%0d",
                 md_tx_data, md_tx_size, md_tx_offset);
        if (md_tx_data   === 32'hDEAD_BEEF &&
            md_tx_size   === 3'd4           &&
            md_tx_offset === 2'd0)
          $display("PASS: TX data matches expected values");
        else begin
          $display("FAIL: TX mismatch. Expected data=0xDEADBEEF size=4 offset=0");
          errors++;
        end
      end
    join

    repeat(5) @(posedge clk);


    $display("\n==========================================");
    if (errors == 0)
      $display("  ALL TESTS PASSED  (%0d errors)", errors);
    else
      $display("  SIMULATION FAILED (%0d error(s))", errors);
    $display("==========================================\n");

    $finish;
  end


  initial begin
    #100_000;
    $display("[TB] TIMEOUT: Simulation exceeded time limit");
    $finish;
  end

  initial begin
    $dumpfile("aligner_tb.vcd");
    $dumpvars(0, aligner_tb);
  end

endmodule
