# Verificación de Alineador con UVM
 
Entorno de verificación funcional UVM para el módulo `cfs_aligner`.
Implementa dos agentes activos (APB y MD), un scoreboard con modelo de
referencia y una capa de abstracción de registros (RAL).

---
 
## Flujo de simulación
 
### Compilación y ejecución básica
 
```bash
make                # Compila y corre (sin cobertura)
make comp           # Solo compila
make run            # Solo corre (requiere comp previo)
make clean          # Borra archivos generados
```
 
Argumentos opcionales:
 
| Argumento        | Descripción                                      | 
|------------------|--------------------------------------------------|
| `SEED=<val>`     | Semilla aleatoria para `ntb_random_seed`         | 
| `PLUSARGS_FILE=` | Archivo en `tb/test/plusargs/` con plusargs      | 
 
Ejemplo:
 
```bash
make run SEED=42 PLUSARGS_FILE=rx_legal_comb_test.txt
```
 
### Cobertura
 
```bash
make coverage PLUSARGS_FILE=base_test.txt SEED=5  # Compila + corre con cobertura
make run_cov  SEED=13 PLUSARGS_FILE=fill_rx_fifo_test.txt  # Acumula sin recompilar
make verdi        # Abre Verdi con coverage.vdb
```
 
### Regresión con múltiples semillas
 
Corre el caso seleccionado con 20 semillas predefinidas, acumulando cobertura:
 
```bash
make multiple_seeds PLUSARGS_FILE=base_test.txt
```
 
### Casos de esquina
 
Itera sobre todos los archivos de plusargs disponibles, ejecutando cada
escenario con la semilla indicada:
 
```bash
make corner_cases          # SEED=1 por defecto
make corner_cases SEED=7
```
 
### Flujo completo de verificación
 
```bash
make coverage        PLUSARGS_FILE=base_test.txt SEED=1
make multiple_seeds  PLUSARGS_FILE=base_test.txt
make corner_cases
make verdi           
```
 
---



# Testplan Alineador

## Caso general

Los siguientes puntos son aleatorizables:

### Interfaz Rx
---
- Dato
- Size
- Offset
 
- Tiempo de valid

- Retardo entre paquetes
- Cantidad de paquetes

--- 

### Interfaz Tx

---
- Retardo y Tiempo de ready
---

### Interfaz APB a registros
---
- Dirección
- Tipo de acceso (Lectura o Escritura)
- Dato de escritura
---

## Casos esquina

- [x] Flujo de paquetes validos y combinación legal de de size y offset en registro de control.

- [x] Rx size mayor que control size

- [x] Rx size menor que control size

- [x] Cambio de datos de control en ejecución.

- [x] Paquete Rx con size y offset ilegal

- [x] Saturación de paquetes ilegales para llevar a CNT_DROP al máximo y generar el clear

- [x] Escritura invalida (offset y size ilegal) a registro de control

- [x] Escritura a registro de estado

- [x] FIFO de RX lleno

- [x] FIFO de Tx lleno

- [x] Generar w1c en IRQ de FIFO vacía

- [x] Deshabilitar todos los campos de habilitación de interrupciones



---
