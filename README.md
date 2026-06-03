# Proyecto Ahorcado - Ensamblador 8086

## 1. Introduccion

Juego del Ahorcado en ensamblador 8086 para EMU8086, con dos modalidades:

- **Maquina vs Jugador**: el programa selecciona una palabra aleatoria desde archivos `.txt` clasificados por dificultad (facil, medio, dificil).
- **Jugador vs Jugador**: un jugador ingresa una palabra secreta con caracteres ocultos (`*`) y el otro intenta adivinarla en maximo 6 intentos. Los roles se intercambian y se comparan puntajes.

El codigo esta dividido en tres bloques:

| Bloque | Funcion |
|---|---|
| Interfaz + Entrada de usuario | Pantallas, nicknames, menus, tablero de juego, estadisticas finales |
| Logica del juego | Comparar letras, validar repetidas, detectar victoria/derrota, puntuacion, turnos |
| Archivos + Aleatoriedad + PvP | Leer palabras de archivos `.txt`, seleccion aleatoria, entrada oculta con `*` |

---

## 2. Archivos del proyecto

| Archivo | Descripcion |
|---|---|
| `ahorcado_integrado.asm` | Codigo fuente completo integrado. Abrir en EMU8086, ensamblar (F7), ejecutar (F5). |
| `persona1_interfaz.asm` | Modulo de interfaz standalone (Persona 1). Compila y prueba de forma independiente. |
| `facil.txt` | 20 palabras de 4-5 letras, una por linea |
| `medio.txt` | 15 palabras de 6-8 letras, una por linea |
| `dificil.txt` | 12 palabras de 9+ letras, una por linea |

Los `.txt` deben estar en `C:\emu8086\MyBuild\`. Si un archivo no se encuentra, el programa usa `'PRUEBA'` como respaldo.

> **Nota sobre caracteres:** Los marcos del tablero usan solo caracteres ASCII estandar (`+`, `-`, `|`) para garantizar compatibilidad total con EMU8086 sin depender de codepage ni bytes hexadecimales especiales.

---

## 3. Variables globales

### Datos del juego
```
PALABRA       DB 20 DUP(0)      ; Palabra secreta actual
LONG_PALABRA  DB 0              ; Cantidad de letras
ESTADO        DB 20 DUP('_')    ; Lo que ve el jugador (_ _ _ _)
ERRORES       DB 0              ; Errores acumulados (0-6)
LETRA_ACTUAL  DB 0              ; Ultima letra ingresada
USADAS        DB 26 DUP(0)      ; Letras ya usadas (A=0, B=1, ..., Z=25)
TURNO         DB 1              ; 1=Jugador 1, 2=Jugador 2
MODALIDAD     DB 1              ; 1=Maquina vs J, 2=PvP
```

### Puntajes
```
TABLA_PUNTAJES DB 100, 100, 85, 70, 50, 30, 10   ; Indexada por ERRORES
PUNTAJE_ACTUAL DB 0                                ; Puntaje del turno
PUNTAJE_J1     DW 0                                ; Acumulado Jugador 1
PUNTAJE_J2     DW 0                                ; Acumulado Jugador 2
MAX_ERRORES    EQU 6                               ; Maximo de intentos
```

### Archivos y aleatoriedad
```
DIFICULTAD    DB 1              ; 1=facil, 2=medio, 3=dificil
BUFFER_ARCH   DB 2000 DUP(0)    ; Buffer de lectura del archivo
BYTES_LEIDOS  DW 0              ; Bytes leidos
CONT_PALABRAS DB 0              ; Total de palabras en el buffer
INDICE_SEL    DB 0              ; Indice de palabra elegida al azar
FILE_HANDLE   DW 0              ; Handle del archivo abierto

