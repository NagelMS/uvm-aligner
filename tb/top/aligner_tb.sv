`timescale 1ns/1ps

module aligner_tb;

  localparam ALGN_DATA_WIDTH = 32;
  localparam FIFO_DEPTH      = 8;

  logic clk;

  apb_if apb (.clk(clk));
  md_if  rx  (.clk(clk));
  md_if  tx  (.clk(clk));

  assign rx.reset_n = apb.reset_n;
  assign tx.reset_n = apb.reset_n;

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

  initial clk = 1'b0;
  always  #5 clk = ~clk;

  // Reset: 5 ciclos en bajo; los agentes MD toman control de rx/tx desde sus drivers
  initial begin
    apb.reset_n = 1'b0;
    repeat(5) @(posedge clk);
    apb.reset_n = 1'b1;
    `uvm_info("TB", "Reset released.", UVM_LOW)
  end

  initial begin
    uvm_config_db #(virtual apb_if)::set(null, "uvm_test_top.*", "apb_vif", apb);
    uvm_config_db #(virtual md_if #(ALGN_DATA_WIDTH))::set(null, "uvm_test_top.*", "md_rx_vif", rx);
    uvm_config_db #(virtual md_if #(ALGN_DATA_WIDTH))::set(null, "uvm_test_top.*", "md_tx_vif", tx);
    run_test("apb_basic_test");
  end

  initial begin
    #100_000;
    `uvm_fatal("TB", "TIMEOUT: Simulation exceeded time limit")
  end

  initial begin
    $dumpfile("aligner_tb.vcd");
    $dumpvars(0, aligner_tb);
  end

endmodule
