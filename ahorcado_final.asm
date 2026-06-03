;====================================================================
; PROYECTO: AHORCADO - Ensamblador 8086
;====================================================================

ORG 100H
JMP MAIN

;====================================================================
; SECCION DE DATOS GLOBALES 
;====================================================================

;Variables de juego
PALABRA        DB 20 DUP(0)         ; Palabra secreta actual
LONG_PALABRA   DB 0                 ; Longitud de la palabra
ESTADO         DB 20 DUP('_')       ; Letras reveladas (_ = sin adivinar)
ERRORES        DB 0                 ; Errores cometidos en este turno
LETRA_ACTUAL   DB 0                 ; Ultima letra ingresada
USADAS         DB 26 DUP(0)        ; A=pos0 .. Z=pos25, 1=usada
TURNO          DB 1                 ; 1=Jugador 1, 2=Jugador 2
MODALIDAD      DB 1                 ; 1=Maq vs Jugador, 2=PvP

TABLA_PUNTAJES DB 100, 100, 85, 70, 50, 30, 10

PUNTAJE_ACTUAL DB 0
PUNTAJE_J1     DW 0
PUNTAJE_J2     DW 0

MAX_ERRORES    EQU 6

;Variables de archivo 
DIFICULTAD     DB 1                 ; 1=facil, 2=medio, 3=dificil
BUFFER_ARCH    DB 2000 DUP(0)       ; Buffer para leer el archivo
BYTES_LEIDOS   DW 0
CONT_PALABRAS  DB 0
INDICE_SEL     DB 0
FILE_HANDLE    DW 0

ARCH_FACIL     DB 'facil.txt', 0
ARCH_MEDIO     DB 'medio.txt', 0
ARCH_DIFICIL   DB 'dificil.txt', 0

PAL_DEFAULT    DB 'PRUEBA'
LEN_DEFAULT    DB 6

;Variables de interfaz
NICK_J1        DB 11 DUP(0)        ; Nickname jugador 1
NICK_J2        DB 11 DUP(0)        ; Nickname jugador 2
LEN_NICK_J1    DB 0
LEN_NICK_J2    DB 0
ACCION_ESPECIAL DB 0               ; 0=ninguna 1=rendirse 2=reset 3=salir


;====================================================================
; MENSAJES (Interfaz)
;====================================================================

MSG_BIENVENIDA DB '+----------------------------------+', 0DH, 0AH
DB '|       AHORCADO  8086           |', 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH, '$'

MSG_PEDIR_NICK1 DB 0DH, 0AH
DB 'Nickname Jugador 1 (3-10 letras): $'
MSG_PEDIR_NICK2 DB 0DH, 0AH
DB 'Nickname Jugador 2 (3-10 letras): $'
MSG_ERR_NICK   DB 0DH, 0AH
DB '! Nickname invalido (3-10 caracteres).', 0DH, 0AH, '$'

MSG_MODO       DB 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH
DB '|      MODO  DE  JUEGO           |', 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH
DB '|  1. Maquina  vs  Jugador       |', 0DH, 0AH
DB '|  2. Jugador  vs  Jugador       |', 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH
DB '|  Seleccione opcion: _          |', 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_ERR_MODO   DB 0DH, 0AH
DB '! Opcion invalida. Ingrese 1 o 2.', 0DH, 0AH, '$'

MSG_DIFIC      DB 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH
DB '|        DIFICULTAD              |', 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH
DB '|  1. Facil                      |', 0DH, 0AH
DB '|  2. Medio                      |', 0DH, 0AH
DB '|  3. Dificil                    |', 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH
DB '|  Seleccione opcion: _          |', 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_ERR_DIFIC  DB 0DH, 0AH
DB '! Opcion invalida. Ingrese 1, 2 o 3.', 0DH, 0AH, '$'

MSG_JUGADOR    DB '| Jugador: $'
MSG_INTENTOS   DB '| Intentos restantes: $'
MSG_PUNTAJE_L  DB '| Puntaje: $'
MSG_PALABRA_L  DB '| Palabra: $'
MSG_USADAS_L   DB '| Letras usadas: $'
MSG_MARCO_TOP  DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_MARCO_MID  DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_MARCO_BOT  DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_OPCIONES   DB 0DH, 0AH
DB '[1] Rendirse  [2] Reset  [3] Salir', 0DH, 0AH, '$'
MSG_PEDIR_LETRA DB 0DH, 0AH, 'Ingrese una letra: $'
MSG_INV_LETRA  DB 0DH, 0AH, '! Entrada invalida.', 0DH, 0AH, '$'

MSG_STATS_TOP  DB 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH
DB '|       ESTADISTICAS             |', 0DH, 0AH
DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_GANADOR    DB '| Ganador: $'
MSG_EMPATE     DB '| EMPATE!                        |', 0DH, 0AH, '$'
MSG_FLECHA     DB ' -> $'
MSG_PTS_STR    DB ' pts', 0DH, 0AH, '$'

MSG_CONFIRMAR_RENDIR DB 0DH, 0AH, 'Desea rendirse? (S/N): $'
MSG_CONFIRMAR_SALIR DB 0DH, 0AH, 'Desea salir? (S/N): $'
MSG_CONFIRMAR_RESET DB 0DH, 0AH, 'Desea reiniciar? (S/N): $'
MSG_SE_RINDIO  DB 'TE HAS RENDIDO', 0DH, 0AH
               DB 0DH, 0AH, 'La palabra era: $'
MSG_PALABRA_ERA DB 0DH, 0AH, 'La palabra era: $'
MSG_ENTER_CONT DB 0DH, 0AH, 'Presione ENTER para continuar...$'

; Mensajes del juego
MSG_TURNO_J1   DB 0DH, 0AH, '--- Turno del Jugador 1 ---', 0DH, 0AH, '$'
MSG_TURNO_J2   DB 0DH, 0AH, '--- Turno del Jugador 2 ---', 0DH, 0AH, '$'
MSG_VICTORIA   DB 0DH, 0AH, '!GANASTE la ronda!', 0DH, 0AH, '$'
MSG_DERROTA    DB 0DH, 0AH, '!PERDISTE! Intentos agotados', 0DH, 0AH, '$'
MSG_PT_RONDA   DB 'Puntaje de esta ronda: $'
MSG_REPETIDA   DB 0DH, 0AH, 'Letra ya usada, intente otra.', 0DH, 0AH, '$'
MSG_STATS      DB 0DH, 0AH, '=== ESTADISTICAS FINALES ===', 0DH, 0AH, '$'
MSG_TOTAL_J1   DB 'Jugador 1: $'
MSG_TOTAL_J2   DB 0DH, 0AH, 'Jugador 2: $'
MSG_FIN        DB 0DH, 0AH, 'Fin de la partida.', 0DH, 0AH, '$'

