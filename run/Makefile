
PROJECT_NAME = uvm-aligner


DUT_DIR = ../dut
TB_DIR  = ../tb



SEED         = 1
PLUSARGS_FILE =

ifndef VCS_HOME
  ERR_STATUS = 1
endif

COMP_OPTS = -sverilog -l vcs.log   \
            +incdir+$(DUT_DIR)    \
            -timescale=1ns/1ps    \
            -ntb_opts uvm-1.2     \
            -debug_all

# Cargar plusargs desde archivo si PLUSARGS_FILE está definido
ifneq ($(PLUSARGS_FILE),)
  _PA_PATH      = $(TB_DIR)/test/plusargs/$(PLUSARGS_FILE)
  _FILE_PLUSARGS = $(shell grep -E '^\+' $(_PA_PATH) 2>/dev/null | tr '\n' ' ')
else
  _FILE_PLUSARGS =
endif

RUN_OPTS = +ntb_random_seed=$(SEED) -l simv.log $(_FILE_PLUSARGS)



all default: check comp run

check:
ifdef ERR_STATUS
	@echo ""
	@echo "ERROR : VCS_HOME is not set"
	@echo "Please set VCS_HOME to run this Makefile"
	@echo ""
endif

comp: check
ifndef ERR_STATUS
	vcs $(COMP_OPTS)             \
	    -f $(DUT_DIR)/filelist.f \
	    -f $(TB_DIR)/filelist.f
endif

run: check
ifndef ERR_STATUS
	./simv $(RUN_OPTS)
endif

clean:
	rm -rf simv* csrc
	rm -rf vc_hdrs.h .vcsmx_rebuild *.log
	rm -rf work/* *.svshell vcs_version *.vcd

help:
	@echo "************************************************************"
	@echo "***   Makefile Help for $(PROJECT_NAME)                  ***"
	@echo "************************************************************"
	@echo "*  Usage:                                                  *"
	@echo "*  ------                                                  *"
	@echo "*  make           Compile and run the testbench           *"
	@echo "*  make help      Show this help                          *"
	@echo "*  make clean     Remove all generated files              *"
	@echo "*  make comp      Compile only                            *"
	@echo "*  make run       Run simulation only                     *"
	@echo "*                                                          *"
	@echo "*  Optional arguments:                                    *"
	@echo "*  SEED=<val>           Random seed (default=1)           *"
	@echo "*  PLUSARGS_FILE=<f>    File in tb/test/plusargs/ to load *"
	@echo "*                       e.g. PLUSARGS_FILE=base_test.txt  *"
	@echo "************************************************************"
