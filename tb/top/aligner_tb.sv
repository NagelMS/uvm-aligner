///////////////////////////////////////////////////////////////////////////////
// File:        aligner_tb.sv
// Description: Dummy testbench for cfs_aligner.
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module aligner_tb;

  localparam ALGN_DATA_WIDTH = 32;
  localparam FIFO_DEPTH      = 8;

  logic clk;

  // ── Interfaces ────────────────────────────────────────────────────────────
  apb_if apb (.clk(clk));
  md_if  rx  (.clk(clk));
  md_if  tx  (.clk(clk));

  // apb_if es quien controla reset_n; rx y tx lo observan
  assign rx.reset_n = apb.reset_n;
  assign tx.reset_n = apb.reset_n;

  // ── DUT ───────────────────────────────────────────────────────────────────
  cfs_aligner #(
    .ALGN_DATA_WIDTH(ALGN_DATA_WIDTH),
    .FIFO_DEPTH     (FIFO_DEPTH)
  ) dut (
    .clk         (clk),
    .reset_n     (apb.reset_n),
    .paddr       (apb.paddr),
    .pwrite      (apb.pwrite),
    .psel        (apb.psel),
    .penable     (apb.penable),
    .pwdata      (apb.pwdata),
    .pready      (apb.pready),
    .prdata      (apb.prdata),
    .pslverr     (apb.pslverr),
    .md_rx_valid (rx.valid),
    .md_rx_data  (rx.data),
    .md_rx_offset(rx.offset),
    .md_rx_size  (rx.size),
    .md_rx_ready (rx.ready),
    .md_rx_err   (rx.err),
    .md_tx_valid (tx.valid),
    .md_tx_data  (tx.data),
    .md_tx_offset(tx.offset),
    .md_tx_size  (tx.size),
    .md_tx_ready (tx.ready),
    .md_tx_err   (tx.err),
    .irq         (apb.irq)
  );

  // ── Clock: 100 MHz ────────────────────────────────────────────────────────
  initial clk = 1'b0;
  always  #5 clk = ~clk;

  // ── APB write task ────────────────────────────────────────────────────────
  task automatic apb_write(
    input logic [15:0] addr,
    input logic [31:0] data
  );
    @(posedge clk);
    apb.paddr   <= addr;
    apb.pwrite  <= 1'b1;
    apb.psel    <= 1'b1;
    apb.penable <= 1'b0;
    apb.pwdata  <= data;
    @(posedge clk);
    apb.penable <= 1'b1;
    @(posedge clk);
    while (!apb.pready) @(posedge clk);
    $display("[APB WR] addr=0x%04h  data=0x%08h  slverr=%0b", addr, data, apb.pslverr);
    apb.psel    <= 1'b0;
    apb.penable <= 1'b0;
    apb.pwrite  <= 1'b0;
  endtask

  // ── APB read task ─────────────────────────────────────────────────────────
  task automatic apb_read(
    input  logic [15:0] addr,
    output logic [31:0] rdata
  );
    @(posedge clk);
    apb.paddr   <= addr;
    apb.pwrite  <= 1'b0;
    apb.psel    <= 1'b1;
    apb.penable <= 1'b0;
    @(posedge clk);
    apb.penable <= 1'b1;
    @(posedge clk);
    while (!apb.pready) @(posedge clk);
    rdata = apb.prdata;
    $display("[APB RD] addr=0x%04h  data=0x%08h", addr, rdata);
    apb.psel    <= 1'b0;
    apb.penable <= 1'b0;
  endtask

  // ── Error counter ─────────────────────────────────────────────────────────
  int errors = 0;

  // ── Main test sequence ────────────────────────────────────────────────────
  initial begin
    apb.paddr   = '0;
    apb.pwrite  = 1'b0;
    apb.psel    = 1'b0;
    apb.penable = 1'b0;
    apb.pwdata  = '0;
    rx.valid    = 1'b0;
    rx.data     = '0;
    rx.offset   = '0;
    rx.size     = '0;
    tx.ready        = 1'b1;
    tx.err          = 1'b0;
    apb.reset_n     = 1'b0;

    $display("\n[TB] Applying reset...");
    repeat(5) @(posedge clk);
    apb.reset_n = 1'b1;
    repeat(3) @(posedge clk);
    $display("[TB] Reset released.");

    // ── Test 1: CTRL default ─────────────────────────────────────────────
    $display("\n=== Test 1: CTRL default value (SIZE=1, OFFSET=0) ===");
    begin
      automatic logic [31:0] rd;
      apb_read(16'h0000, rd);
      if (rd === 32'h0000_0001)
        $display("PASS: CTRL = 0x%08h", rd);
      else begin
        $display("FAIL: Expected CTRL=0x00000001, got 0x%08h", rd);
        errors++;
      end
    end

    // ── Test 2: Configurar CTRL SIZE=4, OFFSET=0 ─────────────────────────
    $display("\n=== Test 2: Write CTRL SIZE=4, OFFSET=0 ===");
    apb_write(16'h0000, 32'h0000_0004);
    begin
      automatic logic [31:0] rd;
      apb_read(16'h0000, rd);
      if (rd === 32'h0000_0004)
        $display("PASS: CTRL = 0x%08h", rd);
      else begin
        $display("FAIL: Expected CTRL=0x00000004, got 0x%08h", rd);
        errors++;
      end
    end

    // ── Test 3: Flujo RX → Aligner → TX ──────────────────────────────────
    $display("\n=== Test 3: RX packet flow through aligner ===");
    fork
      begin
        @(posedge clk);
        rx.valid  <= 1'b1;
        rx.data   <= 32'hDEAD_BEEF;
        rx.offset <= '0;
        rx.size   <= 3'd4;
        do @(posedge clk); while (!rx.ready);
        $display("[RX] Handshake done: data=0x%08h size=%0d offset=%0d err=%0b",
                 rx.data, rx.size, rx.offset, rx.err);
        @(posedge clk);
        rx.valid <= 1'b0;
      end
      begin
        @(posedge tx.valid);
        $display("[TX] Received: data=0x%08h size=%0d offset=%0d",
                 tx.data, tx.size, tx.offset);
        if (tx.data   === 32'hDEAD_BEEF &&
            tx.size   === 3'd4           &&
            tx.offset === '0)
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

  // ── Timeout watchdog ──────────────────────────────────────────────────────
  initial begin
    #100_000;
    $display("[TB] TIMEOUT: Simulation exceeded time limit");
    $finish;
  end

  // ── VCD dump ──────────────────────────────────────────────────────────────
  initial begin
    $dumpfile("aligner_tb.vcd");
    $dumpvars(0, aligner_tb);
  end

endmodule