; Mensajes de PvP y archivos
MSG_PVP_J1     DB 0DH, 0AH
DB 'Jugador 1, ingrese la palabra secreta', 0DH, 0AH
DB '(Que el Jugador 2 NO mire): ', 0DH, 0AH, '$'
MSG_PVP_J2     DB 0DH, 0AH
DB 'Jugador 2, ingrese la palabra secreta', 0DH, 0AH
DB '(Que el Jugador 1 NO mire): ', 0DH, 0AH, '$'
MSG_OCULTA     DB 0DH, 0AH, 'Palabra (oculta): $'
MSG_CAMBIAR    DB 0DH, 0AH
DB '>>> PASE EL TECLADO AL OTRO JUGADOR <<<', 0DH, 0AH
DB 'Presione ENTER para continuar...$'
MSG_ERROR_ARCH DB 0DH, 0AH, '*** ERROR: Archivo no encontrado ***', 0DH, 0AH, '$'
MSG_USA_DEF    DB '(Usando palabra por defecto)', 0DH, 0AH, '$'


;====================================================================
;                    PROGRAMA PRINCIPAL 
;====================================================================

MAIN:
CALL LIMPIAR_PANTALLA

;------------------------------------------------------------------
; Pantalla inicial
; Pide nicknames, modo de juego y dificultad
;------------------------------------------------------------------
CALL PANTALLA_INICIAL

; Inicializar variables de partida
MOV  TURNO, 1
MOV  PUNTAJE_J1, 0
MOV  PUNTAJE_J2, 0

;------------------------------------------------------------------
; LOOP DE RONDAS
;------------------------------------------------------------------
RONDA:
CALL IMPRIMIR_TURNO             ; muestra "Turno del Jugador X"
CALL CARGAR_PALABRA             ; carga palabra (archivo o PvP)

LOOP_TURNO:
CALL CALCULAR_PUNTAJE           ; puntaje potencial segun errores
CALL MOSTRAR_JUEGO              ; dibuja el tablero completo

CALL LEER_INPUT_JUGADOR         ; lee letra o accion especial

; Verificar acciones especiales
CMP  ACCION_ESPECIAL, 1
JE   ACCION_RENDIRSE
CMP  ACCION_ESPECIAL, 2
JE   ACCION_RESET
CMP  ACCION_ESPECIAL, 3
JE   ACCION_SALIR_TOTAL

; Letra normal: procesarla
MOV  LETRA_ACTUAL, AL

CALL VALIDAR_REPETIDA           ; verifica si ya fue usada
JC   LETRA_YA_USADA

CALL COMPARAR_LETRA             ; busca la letra en la palabra

CALL DETECTAR_VICTORIA          ; verifica si ya se adivino
JC   GANO_RONDA

CALL DETECTAR_DERROTA           ; verifica si se agotaron intentos
JC   PERDIO_RONDA

JMP  LOOP_TURNO

LETRA_YA_USADA:
LEA  DX, MSG_REPETIDA
CALL IMPRIMIR_CADENA
JMP  LOOP_TURNO

;------------------------------------------------------------------
; Jugador se rindio 
;------------------------------------------------------------------
ACCION_RENDIRSE:
CALL MOSTRAR_RENDICION          ; muestra la palabra y mensaje
CALL PUNTAJE_DERROTA            ; puntaje = 0
CALL ACUMULAR_PUNTAJE
JMP  FIN_RONDA

;------------------------------------------------------------------
; Reset de la ronda 
;------------------------------------------------------------------
ACCION_RESET:
JMP  MAIN

;------------------------------------------------------------------
; Salir del juego 
;------------------------------------------------------------------
ACCION_SALIR_TOTAL:
CALL MOSTRAR_ESTADISTICAS
MOV  AH, 4CH
INT  21H

;------------------------------------------------------------------
; Fin de ronda: victoria
;------------------------------------------------------------------
GANO_RONDA:
CALL MOSTRAR_JUEGO              ; tablero final con la palabra
LEA  DX, MSG_VICTORIA
CALL IMPRIMIR_CADENA
CALL CALCULAR_PUNTAJE
CALL ACUMULAR_PUNTAJE           ; sumar puntaje al jugador activo
LEA  DX, MSG_PT_RONDA
CALL IMPRIMIR_CADENA
CALL IMPRIMIR_PUNTAJE
LEA  DX, MSG_ENTER_CONT
CALL IMPRIMIR_CADENA
CALL ESPERAR_ENTER
JMP  FIN_RONDA

;------------------------------------------------------------------
; Fin de ronda: derrota
;------------------------------------------------------------------
PERDIO_RONDA:
CALL MOSTRAR_JUEGO
LEA  DX, MSG_DERROTA
CALL IMPRIMIR_CADENA
    ; Mostrar palabra real
    LEA  DX, MSG_PALABRA_ERA
CALL IMPRIMIR_CADENA
CALL IMPRIMIR_PALABRA_COMPLETA  ; P1: imprime PALABRA letra por letra
CALL NUEVA_LINEA
CALL PUNTAJE_DERROTA
CALL ACUMULAR_PUNTAJE
LEA  DX, MSG_PT_RONDA
CALL IMPRIMIR_CADENA
CALL IMPRIMIR_PUNTAJE
LEA  DX, MSG_ENTER_CONT
CALL IMPRIMIR_CADENA
CALL ESPERAR_ENTER

FIN_RONDA:
; Si ya jugaron los dos en PvP (o termino la ronda unica), fin
CMP  TURNO, 2
JE   FIN_PARTIDA
CMP  MODALIDAD, 1               ; Modo maquina: una sola ronda
JE   FIN_PARTIDA

; PvP: cambiar turno y jugar segunda ronda
CALL CAMBIO_TURNO               ; alterna TURNO y resetea datos
JMP  RONDA