ARCH_FACIL    DB 'facil.txt', 0
ARCH_MEDIO    DB 'medio.txt', 0
ARCH_DIFICIL  DB 'dificil.txt', 0
PAL_DEFAULT   DB 'PRUEBA'       ; Palabra de respaldo
LEN_DEFAULT   DB 6
```

### Interfaz y entrada (Persona 1)
```
NICK_J1         DB 11 DUP(0)   ; Nickname jugador 1 (max 10 caracteres + null)
NICK_J2         DB 11 DUP(0)   ; Nickname jugador 2 (max 10 caracteres + null)
LEN_NICK_J1     DB 0           ; Longitud del nickname J1
LEN_NICK_J2     DB 0           ; Longitud del nickname J2
ACCION_ESPECIAL DB 0           ; 0=ninguna  1=rendirse  2=reset  3=salir
```

---

## 4. Modulos de interfaz y entrada de usuario (Persona 1)

### PANTALLA_INICIAL
Punto de entrada al inicio de la partida. Muestra la pantalla de bienvenida y solicita en orden:
1. Nickname del Jugador 1 (llamando a `LEER_NICKNAME` + `VALIDAR_NICKNAME`).
2. Modo de juego (1 = Maquina vs Jugador, 2 = Jugador vs Jugador). Escribe `MODALIDAD`.
3. Si modo PvP: nickname del Jugador 2.
4. Si modo Maquina: dificultad (1/2/3). Escribe `DIFICULTAD`.

Cada campo se repite hasta recibir una entrada valida. No avanza si el input esta vacio o fuera de rango.

### MOSTRAR_JUEGO
Dibuja el tablero completo del turno activo limpiando la pantalla antes de cada refresco. Estructura:

```
+----------------------------------+
| Jugador: NOMBRE                  |
| Intentos restantes: N            |
| Puntaje: XXX                     |
+----------------------------------+
| Palabra: _ A _ _ A               |
+----------------------------------+
| Letras usadas: A E O T           |
+----------------------------------+
[1] Rendirse  [2] Reset  [3] Salir
```

Lee (no modifica): `TURNO`, `ERRORES`, `PUNTAJE_ACTUAL`, `ESTADO`, `LONG_PALABRA`, `USADAS`. Llama internamente a `IMPRIMIR_NICK_ACTIVO`, `IMPRIMIR_ESTADO_PALABRA` e `IMPRIMIR_LETRAS_USADAS`.

### LEER_INPUT_JUGADOR
Lee una sola tecla sin eco y la convierte a mayuscula. Detecta:
- **Letras A-Z**: retorna la letra en AL y deja `ACCION_ESPECIAL = 0`.
- **1**: llama a `CONFIRMAR_RENDIRSE`. Si confirma, `ACCION_ESPECIAL = 1`, AL = 0.
- **2**: llama a `CONFIRMAR_RESET`. Si confirma, `ACCION_ESPECIAL = 2`, AL = 0.
- **3**: llama a `CONFIRMAR_SALIR`. Si confirma, `ACCION_ESPECIAL = 3`, AL = 0.
- Cualquier otro caracter: muestra "Entrada invalida" y vuelve a leer.

El programa principal lee `ACCION_ESPECIAL` tras el retorno para decidir que hacer.

### MOSTRAR_ESTADISTICAS
Muestra el cuadro final con puntajes y ganador al terminar la partida:

```
+----------------------------------+
|        ESTADISTICAS              |
+----------------------------------+
| NOMBRE1 -> 120 pts               |
| NOMBRE2 ->  90 pts               |
+----------------------------------+
| Ganador: NOMBRE1                 |
+----------------------------------+
```

Compara `PUNTAJE_J1` vs `PUNTAJE_J2`. Muestra "EMPATE!" si son iguales. En modo Maquina vs Jugador solo muestra J1. Lee `MODALIDAD`, `NICK_J1`, `NICK_J2`, `PUNTAJE_J1`, `PUNTAJE_J2`.

### MOSTRAR_RENDICION
Se llama cuando el jugador activo elige [1] Rendirse y confirma. Muestra el mensaje de rendicion y revela la palabra completa leyendo `PALABRA` byte a byte segun `LONG_PALABRA`. Espera ENTER para continuar.

### CONFIRMAR_RENDIRSE / CONFIRMAR_RESET / CONFIRMAR_SALIR
Las tres funcionan igual: muestran un mensaje de confirmacion "Seguro? (S/N)" y leen una tecla. Retornan `CF=0` si el jugador presiono S (confirmo) o `CF=1` si presiono cualquier otra tecla (cancelo). El llamador salta de vuelta al loop de juego si CF=1.

### LEER_NICKNAME
Lee caracteres del teclado con eco visible y los almacena en el buffer apuntado por DX. Comportamiento:
- Acepta A-Z (convierte minusculas a mayusculas con `-20h`) y digitos 0-9.
- Backspace borra el ultimo caracter visualmente (secuencia BS + espacio + BS).
- ENTER termina la lectura.
- Maximo 10 caracteres; los extras se ignoran.
- Coloca un byte 0 al final (null terminator).
- Retorna en AL la longitud del nick leido.

### VALIDAR_NICKNAME
Verifica que AL este entre 3 y 10. Retorna `CF=0` si es valido, `CF=1` si no lo es. `PANTALLA_INICIAL` la llama despues de cada `LEER_NICKNAME` y repite la solicitud si CF=1.

### IMPRIMIR_NICK_ACTIVO
Lee `TURNO` y llama a `IMPRIMIR_NICK_RAW` con `NICK_J1` o `NICK_J2` segun corresponda.

### IMPRIMIR_NICK_RAW
Imprime la cadena apuntada por DX recorriendo byte a byte hasta encontrar el byte 0 (null terminator). No usa `INT 21h/AH=09h` porque los nicknames no tienen `'$'` al final.

### IMPRIMIR_ESTADO_PALABRA
Recorre `ESTADO` de 0 a `LONG_PALABRA - 1` e imprime cada caracter seguido de un espacio. Produce la visualizacion `_ A _ _ A` del tablero.

### IMPRIMIR_LETRAS_USADAS
Recorre el arreglo `USADAS` (26 bytes). Si `USADAS[i] = 1`, convierte el indice a letra con `'A' + i` y la imprime seguida de un espacio. Produce la lista `A E O T` del tablero.

### IMPRIMIR_PALABRA_COMPLETA
Imprime `PALABRA` letra a letra segun `LONG_PALABRA`. Se usa al revelar la palabra tras una derrota o rendicion.

---

## 5. Modulos de logica del juego (Persona 2)

### COMPARAR_LETRA
Busca `LETRA_ACTUAL` en `PALABRA`. Por cada coincidencia revela esa posicion en `ESTADO`. Si no encuentra ninguna, incrementa `ERRORES`. Retorna cantidad de aciertos en AL.

Ejemplo: `PALABRA = "CASA"`, `ESTADO = "____"`, letra = `'A'` → resultado: `ESTADO = "_A_A"`, AL = 2.

### VALIDAR_REPETIDA
Verifica en `USADAS` si la letra ya fue ingresada. Si es nueva, la marca. Si es repetida, retorna CF=1. Debe llamarse siempre ANTES de `COMPARAR_LETRA`. El indice se obtiene con `LETRA_ACTUAL - 'A'` (A=0, B=1, ..., Z=25).

### DETECTAR_VICTORIA
Recorre `ESTADO` buscando `'_'`. Si no encuentra ninguno, el jugador gano (CF=1). Debe llamarse ANTES que `DETECTAR_DERROTA` para que adivinar en el ultimo intento cuente como victoria.

### DETECTAR_DERROTA
Compara `ERRORES >= MAX_ERRORES` (6). Si se alcanzo el maximo, CF=1.

### CALCULAR_PUNTAJE
Busca en `TABLA_PUNTAJES` usando `ERRORES` como indice y actualiza `PUNTAJE_ACTUAL`. Se llama en cada iteracion para mostrar el puntaje potencial en tiempo real.

### PUNTAJE_DERROTA y ACUMULAR_PUNTAJE
`PUNTAJE_DERROTA` pone `PUNTAJE_ACTUAL = 0` (cuando se pierde o rinde). `ACUMULAR_PUNTAJE` suma `PUNTAJE_ACTUAL` a `PUNTAJE_J1` o `PUNTAJE_J2` segun `TURNO`. Llamar una sola vez por ronda.

### CAMBIO_TURNO
Alterna `TURNO` entre 1 y 2. Resetea `ERRORES=0`, `PUNTAJE_ACTUAL=0` y limpia `USADAS`. Solo se usa en modo PvP.

### IMPRIMIR_TURNO
Muestra "Turno del Jugador 1" o "Turno del Jugador 2" segun `TURNO`.

### Auxiliares
`REINICIAR_ESTADO`: llena `ESTADO` con `'_'` segun `LONG_PALABRA`. Usa `REP STOSB`.

`REINICIAR_USADAS`: pone 26 ceros en `USADAS`. Usa `REP STOSB`.

`IMPRIMIR_NUMERO`: convierte AX a decimal dividiendo entre 10 y apilando digitos (DOS no imprime numeros nativamente).

`MOSTRAR_ESTADO_PRUEBA`: muestra `ESTADO`, `ERRORES` y `PUNTAJE_ACTUAL` en pantalla.

---

## 6. Modulos de archivos y PvP (Persona 3)

### CARGAR_PALABRA (punto de entrada)
Segun `MODALIDAD`:
- **Maquina (1)**: delega en `CARGAR_PALABRA_ARCHIVO`
- **PvP (2)**: delega en `LEER_PALABRA_OCULTA`

Si no se carga ninguna palabra (archivo no encontrado, usuario presiono Enter sin escribir), carga `'PRUEBA'` como respaldo para evitar que `LONG_PALABRA = 0`, lo cual causaria loops infinitos. Al finalizar resetea `ESTADO`, `ERRORES` y `USADAS`.

### CARGAR_PALABRA_ARCHIVO
Flujo: `ABRIR_ARCHIVO` → `CONTAR_PALABRAS` → `GENERAR_ALEATORIO` → `EXTRAER_PALABRA`. Si algo falla, muestra error y carga `'PRUEBA'`.

### ABRIR_ARCHIVO
Segun `DIFICULTAD` (1, 2, 3) selecciona `facil.txt`, `medio.txt` o `dificil.txt`. Usa tres interrupciones DOS: `AH=3Dh` (abrir), `AH=3Fh` (leer hasta 2000 bytes a `BUFFER_ARCH`), `AH=3Eh` (cerrar). Retorna CF=1 si el archivo no existe o hay error de lectura.

### CONTAR_PALABRAS
Recorre `BUFFER_ARCH` byte a byte. Las palabras estan separadas por `CR` (0Dh) y `LF` (0Ah). Cada grupo de caracteres que no es CR ni LF cuenta como una palabra. Resultado en `CONT_PALABRAS`.

### EXTRAER_PALABRA
Similar a `CONTAR_PALABRAS` pero cuando llega al indice `INDICE_SEL` copia esa palabra a `PALABRA` y guarda su longitud en `LONG_PALABRA`. Maximo 20 caracteres.

### GENERAR_ALEATORIO
Usa `INT 21h/AH=2Ch` para obtener centesimas de segundo (0-99). Calcula `INDICE_SEL = centesimas % CONT_PALABRAS` usando `DIV`. Protegido contra division por cero.

### LEER_PALABRA_OCULTA
Entrada de palabra secreta para modo PvP:
- Segun `TURNO`, pide la palabra al jugador que NO esta adivinando
- Lee con `INT 21h/AH=08h` (sin eco), muestra `*` con `INT 21h/AH=02h`
- Soporta Backspace con secuencia `BS + espacio + BS`
- Convierte minusculas a mayusculas (`-20h`)
- Filtra: solo acepta A-Z, maximo 20 letras
- Al terminar muestra "PASE EL TECLADO AL OTRO JUGADOR", espera ENTER y limpia pantalla

---

## 7. Flujo del programa

```
INICIO
  ├─ PANTALLA_INICIAL
  │   ├─ Pedir nickname Jugador 1 (LEER_NICKNAME + VALIDAR_NICKNAME)
  │   ├─ Seleccionar modo (1=Maquina, 2=PvP)
  │   ├─ Si PvP: pedir nickname Jugador 2
  │   └─ Si Maquina: seleccionar dificultad
  ├─ Inicializar TURNO=1, puntajes en 0
  │
  ▼
