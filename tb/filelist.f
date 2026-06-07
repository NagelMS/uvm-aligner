// Register model (RAL) - package, debe compilarse primero
../tb/ral/aligner_ral_pkg.sv

// Interfaces
../tb/if/apb_if.sv
../tb/if/md_if.sv

// Environment - APB agent
../tb/env/apb_seq_item.sv
../tb/env/apb_sequencer.sv
../tb/env/apb_driver.sv
../tb/env/apb_monitor.sv
../tb/env/apb_agent.sv

// RAL adapter (depende de apb_seq_item)
../tb/ral/apb_ral_adapter.sv

// Environment - MD agent
../tb/env/md_seq_item.sv
../tb/env/md_sequencer.sv
../tb/env/md_rx_driver.sv
../tb/env/md_tx_driver.sv
../tb/env/md_monitor.sv
../tb/env/md_agent.sv

// Scoreboard (depende de apb_seq_item, md_seq_item y ALIGNER)
../tb/env/scoreboard.sv

// Environment top (depende de agente + adaptador + ALIGNER + scoreboard)
../tb/env/aligner_env.sv

// Tests
../tb/test/apb_basic_test.sv

// Top testbench
../tb/top/aligner_tb.sv