FIN_PARTIDA:
; P1: mostrar estadisticas con ganador
CALL MOSTRAR_ESTADISTICAS
MOV  AH, 4CH
INT  21H

;--------------------------------------------------------------------
; PANTALLA_INICIAL
; Pide nicknames, modo de juego y dificultad al inicio de partida
;--------------------------------------------------------------------

PANTALLA_INICIAL PROC
PUSH AX
PUSH DX

CALL LIMPIAR_PANTALLA
LEA  DX, MSG_BIENVENIDA
CALL IMPRIMIR_CADENA

; Pedir nickname Jugador 1
PI_NICK1:
LEA  DX, MSG_PEDIR_NICK1
CALL IMPRIMIR_CADENA
LEA  DX, NICK_J1
CALL LEER_NICKNAME              ; Lee y guarda nick, retorna longitud en AL
CALL VALIDAR_NICKNAME           ; CF=1 si invalido
JNC  PI_NICK1_OK
LEA  DX, MSG_ERR_NICK
CALL IMPRIMIR_CADENA
JMP  PI_NICK1
PI_NICK1_OK:
MOV  LEN_NICK_J1, AL

; Seleccion de modo
PI_MODO:
LEA  DX, MSG_MODO
CALL IMPRIMIR_CADENA
CALL LEER_TECLA_DIRECTA
CMP  AL, '1'
JE   PI_ES_MAQ
CMP  AL, '2'
JE   PI_ES_PVP
LEA  DX, MSG_ERR_MODO
CALL IMPRIMIR_CADENA
JMP  PI_MODO

PI_ES_MAQ:
MOV  MODALIDAD, 1
JMP  PI_DIFIC

PI_ES_PVP:
MOV  MODALIDAD, 2
; Pedir nick J2 solo en PvP
PI_NICK2:
LEA  DX, MSG_PEDIR_NICK2
CALL IMPRIMIR_CADENA
LEA  DX, NICK_J2
CALL LEER_NICKNAME
CALL VALIDAR_NICKNAME
JNC  PI_NICK2_OK
LEA  DX, MSG_ERR_NICK
CALL IMPRIMIR_CADENA
JMP  PI_NICK2
PI_NICK2_OK:
MOV  LEN_NICK_J2, AL
JMP  PI_FIN                     ; PvP no usa dificultad

PI_DIFIC:
PI_DIFIC_LOOP:
LEA  DX, MSG_DIFIC
CALL IMPRIMIR_CADENA
CALL LEER_TECLA_DIRECTA
CMP  AL, '1'
JE   PI_DIFIC_OK
CMP  AL, '2'
JE   PI_DIFIC_OK
CMP  AL, '3'
JE   PI_DIFIC_OK
LEA  DX, MSG_ERR_DIFIC
CALL IMPRIMIR_CADENA
JMP  PI_DIFIC_LOOP
PI_DIFIC_OK:
SUB  AL, '0'
MOV  DIFICULTAD, AL

PI_FIN:
POP  DX
POP  AX
RET
PANTALLA_INICIAL ENDP

;--------------------------------------------------------------------
; MOSTRAR_JUEGO
; Dibuja el tablero completo del juego actual
;--------------------------------------------------------------------

MOSTRAR_JUEGO PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI

CALL LIMPIAR_PANTALLA

LEA  DX, MSG_MARCO_TOP
CALL IMPRIMIR_CADENA

; Jugador activo
LEA  DX, MSG_JUGADOR
CALL IMPRIMIR_CADENA
CALL IMPRIMIR_NICK_ACTIVO
CALL NUEVA_LINEA

; Intentos restantes
LEA  DX, MSG_INTENTOS
CALL IMPRIMIR_CADENA
MOV  AL, MAX_ERRORES
SUB  AL, ERRORES
MOV  DL, AL
ADD  DL, '0'
CALL IMPRIMIR_CARACTER
CALL NUEVA_LINEA

; Puntaje potencial
LEA  DX, MSG_PUNTAJE_L
CALL IMPRIMIR_CADENA
MOV  AL, PUNTAJE_ACTUAL
MOV  AH, 0
CALL IMPRIMIR_NUMERO
CALL NUEVA_LINEA

LEA  DX, MSG_MARCO_MID
CALL IMPRIMIR_CADENA

; Estado de la palabra
LEA  DX, MSG_PALABRA_L
CALL IMPRIMIR_CADENA
CALL IMPRIMIR_ESTADO_PALABRA
CALL NUEVA_LINEA

LEA  DX, MSG_MARCO_MID
CALL IMPRIMIR_CADENA

; Letras usadas
LEA  DX, MSG_USADAS_L
CALL IMPRIMIR_CADENA
CALL IMPRIMIR_LETRAS_USADAS
CALL NUEVA_LINEA

; Opciones
LEA  DX, MSG_OPCIONES
CALL IMPRIMIR_CADENA

POP  SI
POP  DX
POP  CX
POP  BX
POP  AX
RET
MOSTRAR_JUEGO ENDP

;--------------------------------------------------------------------
; LEER_INPUT_JUGADOR
; Lee una tecla. Detecta letras A-Z y opciones R/X/S.
; Sale con AL=letra o AL=0 si fue accion especial.
; Escribe ACCION_ESPECIAL: 0=ninguna 1=rendirse 2=reset 3=salir
;--------------------------------------------------------------------

LEER_INPUT_JUGADOR PROC
PUSH DX

MOV  ACCION_ESPECIAL, 0
LEA  DX, MSG_PEDIR_LETRA
CALL IMPRIMIR_CADENA

LIJ_LEER:
CALL LEER_TECLA_DIRECTA

CMP  AL, '1'
JE   LIJ_RENDIRSE
CMP  AL, '2'
JE   LIJ_RESET
CMP  AL, '3'
JE   LIJ_SALIR

CMP  AL, 'A'
JB   LIJ_INVALIDA
CMP  AL, 'Z'
JA   LIJ_INVALIDA
JMP  LIJ_FIN

LIJ_INVALIDA:
LEA  DX, MSG_INV_LETRA
CALL IMPRIMIR_CADENA
JMP  LIJ_LEER

