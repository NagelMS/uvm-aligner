`include "uvm_macros.svh"
import uvm_pkg::*;
import aligner_ral_pkg::*;

class apb_seq_item extends uvm_sequence_item;

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr,   UVM_ALL_ON)
    `uvm_field_int(data,   UVM_ALL_ON)
    `uvm_field_int(write,  UVM_ALL_ON)
    `uvm_field_int(slverr, UVM_ALL_ON)
  `uvm_object_utils_end

  rand logic [15:0] addr;
  rand logic [31:0] data;
  rand logic        write;
       logic        slverr; 

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("[APB] %s addr=0x%04h data=0x%08h slverr=%0b",
                     write ? "WR" : "RD", addr, data, slverr);
  endfunction

endclass

