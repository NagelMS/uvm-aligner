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

- [ ] Lectura activa de estado.

- [x] Paquete Rx con size y offset ilegal

- [x] Saturación de paquetes ilegales para llevar a CNT_DROP al máximo y generar el clear

- [x] Escritura invalida (offset y size ilegal) a registro de control

- [x] Escritura a registro de estado

- [x] FIFO de RX lleno

- [x] FIFO de Tx lleno

- [ ] Generar w1c en IRQ de FIFO vacía

- [ ] Deshabilitar todos los campos de habilitación de interrupciones



---