LIJ_RENDIRSE:
CALL CONFIRMAR_RENDIRSE
JNC  LIJ_ACCION_R
JMP  LIJ_LEER
LIJ_ACCION_R:
MOV  ACCION_ESPECIAL, 1
MOV  AL, 0
JMP  LIJ_FIN

LIJ_RESET:
CALL CONFIRMAR_RESET
JNC  LIJ_ACCION_X
JMP  LIJ_LEER
LIJ_ACCION_X:
MOV  ACCION_ESPECIAL, 2
MOV  AL, 0
JMP  LIJ_FIN

LIJ_SALIR:
CALL CONFIRMAR_SALIR
JNC  LIJ_ACCION_S
JMP  LIJ_LEER
LIJ_ACCION_S:
MOV  ACCION_ESPECIAL, 3
MOV  AL, 0

LIJ_FIN:
POP  DX
RET
LEER_INPUT_JUGADOR ENDP

;--------------------------------------------------------------------
; MOSTRAR_ESTADISTICAS
; Muestra puntajes de J1 y J2 (si PvP) y declara ganador
;--------------------------------------------------------------------

MOSTRAR_ESTADISTICAS PROC
PUSH AX
PUSH DX

CALL LIMPIAR_PANTALLA
LEA  DX, MSG_STATS_TOP
CALL IMPRIMIR_CADENA

; J1
LEA  DX, NICK_J1
CALL IMPRIMIR_NICK_RAW
LEA  DX, MSG_FLECHA
CALL IMPRIMIR_CADENA
MOV  AX, PUNTAJE_J1
CALL IMPRIMIR_NUMERO
LEA  DX, MSG_PTS_STR
CALL IMPRIMIR_CADENA

; J2 solo en PvP
CMP  MODALIDAD, 2
JNE  ME_SIN_J2
LEA  DX, NICK_J2
CALL IMPRIMIR_NICK_RAW
LEA  DX, MSG_FLECHA
CALL IMPRIMIR_CADENA
MOV  AX, PUNTAJE_J2
CALL IMPRIMIR_NUMERO
LEA  DX, MSG_PTS_STR
CALL IMPRIMIR_CADENA

ME_SIN_J2:
LEA  DX, MSG_MARCO_MID
CALL IMPRIMIR_CADENA

; Ganador
    CMP  MODALIDAD, 2
    JNE  ME_RESULTADO_MAQ
; PvP: comparar puntajes
    MOV  AX, PUNTAJE_J1
    CMP  AX, PUNTAJE_J2
    JA   ME_GANA_J1
    JB   ME_GANA_J2
    LEA  DX, MSG_EMPATE
    CALL IMPRIMIR_CADENA
    JMP  ME_CIERRE

ME_RESULTADO_MAQ:
; Maquina: si PUNTAJE_J1=0 significa que perdio o se rindio
    CMP  PUNTAJE_J1, 0
    JE   ME_CIERRE
    JMP  ME_GANA_J1

ME_GANA_J1:
LEA  DX, MSG_GANADOR
CALL IMPRIMIR_CADENA
LEA  DX, NICK_J1
CALL IMPRIMIR_NICK_RAW
CALL NUEVA_LINEA
JMP  ME_CIERRE

ME_GANA_J2:
LEA  DX, MSG_GANADOR
CALL IMPRIMIR_CADENA
LEA  DX, NICK_J2
CALL IMPRIMIR_NICK_RAW
CALL NUEVA_LINEA

ME_CIERRE:
LEA  DX, MSG_FIN
CALL IMPRIMIR_CADENA

POP  DX
POP  AX
RET
MOSTRAR_ESTADISTICAS ENDP

;--------------------------------------------------------------------
; MOSTRAR_RENDICION
; Muestra la palabra al jugador que se rindio
;--------------------------------------------------------------------

MOSTRAR_RENDICION PROC
    PUSH CX
    PUSH DX
    PUSH SI

    CALL LIMPIAR_PANTALLA
    LEA  DX, MSG_SE_RINDIO
CALL IMPRIMIR_CADENA
CALL IMPRIMIR_PALABRA_COMPLETA
CALL NUEVA_LINEA
LEA  DX, MSG_ENTER_CONT
CALL IMPRIMIR_CADENA
CALL ESPERAR_ENTER

POP  SI
POP  DX
POP  CX
RET
MOSTRAR_RENDICION ENDP

;--------------------------------------------------------------------
; IMPRIMIR_PALABRA_COMPLETA
; Imprime PALABRA letra a letra segun LONG_PALABRA
;--------------------------------------------------------------------

IMPRIMIR_PALABRA_COMPLETA PROC
PUSH CX
PUSH DX
PUSH SI

XOR  SI, SI
MOV  CL, LONG_PALABRA
MOV  CH, 0
IPC_LOOP:
MOV  DL, PALABRA[SI]
CALL IMPRIMIR_CARACTER
INC  SI
LOOP IPC_LOOP

POP  SI
POP  DX
POP  CX
RET
IMPRIMIR_PALABRA_COMPLETA ENDP

;--------------------------------------------------------------------
; IMPRIMIR_ESTADO_PALABRA
; Muestra ESTADO con espacios: _ A _ _ A
;--------------------------------------------------------------------

IMPRIMIR_ESTADO_PALABRA PROC
PUSH AX
PUSH CX
PUSH DX
PUSH SI

XOR  SI, SI
MOV  CL, LONG_PALABRA
MOV  CH, 0
IEP_LOOP:
MOV  DL, ESTADO[SI]
CALL IMPRIMIR_CARACTER
MOV  DL, ' '
CALL IMPRIMIR_CARACTER
INC  SI
LOOP IEP_LOOP

POP  SI
POP  DX
POP  CX
POP  AX
RET
IMPRIMIR_ESTADO_PALABRA ENDP

;--------------------------------------------------------------------
; IMPRIMIR_LETRAS_USADAS
; Recorre USADAS e imprime las marcadas como usadas (=1)
;--------------------------------------------------------------------

IMPRIMIR_LETRAS_USADAS PROC
PUSH AX
PUSH BX
PUSH DX

XOR  BX, BX
ILU_LOOP:
CMP  BX, 26
JAE  ILU_FIN
CMP  USADAS[BX], 1
JNE  ILU_SIGUIENTE
MOV  DL, BL
ADD  DL, 'A'
CALL IMPRIMIR_CARACTER
MOV  DL, ' '
CALL IMPRIMIR_CARACTER
ILU_SIGUIENTE:
INC  BX
JMP  ILU_LOOP
ILU_FIN:
POP  DX
POP  BX
POP  AX
RET
IMPRIMIR_LETRAS_USADAS ENDP

