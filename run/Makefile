
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


COV_DIR       = coverage.vdb
COV_COMP_OPTS = -cm line+cond+fsm+tgl+branch+assert
COV_RUN_OPTS  = -cm line+cond+fsm+tgl+branch+assert -cm_dir $(COV_DIR)



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


comp_cov: check
ifndef ERR_STATUS
	vcs $(COMP_OPTS) $(COV_COMP_OPTS)    \
	    -f $(DUT_DIR)/filelist.f         \
	    -f $(TB_DIR)/filelist.f
endif


coverage: comp_cov
ifndef ERR_STATUS
	./simv $(RUN_OPTS) $(COV_RUN_OPTS)
endif

# Solo corre sin recompilar; acumula en el mismo COV_DIR.
#   make run_cov SEED=2 PLUSARGS_FILE=fill_rx_fifo_test.txt
run_cov: check
ifndef ERR_STATUS
	./simv $(RUN_OPTS) $(COV_RUN_OPTS)
endif

# Abre Verdi con la base de datos de cobertura.
verdi:
	@[ -d "$(COV_DIR)" ] || \
	  { echo "ERROR: $(COV_DIR) no existe — corre 'make coverage' primero"; exit 1; }
	verdi -cov -covdir $(COV_DIR) &

# Genera reporte HTML + texto plano con URG (Unified Report Generator).
# Resultado en cov_report/dashboard.html
cov_report:
	@[ -d "$(COV_DIR)" ] || \
	  { echo "ERROR: $(COV_DIR) no existe — corre 'make coverage' primero"; exit 1; }
	urg -dir $(COV_DIR) -report cov_report -format both
	@echo "Reporte listo en: cov_report/dashboard.html"

# ──────────────────────────────────────────────────────────────────────────────

clean:
	rm -rf simv* csrc
	rm -rf vc_hdrs.h .vcsmx_rebuild *.log
	rm -rf work/* *.svshell vcs_version *.vcd
	rm -rf $(COV_DIR) cov_report

help:
	@echo "****************************************************************"
	@echo "***   Makefile Help for $(PROJECT_NAME)                      ***"
	@echo "****************************************************************"
	@echo "*  Simulación básica:                                          *"
	@echo "*    make                  Compila y corre (sin cobertura)     *"
	@echo "*    make comp             Solo compila                        *"
	@echo "*    make run              Solo corre (requiere comp previo)   *"
	@echo "*    make clean            Borra todos los archivos generados  *"
	@echo "*                                                              *"
	@echo "*  Cobertura:                                                  *"
	@echo "*    make coverage         Compila + corre con cobertura       *"
	@echo "*    make comp_cov         Solo compila con cobertura          *"
	@echo "*    make run_cov          Solo corre; acumula en coverage.vdb *"
	@echo "*    make verdi            Abre Verdi con coverage.vdb         *"
	@echo "*    make cov_report       Genera reporte HTML via URG         *"
	@echo "*                                                              *"
	@echo "*  Argumentos opcionales:                                      *"
	@echo "*    SEED=<val>            Semilla aleatoria (default=1)       *"
	@echo "*    PLUSARGS_FILE=<f>     Archivo en tb/test/plusargs/        *"
	@echo "*                         ej: PLUSARGS_FILE=base_test.txt      *"
	@echo "*                                                              *"
	@echo "*  Flujo típico para acumular cobertura de varios tests:       *"
	@echo "*    make coverage  PLUSARGS_FILE=base_test.txt   SEED=1       *"
	@echo "*    make run_cov   PLUSARGS_FILE=fill_rx_fifo_test.txt SEED=2 *"
	@echo "*    make run_cov   PLUSARGS_FILE=fill_tx_fifo_test.txt SEED=3 *"
	@echo "*    make verdi                                                *"
	@echo "****************************************************************"