RONDA ←──────────────────────────────────────────────┐
  ├─ IMPRIMIR_TURNO                                   │
  ├─ CARGAR_PALABRA                                   │
  │   ├─ Maquina: leer .txt → aleatoria               │
  │   └─ PvP: entrada oculta con *                    │
  │   └─ Resetea ESTADO, ERRORES, USADAS              │
  ▼                                                   │
LOOP_TURNO ←──────────────────────────────────────┐   │
  ├─ CALCULAR_PUNTAJE                              │   │
  ├─ MOSTRAR_JUEGO (tablero completo)              │   │
  ├─ LEER_INPUT_JUGADOR                            │   │
  │   ├─ Letra A-Z → continuar                    │   │
  │   ├─ [1] Rendirse → MOSTRAR_RENDICION         │   │
  │   ├─ [2] Reset → reiniciar ronda ─────────────┘   │
  │   └─ [3] Salir → terminar programa                │
  ├─ VALIDAR_REPETIDA → repetida? volver              │
  ├─ COMPARAR_LETRA                                   │
  ├─ DETECTAR_VICTORIA → gano?                        │
  ├─ DETECTAR_DERROTA → perdio?                       │
  └─ Volver ───────────────────────────────────────────┘
  │
  ▼
FIN_RONDA
  ├─ ACUMULAR_PUNTAJE
  ├─ TURNO=2 → FIN_PARTIDA
  └─ TURNO=1 → CAMBIO_TURNO → volver a RONDA
  │
  ▼