;--------------------------------------------------------------------
; IMPRIMIR_NICK_ACTIVO
; Imprime el nickname del jugador segun TURNO actual
;--------------------------------------------------------------------

IMPRIMIR_NICK_ACTIVO PROC
PUSH DX
CMP  TURNO, 1
JNE  INA_J2
LEA  DX, NICK_J1
JMP  INA_PRINT
INA_J2:
LEA  DX, NICK_J2
INA_PRINT:
CALL IMPRIMIR_NICK_RAW
POP  DX
RET
IMPRIMIR_NICK_ACTIVO ENDP

;--------------------------------------------------------------------
; IMPRIMIR_NICK_RAW
; Imprime la cadena en DX hasta encontrar byte 0
;--------------------------------------------------------------------

IMPRIMIR_NICK_RAW PROC
PUSH AX
PUSH DX
PUSH SI

MOV  SI, DX
INR_LOOP:
MOV  AL, [SI]
CMP  AL, 0
JE   INR_FIN
MOV  DL, AL
CALL IMPRIMIR_CARACTER
INC  SI
JMP  INR_LOOP
INR_FIN:
POP  SI
POP  DX
POP  AX
RET
IMPRIMIR_NICK_RAW ENDP

;--------------------------------------------------------------------
; LEER_NICKNAME
; Lee hasta 10 caracteres A-Z 0-9 con backspace y ENTER.
; DX = buffer destino. Retorna AL = longitud.
;--------------------------------------------------------------------

LEER_NICKNAME PROC
PUSH BX
PUSH DX
PUSH SI

MOV  SI, DX
XOR  BL, BL

LN_LEER:
MOV  AH, 01H
INT  21H

CMP  AL, 0DH
JE   LN_FIN
CMP  AL, 08H
JE   LN_BORRAR

CMP  AL, 'a'
JB   LN_FILTRAR
CMP  AL, 'z'
JA   LN_FILTRAR
SUB  AL, 20H

LN_FILTRAR:
CMP  AL, 'A'
JB   LN_IGNORAR
CMP  AL, 'Z'
JBE  LN_GUARDAR
CMP  AL, '0'
JB   LN_IGNORAR
CMP  AL, '9'
JA   LN_IGNORAR

LN_GUARDAR:
CMP  BL, 10
JAE  LN_IGNORAR
MOV  [SI], AL
INC  SI
INC  BL
JMP  LN_LEER

LN_IGNORAR:
JMP  LN_LEER

LN_BORRAR:
CMP  BL, 0
JE   LN_LEER
MOV  AH, 02H
MOV  DL, 08H
INT  21H
MOV  DL, ' '
INT  21H
MOV  DL, 08H
INT  21H
DEC  SI
DEC  BL
JMP  LN_LEER

LN_FIN:
MOV  BYTE PTR [SI], 0
MOV  AL, BL

POP  SI
POP  DX
POP  BX
RET
LEER_NICKNAME ENDP

;--------------------------------------------------------------------
; VALIDAR_NICKNAME
; AL = longitud. CF=0 si 3<=AL<=10, CF=1 si invalido
;--------------------------------------------------------------------

VALIDAR_NICKNAME PROC
CMP  AL, 3
JB   VN_INVALIDO
CMP  AL, 10
JA   VN_INVALIDO
CLC
RET
VN_INVALIDO:
STC
RET
VALIDAR_NICKNAME ENDP

;--------------------------------------------------------------------
; CONFIRMAR_RENDIRSE / CONFIRMAR_RESET / CONFIRMAR_SALIR
; CF=0 si confirmo (S), CF=1 si cancelo
;--------------------------------------------------------------------

CONFIRMAR_RENDIRSE PROC
PUSH DX
LEA  DX, MSG_CONFIRMAR_RENDIR
CALL IMPRIMIR_CADENA
CALL LEER_TECLA_DIRECTA
CMP  AL, 'S'
JE   CR_SI
STC
JMP  CR_FIN
CR_SI:
CLC
CR_FIN:
POP  DX
RET
CONFIRMAR_RENDIRSE ENDP

CONFIRMAR_RESET PROC
PUSH DX
LEA  DX, MSG_CONFIRMAR_RESET
CALL IMPRIMIR_CADENA
CALL LEER_TECLA_DIRECTA
CMP  AL, 'S'
JE   CRESET_SI
STC
JMP  CRESET_FIN
CRESET_SI:
CLC
CRESET_FIN:
POP  DX
RET
CONFIRMAR_RESET ENDP

CONFIRMAR_SALIR PROC
PUSH DX
LEA  DX, MSG_CONFIRMAR_SALIR
CALL IMPRIMIR_CADENA
CALL LEER_TECLA_DIRECTA
CMP  AL, 'S'
JE   CS_SI
STC
JMP  CS_FIN
CS_SI:
CLC
CS_FIN:
POP  DX
RET
CONFIRMAR_SALIR ENDP

;--------------------------------------------------------------------
; COMPARAR_LETRA
; Busca LETRA_ACTUAL en PALABRA y actualiza ESTADO.
; Si no encuentra la letra, incrementa ERRORES.
;--------------------------------------------------------------------

COMPARAR_LETRA PROC
PUSH BX
PUSH CX
PUSH SI
PUSH DX

XOR  SI, SI
XOR  BX, BX
MOV  CL, LONG_PALABRA
MOV  CH, 0
MOV  AL, LETRA_ACTUAL

COMP_LOOP:
CMP  PALABRA[SI], AL
JNE  COMP_NO_MATCH
MOV  ESTADO[SI], AL
INC  BX
COMP_NO_MATCH:
INC  SI
LOOP COMP_LOOP

CMP  BX, 0
JNE  COMP_FIN
INC  ERRORES
COMP_FIN:
MOV  AL, BL
POP  DX
POP  SI
POP  CX
POP  BX
RET
COMPARAR_LETRA ENDP

;--------------------------------------------------------------------
; VALIDAR_REPETIDA
; Verifica si LETRA_ACTUAL ya fue usada.
; CF=0 si es nueva (y la marca), CF=1 si ya estaba usada.
;--------------------------------------------------------------------

