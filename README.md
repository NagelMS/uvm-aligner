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

- Flujo de paquetes validos y combinación legal de de size y offset en registro de control.
- Rx size mayor que control size
- Rx size menor que control size
- Cambio de datos de control en ejecución.
- Lectura activa de estado.
- Paquete Rx con size y offset ilegal
- Saturación de paquetes ilegales para llevar a CNT_DROP al máximo y generar el clear
- Escritura invalida (offset y size ilegal) a registro de control
- Escritura a registro de estado
- FIFO de RX lleno
- FIFO de Tx lleno
- Generar w1c en IRQ de FIFO vacía
- Deshabilitar todos los campos de habilitación de interrupciones



---