FIN_PARTIDA
  └─ MOSTRAR_ESTADISTICAS (cuadro con puntajes y ganador)
```

---

## 8. Interrupciones utilizadas

| Interrupcion | Proposito | Donde se usa |
|---|---|---|
| `INT 10h, AH=00h, AL=03h` | Modo texto 80x25 (limpia pantalla) | `LIMPIAR_PANTALLA`, `MOSTRAR_JUEGO` |
| `INT 21h, AH=01h` | Leer tecla con eco | `LEER_NICKNAME` |
| `INT 21h, AH=02h` | Imprimir caracter en DL | `IMPRIMIR_CARACTER`, `LEER_PALABRA_OCULTA`, borrado de Backspace |
| `INT 21h, AH=08h` | Leer tecla sin eco | `LEER_INPUT_JUGADOR`, `LEER_TECLA_DIRECTA`, `LEER_PALABRA_OCULTA`, `ESPERAR_ENTER` |
| `INT 21h, AH=09h` | Imprimir cadena terminada en `$` | `IMPRIMIR_CADENA` |
| `INT 21h, AH=2Ch` | Obtener hora del sistema | `GENERAR_ALEATORIO` |
| `INT 21h, AH=3Dh` | Abrir archivo (solo lectura) | `ABRIR_ARCHIVO` |
| `INT 21h, AH=3Fh` | Leer archivo | `ABRIR_ARCHIVO` |
| `INT 21h, AH=3Eh` | Cerrar archivo | `ABRIR_ARCHIVO` |
| `INT 21h, AH=4Ch` | Terminar programa | `FIN_PARTIDA`, opcion [3] Salir |

---

## 9. Formato de los archivos .txt

- Una palabra por linea, en **mayusculas**, sin tildes ni caracteres especiales.
- Las palabras se separan por salto de linea (CR+LF).
- Cada archivo debe tener al menos una palabra.

Clasificacion:

| Dificultad | Archivo | Letras por palabra | Cantidad |
|---|---|---|---|
| Facil | `facil.txt` | 4-5 | 20 |
| Medio | `medio.txt` | 6-8 | 15 |
| Dificil | `dificil.txt` | 9+ | 12 |

---

## 10. Resumen de procedimientos

### Interfaz + Entrada de usuario - (15 modulos)
`PANTALLA_INICIAL`, `MOSTRAR_JUEGO`, `LEER_INPUT_JUGADOR`, `MOSTRAR_ESTADISTICAS`, `MOSTRAR_RENDICION`, `CONFIRMAR_RENDIRSE`, `CONFIRMAR_RESET`, `CONFIRMAR_SALIR`, `LEER_NICKNAME`, `VALIDAR_NICKNAME`, `IMPRIMIR_NICK_ACTIVO`, `IMPRIMIR_NICK_RAW`, `IMPRIMIR_ESTADO_PALABRA`, `IMPRIMIR_LETRAS_USADAS`, `IMPRIMIR_PALABRA_COMPLETA`.

### Logica del juego - (19 modulos)
`COMPARAR_LETRA`, `VALIDAR_REPETIDA`, `DETECTAR_VICTORIA`, `DETECTAR_DERROTA`, `CALCULAR_PUNTAJE`, `PUNTAJE_DERROTA`, `ACUMULAR_PUNTAJE`, `CAMBIO_TURNO`, `IMPRIMIR_TURNO`, `REINICIAR_ESTADO`, `REINICIAR_USADAS`, `MOSTRAR_ESTADO_PRUEBA`, `LIMPIAR_PANTALLA`, `IMPRIMIR_CADENA`, `IMPRIMIR_CARACTER`, `IMPRIMIR_NUMERO`, `IMPRIMIR_PUNTAJE`, `NUEVA_LINEA`, `LEER_TECLA`.

### Archivos + Aleatoriedad + PvP - (7 modulos)
`CARGAR_PALABRA`, `CARGAR_PALABRA_ARCHIVO`, `ABRIR_ARCHIVO`, `CONTAR_PALABRAS`, `EXTRAER_PALABRA`, `GENERAR_ALEATORIO`, `LEER_PALABRA_OCULTA`.