VALIDAR_REPETIDA PROC
PUSH AX
PUSH BX

MOV  AL, LETRA_ACTUAL
SUB  AL, 'A'
MOV  BL, AL
MOV  BH, 0

CMP  USADAS[BX], 1
JE   VR_REPETIDA

MOV  USADAS[BX], 1
CLC
JMP  VR_FIN
VR_REPETIDA:
STC
VR_FIN:
POP  BX
POP  AX
RET
VALIDAR_REPETIDA ENDP


;--------------------------------------------------------------------
; REINICIAR_USADAS
; Pone en 0 los 26 bytes del arreglo USADAS
;--------------------------------------------------------------------
REINICIAR_USADAS PROC
PUSH AX
PUSH CX
PUSH DI
PUSH ES

PUSH DS
POP  ES
LEA  DI, USADAS
MOV  CX, 26
MOV  AL, 0
REP  STOSB

POP  ES
POP  DI
POP  CX
POP  AX
RET
REINICIAR_USADAS ENDP


;--------------------------------------------------------------------
; REINICIAR_ESTADO
; Llena ESTADO con '_' segun LONG_PALABRA
;--------------------------------------------------------------------
REINICIAR_ESTADO PROC
PUSH AX
PUSH CX
PUSH DI
PUSH ES

PUSH DS
POP  ES
LEA  DI, ESTADO
MOV  CL, LONG_PALABRA
MOV  CH, 0
MOV  AL, '_'
REP  STOSB

POP  ES
POP  DI
POP  CX
POP  AX
RET
REINICIAR_ESTADO ENDP


;--------------------------------------------------------------------
; DETECTAR_VICTORIA
; CF=1 si no quedan '_' en ESTADO (gano), CF=0 si hay guiones
;--------------------------------------------------------------------
DETECTAR_VICTORIA PROC
PUSH AX
PUSH CX
PUSH SI

XOR  SI, SI
MOV  CL, LONG_PALABRA
MOV  CH, 0

DV_LOOP:
CMP  ESTADO[SI], '_'
JE   DV_NO_GANO
INC  SI
LOOP DV_LOOP

STC
JMP  DV_FIN
DV_NO_GANO:
CLC
DV_FIN:
POP  SI
POP  CX
POP  AX
RET
DETECTAR_VICTORIA ENDP


;--------------------------------------------------------------------
; DETECTAR_DERROTA
; CF=1 si ERRORES >= MAX_ERRORES
;--------------------------------------------------------------------
DETECTAR_DERROTA PROC
PUSH AX

MOV  AL, ERRORES
CMP  AL, MAX_ERRORES
JB   DD_SIGUE
STC
JMP  DD_FIN
DD_SIGUE:
CLC
DD_FIN:
POP  AX
RET
DETECTAR_DERROTA ENDP


;--------------------------------------------------------------------
; CALCULAR_PUNTAJE
; Consulta TABLA_PUNTAJES[ERRORES] y guarda en PUNTAJE_ACTUAL
;--------------------------------------------------------------------
CALCULAR_PUNTAJE PROC
PUSH BX

MOV  BL, ERRORES
MOV  BH, 0
MOV  AL, TABLA_PUNTAJES[BX]
MOV  PUNTAJE_ACTUAL, AL

POP  BX
RET
CALCULAR_PUNTAJE ENDP


;--------------------------------------------------------------------
; PUNTAJE_DERROTA
; Pone PUNTAJE_ACTUAL en 0 (perdio o se rindio)
;--------------------------------------------------------------------
PUNTAJE_DERROTA PROC
MOV  PUNTAJE_ACTUAL, 0
RET
PUNTAJE_DERROTA ENDP


;--------------------------------------------------------------------
; ACUMULAR_PUNTAJE
; Suma PUNTAJE_ACTUAL al puntaje del jugador activo (J1 o J2)
;--------------------------------------------------------------------
ACUMULAR_PUNTAJE PROC
PUSH AX

MOV  AL, PUNTAJE_ACTUAL
MOV  AH, 0

CMP  TURNO, 1
JNE  AP_JUGADOR_2
ADD  PUNTAJE_J1, AX
JMP  AP_FIN
AP_JUGADOR_2:
ADD  PUNTAJE_J2, AX
AP_FIN:
POP  AX
RET
ACUMULAR_PUNTAJE ENDP


;--------------------------------------------------------------------
; CAMBIO_TURNO
; Alterna TURNO entre 1 y 2, resetea ERRORES y USADAS
;--------------------------------------------------------------------
CAMBIO_TURNO PROC
PUSH AX

MOV  AL, TURNO
CMP  AL, 1
JE   CT_PASA_A_2
MOV  TURNO, 1
JMP  CT_LIMPIAR
CT_PASA_A_2:
MOV  TURNO, 2
CT_LIMPIAR:
MOV  ERRORES, 0
MOV  PUNTAJE_ACTUAL, 0
CALL REINICIAR_USADAS

POP  AX
RET
CAMBIO_TURNO ENDP


;--------------------------------------------------------------------
; IMPRIMIR_TURNO
; Muestra "Turno del Jugador X" segun TURNO
;--------------------------------------------------------------------
IMPRIMIR_TURNO PROC
PUSH DX

CMP  TURNO, 1
JNE  IT_J2
LEA  DX, MSG_TURNO_J1
JMP  IT_PRINT
IT_J2:
LEA  DX, MSG_TURNO_J2
IT_PRINT:
CALL IMPRIMIR_CADENA

POP  DX
RET
IMPRIMIR_TURNO ENDP


;--------------------------------------------------------------------
; IMPRIMIR_PUNTAJE
; Imprime PUNTAJE_ACTUAL como decimal
;--------------------------------------------------------------------

IMPRIMIR_PUNTAJE PROC
PUSH AX

MOV  AL, PUNTAJE_ACTUAL
MOV  AH, 0
CALL IMPRIMIR_NUMERO

POP  AX
RET
IMPRIMIR_PUNTAJE ENDP

;--------------------------------------------------------------------
; CARGAR_PALABRA
; Segun MODALIDAD carga la palabra del archivo (modo Maq) o del
; jugador (modo PvP). Resetea ESTADO, ERRORES y USADAS al salir.
;--------------------------------------------------------------------

