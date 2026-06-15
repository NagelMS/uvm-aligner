#!/bin/bash
# ============================================================
# run_coverage.sh
# Compila con cobertura una vez y corre todos los plusargs
# con multiples seeds, acumulando en coverage.vdb.
#
# ============================================================

SEEDS=3
CLEAN=0
PLUSARGS_DIR=../tb/test/plusargs
LOG_DIR=logs_cov
PASS=0
FAIL=0

for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        SEEDS=$arg
    elif [ "$arg" = "--clean" ]; then
        CLEAN=1
    fi
done

GRN='\033[0;32m'
RED='\033[0;31m'
YLW='\033[1;33m'
NC='\033[0m'

TESTS=($(ls "$PLUSARGS_DIR"/*.txt 2>/dev/null))
N_TESTS=${#TESTS[@]}
TOTAL=$((N_TESTS * SEEDS))

echo ""
echo "========================================================="
echo "  Coverage sweep"
echo "  Tests      : $N_TESTS"
echo "  Seeds/test : $SEEDS"
echo "  Total runs : $TOTAL"
echo "========================================================="

if [ $N_TESTS -eq 0 ]; then
    echo -e "${RED}ERROR: No se encontraron archivos .txt en $PLUSARGS_DIR${NC}"
    exit 1
fi

# Limpiar si se pidio
if [ $CLEAN -eq 1 ]; then
    echo -e "${YLW}[CLEAN] Borrando coverage.vdb, logs y binarios...${NC}"
    make clean
fi

mkdir -p "$LOG_DIR"

# Compilar una sola vez con flags de cobertura
echo ""
echo -e "${YLW}[COMP] Compilando con cobertura...${NC}"
if ! make comp_cov 2>&1 | tee "$LOG_DIR/compile.log"; then
    echo -e "${RED}[COMP] Compilacion fallida. Abortando.${NC}"
    exit 1
fi
echo -e "${GRN}[COMP] OK${NC}"
echo ""

RUN=0
T_START=$SECONDS

for f in "${TESTS[@]}"; do
    TEST=$(basename "$f" .txt)
    for SEED in $(seq 1 "$SEEDS"); do
        RUN=$((RUN + 1))
        printf "  [%3d/%3d] %-45s seed=%-5d" $RUN $TOTAL "$TEST" $SEED

        make run_cov PLUSARGS_FILE="$(basename "$f")" SEED="$SEED" CM_NAME="${TEST}_seed${SEED}" >/dev/null 2>&1
        RC=$?

        # Guardar log individual de la simulacion
        LOG="$LOG_DIR/${TEST}_seed${SEED}.log"
        [ -f simv.log ] && cp simv.log "$LOG"

        # Leer conteos del resumen final de UVM (lineas "UVM_ERROR :    N")
        UVM_ERRS=$(grep -oE "UVM_ERROR\s*:\s*[0-9]+" "$LOG" 2>/dev/null \
                   | grep -oE "[0-9]+" | head -1)
        UVM_FATS=$(grep -oE "UVM_FATAL\s*:\s*[0-9]+" "$LOG" 2>/dev/null \
                   | grep -oE "[0-9]+" | head -1)

        if [ $RC -ne 0 ]; then
            echo -e "  ${RED}FAIL (make error)${NC}"
            FAIL=$((FAIL + 1))
        elif [ "${UVM_ERRS:-0}" -gt 0 ] || [ "${UVM_FATS:-0}" -gt 0 ]; then
            echo -e "  ${RED}FAIL (UVM errors=${UVM_ERRS:-0} fatals=${UVM_FATS:-0})${NC}"
            FAIL=$((FAIL + 1))
        else
            echo -e "  ${GRN}PASS${NC}"
            PASS=$((PASS + 1))
        fi
    done
done

ELAPSED=$((SECONDS - T_START))

echo ""
echo "========================================================="
printf "  PASS  : ${GRN}%d${NC}\n" $PASS
printf "  FAIL  : ${RED}%d${NC}\n" $FAIL
printf "  Tiempo: %dm %ds\n" $((ELAPSED / 60)) $((ELAPSED % 60))
echo "  Logs  : run/$LOG_DIR/"
echo "========================================================="

# Reporte HTML con urg
if [ -d "coverage.vdb" ]; then
    echo ""
    echo -e "${YLW}[REPORT] Generando reporte HTML con urg...${NC}"
    if make cov_report 2>/dev/null; then
        echo -e "${GRN}Reporte listo en: run/cov_report/dashboard.html${NC}"
    else
        echo -e "${YLW}[REPORT] urg no disponible, omitiendo reporte.${NC}"
    fi
fi

echo ""
[ $FAIL -gt 0 ] && exit 1
exit 0