CARGAR_PALABRA PROC
CMP  MODALIDAD, 2
JE   CP_PVP

CALL CARGAR_PALABRA_ARCHIVO
JMP  CP_VERIFICAR

CP_PVP:
CALL LEER_PALABRA_OCULTA

CP_VERIFICAR:
CMP  LONG_PALABRA, 0
JNE  CP_RESETEAR

; Fallback: usar PRUEBA
PUSH DS
POP  ES
MOV  LONG_PALABRA, 6
LEA  SI, PAL_DEFAULT
LEA  DI, PALABRA
MOV  CX, 6
REP  MOVSB

CP_RESETEAR:
CALL REINICIAR_ESTADO
MOV  ERRORES, 0
CALL REINICIAR_USADAS
RET
CARGAR_PALABRA ENDP


;--------------------------------------------------------------------
; CARGAR_PALABRA_ARCHIVO
; Abre el .txt segun DIFICULTAD, cuenta palabras, elige una al azar
;--------------------------------------------------------------------
CARGAR_PALABRA_ARCHIVO PROC
PUSH AX
PUSH CX
PUSH DX

CALL ABRIR_ARCHIVO
JC   CPA_ERROR

CALL CONTAR_PALABRAS

CMP  CONT_PALABRAS, 0
JE   CPA_ERROR

CALL GENERAR_ALEATORIO
CALL EXTRAER_PALABRA

CMP  LONG_PALABRA, 0
JNE  CPA_FIN

CPA_ERROR:
LEA  DX, MSG_ERROR_ARCH
CALL IMPRIMIR_CADENA
LEA  DX, MSG_USA_DEF
CALL IMPRIMIR_CADENA

PUSH DS
POP  ES
MOV  CL, LEN_DEFAULT
MOV  LONG_PALABRA, CL
MOV  CH, 0
LEA  SI, PAL_DEFAULT
LEA  DI, PALABRA
REP  MOVSB

CPA_FIN:
POP  DX
POP  CX
POP  AX
RET
CARGAR_PALABRA_ARCHIVO ENDP


;--------------------------------------------------------------------
; ABRIR_ARCHIVO
; Selecciona y abre el archivo .txt segun DIFICULTAD,
; lee hasta 2000 bytes en BUFFER_ARCH.
; CF=0 exito, CF=1 error
;--------------------------------------------------------------------
ABRIR_ARCHIVO PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX

MOV  AL, DIFICULTAD
CMP  AL, 1
JNE  AA_VER_MEDIO
LEA  DX, ARCH_FACIL
JMP  AA_ABRIR
AA_VER_MEDIO:
CMP  AL, 2
JNE  AA_DIFICIL
LEA  DX, ARCH_MEDIO
JMP  AA_ABRIR
AA_DIFICIL:
LEA  DX, ARCH_DIFICIL

AA_ABRIR:
MOV  AH, 3DH
MOV  AL, 0
INT  21H
JC   AA_ERROR

MOV  FILE_HANDLE, AX

MOV  AH, 3FH
MOV  BX, FILE_HANDLE
LEA  DX, BUFFER_ARCH
MOV  CX, 2000
INT  21H
JC   AA_ERROR_CERRAR

MOV  BYTES_LEIDOS, AX

MOV  AH, 3EH
MOV  BX, FILE_HANDLE
INT  21H

CLC
JMP  AA_FIN

AA_ERROR_CERRAR:
MOV  AH, 3EH
MOV  BX, FILE_HANDLE
INT  21H
AA_ERROR:
STC
AA_FIN:
POP  DX
POP  CX
POP  BX
POP  AX
RET
ABRIR_ARCHIVO ENDP


;--------------------------------------------------------------------
; CONTAR_PALABRAS
; Cuenta cuantas palabras hay en BUFFER_ARCH separadas por CR/LF.
; Resultado en CONT_PALABRAS.
;--------------------------------------------------------------------
CONTAR_PALABRAS PROC
PUSH AX
PUSH CX
PUSH SI

LEA  SI, BUFFER_ARCH
MOV  CX, BYTES_LEIDOS
XOR  AL, AL

CMP  CX, 0
JE   CPAL_FIN

CPAL_BUCLE:
CMP  CX, 0
JE   CPAL_FIN
MOV  AH, [SI]
CMP  AH, 0DH
JE   CPAL_AVANZAR
CMP  AH, 0AH
JE   CPAL_AVANZAR

INC  AL

CPAL_SALTAR:
CMP  CX, 0
JE   CPAL_FIN
MOV  AH, [SI]
CMP  AH, 0DH
JE   CPAL_AVANZAR
CMP  AH, 0AH
JE   CPAL_AVANZAR
INC  SI
DEC  CX
JMP  CPAL_SALTAR

CPAL_AVANZAR:
INC  SI
DEC  CX
JMP  CPAL_BUCLE

CPAL_FIN:
MOV  CONT_PALABRAS, AL

POP  SI
POP  CX
POP  AX
RET
CONTAR_PALABRAS ENDP


;--------------------------------------------------------------------
; GENERAR_ALEATORIO
; Usa centesimas del reloj del sistema para elegir INDICE_SEL
; entre 0 y CONT_PALABRAS-1
;--------------------------------------------------------------------
GENERAR_ALEATORIO PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX

CMP  CONT_PALABRAS, 0
JE   GA_CERO

MOV  AH, 2CH
INT  21H

MOV  AL, DL
MOV  AH, 0
MOV  BL, CONT_PALABRAS
DIV  BL
MOV  INDICE_SEL, AH
JMP  GA_FIN

GA_CERO:
MOV  INDICE_SEL, 0

GA_FIN:
POP  DX
POP  CX
POP  BX
POP  AX
RET
GENERAR_ALEATORIO ENDP


;--------------------------------------------------------------------
; EXTRAER_PALABRA
; Copia la palabra numero INDICE_SEL del buffer a PALABRA.
; Guarda la longitud en LONG_PALABRA (max 20 caracteres).
;--------------------------------------------------------------------
EXTRAER_PALABRA PROC
PUSH AX
PUSH BX
PUSH CX
PUSH SI
PUSH DI

LEA  SI, BUFFER_ARCH
MOV  CX, BYTES_LEIDOS
XOR  BL, BL
LEA  DI, PALABRA
MOV  LONG_PALABRA, 0

CMP  CX, 0
JE   EP_FIN

EP_BUCLE:
CMP  CX, 0
JE   EP_FIN
MOV  AL, [SI]
CMP  AL, 0DH
JE   EP_AVANZAR
CMP  AL, 0AH
JE   EP_AVANZAR

CMP  BL, INDICE_SEL
JE   EP_COPIAR

INC  BL

EP_SALTAR:
CMP  CX, 0
JE   EP_FIN
MOV  AL, [SI]
CMP  AL, 0DH
JE   EP_AVANZAR
CMP  AL, 0AH
JE   EP_AVANZAR
INC  SI
DEC  CX
JMP  EP_SALTAR

EP_COPIAR:
CMP  CX, 0
JE   EP_FIN
MOV  AL, [SI]
CMP  AL, 0DH
JE   EP_FIN
CMP  AL, 0AH
JE   EP_FIN
CMP  LONG_PALABRA, 20
JAE  EP_FIN

MOV  [DI], AL
INC  DI
INC  LONG_PALABRA
INC  SI
DEC  CX
JMP  EP_COPIAR

EP_AVANZAR:
INC  SI
DEC  CX
JMP  EP_BUCLE

EP_FIN:
POP  DI
POP  SI
POP  CX
POP  BX
POP  AX
RET
EXTRAER_PALABRA ENDP


;--------------------------------------------------------------------
; LEER_PALABRA_OCULTA
; En modo PvP: el jugador que NO adivina escribe la palabra
; mostrando '*' por cada letra. Soporta Backspace, max 20 letras.
;--------------------------------------------------------------------
LEER_PALABRA_OCULTA PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI
PUSH DI

; El que NO adivina ingresa la palabra
CMP  TURNO, 1
JNE  LO_ES_J2
LEA  DX, MSG_PVP_J2
JMP  LO_MOSTRAR
LO_ES_J2:
LEA  DX, MSG_PVP_J1

LO_MOSTRAR:
CALL IMPRIMIR_CADENA

LEA  DX, MSG_OCULTA
CALL IMPRIMIR_CADENA

LEA  DI, PALABRA
XOR  BL, BL

LO_LEER:
MOV  AH, 08H
INT  21H

CMP  AL, 0DH
JE   LO_FIN
CMP  AL, 08H
JE   LO_BORRAR

CMP  AL, 'a'
JB   LO_FILTRAR
CMP  AL, 'z'
JA   LO_FILTRAR
SUB  AL, 20H

LO_FILTRAR:
CMP  AL, 'A'
JB   LO_LEER
CMP  AL, 'Z'
JA   LO_LEER

CMP  BL, 20
JAE  LO_LEER

MOV  [DI], AL
INC  DI
INC  BL

PUSH AX
MOV  AH, 02H
MOV  DL, '*'
INT  21H
POP  AX
JMP  LO_LEER

LO_BORRAR:
CMP  BL, 0
JE   LO_LEER

MOV  AH, 02H
MOV  DL, 08H
INT  21H
MOV  DL, ' '
INT  21H
MOV  DL, 08H
INT  21H

DEC  DI
DEC  BL
JMP  LO_LEER

LO_FIN:
MOV  LONG_PALABRA, BL

CALL NUEVA_LINEA
LEA  DX, MSG_CAMBIAR
CALL IMPRIMIR_CADENA

LO_ESPERAR:
MOV  AH, 08H
INT  21H
CMP  AL, 0DH
JNE  LO_ESPERAR

CALL LIMPIAR_PANTALLA

POP  DI
POP  SI
POP  DX
POP  CX
POP  BX
POP  AX
RET
LEER_PALABRA_OCULTA ENDP


;====================================================================
;MODULOS BASICOS DE I/O (compartidos)
;====================================================================

LIMPIAR_PANTALLA PROC
PUSH AX
MOV  AH, 00H
MOV  AL, 03H
INT  10H
POP  AX
RET
LIMPIAR_PANTALLA ENDP

IMPRIMIR_CADENA PROC
PUSH AX
MOV  AH, 09H
INT  21H
POP  AX
RET
IMPRIMIR_CADENA ENDP

IMPRIMIR_CARACTER PROC
PUSH AX
MOV  AH, 02H
INT  21H
POP  AX
RET
IMPRIMIR_CARACTER ENDP

NUEVA_LINEA PROC
PUSH AX
PUSH DX
MOV  AH, 02H
MOV  DL, 0DH
INT  21H
MOV  DL, 0AH
INT  21H
POP  DX
POP  AX
RET
NUEVA_LINEA ENDP

; LEER_TECLA_DIRECTA: Lee con eco, convierte minusculas a mayusculas
LEER_TECLA_DIRECTA PROC
MOV  AH, 01H
INT  21H
CMP  AL, 'a'
JB   LTD_FIN
CMP  AL, 'z'
JA   LTD_FIN
SUB  AL, 20H
LTD_FIN:
RET
LEER_TECLA_DIRECTA ENDP

; ESPERAR_ENTER: Espera ENTER del usuario
ESPERAR_ENTER PROC
PUSH AX
EE_LOOP:
MOV  AH, 08H
INT  21H
CMP  AL, 0DH
JNE  EE_LOOP
POP  AX
RET
ESPERAR_ENTER ENDP

; IMPRIMIR_NUMERO: Imprime AX como numero decimal
IMPRIMIR_NUMERO PROC
PUSH AX
PUSH BX
PUSH CX
PUSH DX

MOV  BX, 10
MOV  CX, 0

CMP  AX, 0
JNE  IN_LOOP_DIV
MOV  DL, '0'
CALL IMPRIMIR_CARACTER
JMP  IN_FIN

IN_LOOP_DIV:
CMP  AX, 0
JE   IN_LOOP_PRINT
MOV  DX, 0
DIV  BX
PUSH DX
INC  CX
JMP  IN_LOOP_DIV

IN_LOOP_PRINT:
CMP  CX, 0
JE   IN_FIN
POP  DX
ADD  DL, '0'
CALL IMPRIMIR_CARACTER
DEC  CX
JMP  IN_LOOP_PRINT

IN_FIN:
POP  DX
POP  CX
POP  BX
POP  AX
RET
IMPRIMIR_NUMERO ENDP

END
