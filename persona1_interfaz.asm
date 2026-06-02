;====================================================================
; PROYECTO: AHORCADO - Ensamblador 8086
; PERSONA 1 - INTERFAZ + ENTRADA DE USUARIO
;
; Responsabilidades:
;   - Pantalla inicial (nickname, modalidad, dificultad)
;   - Mostrar el juego en pantalla (palabra, intentos, puntaje, letras usadas)
;   - Opciones en juego: [R] Rendirse, [X] Reset, [S] Salir
;   - Mostrar estadisticas finales con ganador
;   - Validaciones de entrada (nickname 3-10 chars, opciones validas)
;
; Interrupciones usadas:
;   INT 10h  -> BIOS (limpiar pantalla, posicionar cursor)
;   INT 21h  -> DOS  (imprimir cadena, leer teclado, caracter)
;   INT 16h  -> BIOS teclado (lectura directa sin eco para validar)
;====================================================================

ORG 100H
JMP MAIN

;====================================================================
; SECCION DE DATOS - PERSONA 1
;====================================================================

; ---- Variables GLOBALES compartidas ----
PALABRA        DB 20 DUP(0)
LONG_PALABRA   DB 0
ESTADO         DB 20 DUP('_')
ERRORES        DB 0
USADAS         DB 26 DUP(0)
TURNO          DB 1
MODALIDAD      DB 1
DIFICULTAD     DB 1
PUNTAJE_ACTUAL DB 0
PUNTAJE_J1     DW 0
PUNTAJE_J2     DW 0
MAX_ERRORES    EQU 6

; ---- Variables LOCALES de Persona 1 ----
NICK_J1        DB 11 DUP(0)
NICK_J2        DB 11 DUP(0)
LEN_NICK_J1    DB 0
LEN_NICK_J2    DB 0
LETRA_ACTUAL   DB 0

; ---- Mensajes de pantalla inicial ----
MSG_BIENVENIDA DB '+----------------------------------+', 0DH, 0AH
               DB '|       AHORCADO  8086           |', 0DH, 0AH
               DB '+----------------------------------+', 0DH, 0AH, '$'

MSG_PEDIR_NICK1 DB 0DH, 0AH
                DB 'Nickname Jugador 1 (3-10 letras): $'
MSG_PEDIR_NICK2 DB 0DH, 0AH
                DB 'Nickname Jugador 2 (3-10 letras): $'

MSG_ERR_NICK   DB 0DH, 0AH
               DB '! Nickname invalido. Debe tener entre 3 y 10 caracteres.', 0DH, 0AH, '$'

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

; ---- Mensajes en juego ----
MSG_MARCO_TOP  DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_MARCO_MID  DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_MARCO_BOT  DB '+----------------------------------+', 0DH, 0AH, '$'
MSG_BORDE_IZQ  DB '| $'
MSG_BORDE_DER  DB ' |', 0DH, 0AH, '$'

MSG_JUGADOR    DB '| Jugador: $'
MSG_INTENTOS   DB '| Intentos restantes: $'
MSG_PUNTAJE_L  DB '| Puntaje: $'
MSG_PALABRA_L  DB '| Palabra: $'
MSG_USADAS_L   DB '| Letras usadas: $'
MSG_OPCIONES   DB '+----------------------------------+', 0DH, 0AH
               DB '| [R] Rendirse                   |', 0DH, 0AH
               DB '| [X] Reset                      |', 0DH, 0AH
               DB '| [S] Salir                      |', 0DH, 0AH
               DB '+----------------------------------+', 0DH, 0AH, '$'

MSG_PEDIR_LETRA DB 0DH, 0AH, 'Ingrese una letra: $'
MSG_LETRA_REP   DB 0DH, 0AH, '! La letra ya fue usada. Intente otra.', 0DH, 0AH, '$'
MSG_INV_LETRA   DB 0DH, 0AH, '! Entrada invalida.', 0DH, 0AH, '$'

; ---- Mensajes de resultado de ronda ----
MSG_GANASTE    DB 0DH, 0AH
               DB '+----------------------------------+', 0DH, 0AH
               DB '|         !GANASTE!              |', 0DH, 0AH
               DB '+----------------------------------+', 0DH, 0AH, '$'

MSG_PERDISTE   DB 0DH, 0AH
               DB '+----------------------------------+', 0DH, 0AH
               DB '|         !PERDISTE!             |', 0DH, 0AH
               DB '|      Intentos agotados         |', 0DH, 0AH
               DB '+----------------------------------+', 0DH, 0AH, '$'

MSG_PT_RONDA   DB '  Puntaje de esta ronda: $'

; ---- Mensajes de estadisticas finales ----
MSG_STATS_TOP  DB 0DH, 0AH
               DB '+----------------------------------+', 0DH, 0AH
               DB '|        ESTADISTICAS            |', 0DH, 0AH
               DB '+----------------------------------+', 0DH, 0AH, '$'

MSG_GANADOR    DB '| Ganador: $'
MSG_EMPATE     DB '| EMPATE!                        |', 0DH, 0AH, '$'
MSG_FLECHA     DB ' -> $'
MSG_PTS_STR    DB ' pts                            |', 0DH, 0AH, '$'
MSG_FIN        DB '+----------------------------------+', 0DH, 0AH
               DB 0DH, 0AH, 'Fin de la partida.', 0DH, 0AH, '$'

; ---- Mensajes de acciones especiales ----
MSG_CONFIRMAR_SALIR DB 0DH, 0AH
                    DB 'Seguro que desea salir? (S/N): $'
MSG_CONFIRMAR_RESET DB 0DH, 0AH
                    DB 'Seguro que desea reiniciar? (S/N): $'
MSG_SE_RINDIO  DB 0DH, 0AH, 'Te rendiste. La palabra era: $'

; ---- Separadores y espacios ----
MSG_ESPACIO    DB ' $'
MSG_NEWLINE    DB 0DH, 0AH, '$'
MSG_ENTER_CONT DB 0DH, 0AH, 'Presione ENTER para continuar...$'

; ---- Flag de accion especial ----
ACCION_ESPECIAL DB 0


;====================================================================
;                    PROGRAMA PRINCIPAL
;====================================================================
MAIN:
    CALL LIMPIAR_PANTALLA
    CALL PANTALLA_INICIAL
    CALL MOSTRAR_JUEGO
    CALL MOSTRAR_ESTADISTICAS
    MOV  AH, 4CH
    INT  21H


;====================================================================
; PANTALLA_INICIAL
;====================================================================
PANTALLA_INICIAL PROC
    PUSH AX
    PUSH DX

    CALL LIMPIAR_PANTALLA

    LEA  DX, MSG_BIENVENIDA
    CALL IMPRIMIR_CADENA

PI_NICK1:
    LEA  DX, MSG_PEDIR_NICK1
    CALL IMPRIMIR_CADENA
    LEA  DX, NICK_J1
    CALL LEER_NICKNAME
    CALL VALIDAR_NICKNAME
    JNC  PI_NICK1_OK
    LEA  DX, MSG_ERR_NICK
    CALL IMPRIMIR_CADENA
    JMP  PI_NICK1
PI_NICK1_OK:
    MOV  LEN_NICK_J1, AL

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
    JMP  PI_FIN

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


;====================================================================
; MOSTRAR_JUEGO
;====================================================================
MOSTRAR_JUEGO PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL LIMPIAR_PANTALLA

    LEA  DX, MSG_MARCO_TOP
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_JUGADOR
    CALL IMPRIMIR_CADENA
    CALL IMPRIMIR_NICK_ACTIVO
    LEA  DX, MSG_BORDE_DER
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_INTENTOS
    CALL IMPRIMIR_CADENA
    MOV  AL, MAX_ERRORES
    SUB  AL, ERRORES
    MOV  DL, AL
    ADD  DL, '0'
    CALL IMPRIMIR_CARACTER
    LEA  DX, MSG_BORDE_DER
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_PUNTAJE_L
    CALL IMPRIMIR_CADENA
    MOV  AL, PUNTAJE_ACTUAL
    MOV  AH, 0
    CALL IMPRIMIR_NUMERO
    LEA  DX, MSG_BORDE_DER
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_MARCO_MID
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_PALABRA_L
    CALL IMPRIMIR_CADENA
    CALL IMPRIMIR_ESTADO_PALABRA
    LEA  DX, MSG_BORDE_DER
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_MARCO_MID
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_USADAS_L
    CALL IMPRIMIR_CADENA
    CALL IMPRIMIR_LETRAS_USADAS
    LEA  DX, MSG_BORDE_DER
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_OPCIONES
    CALL IMPRIMIR_CADENA

    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
MOSTRAR_JUEGO ENDP


;====================================================================
; LEER_INPUT_JUGADOR
;====================================================================
LEER_INPUT_JUGADOR PROC
    PUSH DX

    MOV  ACCION_ESPECIAL, 0

    LEA  DX, MSG_PEDIR_LETRA
    CALL IMPRIMIR_CADENA

LIJ_LEER:
    CALL LEER_TECLA_DIRECTA

    CMP  AL, 'R'
    JE   LIJ_RENDIRSE
    CMP  AL, 'X'
    JE   LIJ_RESET
    CMP  AL, 'S'
    JE   LIJ_SALIR

    CMP  AL, 'A'
    JB   LIJ_INVALIDA
    CMP  AL, 'Z'
    JA   LIJ_INVALIDA

    MOV  LETRA_ACTUAL, AL
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


;====================================================================
; MOSTRAR_VICTORIA
;====================================================================
MOSTRAR_VICTORIA PROC
    PUSH AX
    PUSH DX

    LEA  DX, MSG_GANASTE
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_PT_RONDA
    CALL IMPRIMIR_CADENA
    MOV  AL, PUNTAJE_ACTUAL
    MOV  AH, 0
    CALL IMPRIMIR_NUMERO

    CALL NUEVA_LINEA
    LEA  DX, MSG_ENTER_CONT
    CALL IMPRIMIR_CADENA
    CALL ESPERAR_ENTER

    POP  DX
    POP  AX
    RET
MOSTRAR_VICTORIA ENDP


;====================================================================
; MOSTRAR_DERROTA
;====================================================================
MOSTRAR_DERROTA PROC
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI

    LEA  DX, MSG_PERDISTE
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_SE_RINDIO
    CALL IMPRIMIR_CADENA
    XOR  SI, SI
    MOV  CL, LONG_PALABRA
    MOV  CH, 0
MD_LOOP:
    MOV  DL, PALABRA[SI]
    CALL IMPRIMIR_CARACTER
    INC  SI
    LOOP MD_LOOP

    CALL NUEVA_LINEA
    LEA  DX, MSG_ENTER_CONT
    CALL IMPRIMIR_CADENA
    CALL ESPERAR_ENTER

    POP  SI
    POP  DX
    POP  CX
    POP  AX
    RET
MOSTRAR_DERROTA ENDP


;====================================================================
; MOSTRAR_RENDICION
;====================================================================
MOSTRAR_RENDICION PROC
    PUSH CX
    PUSH DX
    PUSH SI

    LEA  DX, MSG_SE_RINDIO
    CALL IMPRIMIR_CADENA

    XOR  SI, SI
    MOV  CL, LONG_PALABRA
    MOV  CH, 0
MR_LOOP:
    MOV  DL, PALABRA[SI]
    CALL IMPRIMIR_CARACTER
    INC  SI
    LOOP MR_LOOP

    CALL NUEVA_LINEA
    LEA  DX, MSG_ENTER_CONT
    CALL IMPRIMIR_CADENA
    CALL ESPERAR_ENTER

    POP  SI
    POP  DX
    POP  CX
    RET
MOSTRAR_RENDICION ENDP


;====================================================================
; MOSTRAR_ESTADISTICAS
;====================================================================
MOSTRAR_ESTADISTICAS PROC
    PUSH AX
    PUSH DX

    CALL LIMPIAR_PANTALLA

    LEA  DX, MSG_STATS_TOP
    CALL IMPRIMIR_CADENA

    LEA  DX, MSG_BORDE_IZQ
    CALL IMPRIMIR_CADENA
    LEA  DX, NICK_J1
    CALL IMPRIMIR_NICK_RAW
    LEA  DX, MSG_FLECHA
    CALL IMPRIMIR_CADENA
    MOV  AX, PUNTAJE_J1
    CALL IMPRIMIR_NUMERO
    LEA  DX, MSG_PTS_STR
    CALL IMPRIMIR_CADENA

    CMP  MODALIDAD, 2
    JNE  ME_SIN_J2

    LEA  DX, MSG_BORDE_IZQ
    CALL IMPRIMIR_CADENA
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

    CMP  MODALIDAD, 2
    JNE  ME_GANADOR_SOLO

    MOV  AX, PUNTAJE_J1
    CMP  AX, PUNTAJE_J2
    JA   ME_GANA_J1
    JB   ME_GANA_J2

    LEA  DX, MSG_EMPATE
    CALL IMPRIMIR_CADENA
    JMP  ME_CIERRE

ME_GANA_J1:
ME_GANADOR_SOLO:
    LEA  DX, MSG_GANADOR
    CALL IMPRIMIR_CADENA
    LEA  DX, NICK_J1
    CALL IMPRIMIR_NICK_RAW
    LEA  DX, MSG_BORDE_DER
    CALL IMPRIMIR_CADENA
    JMP  ME_CIERRE

ME_GANA_J2:
    LEA  DX, MSG_GANADOR
    CALL IMPRIMIR_CADENA
    LEA  DX, NICK_J2
    CALL IMPRIMIR_NICK_RAW
    LEA  DX, MSG_BORDE_DER
    CALL IMPRIMIR_CADENA

ME_CIERRE:
    LEA  DX, MSG_FIN
    CALL IMPRIMIR_CADENA

    POP  DX
    POP  AX
    RET
MOSTRAR_ESTADISTICAS ENDP


;====================================================================
; CONFIRMAR_RENDIRSE / CONFIRMAR_RESET / CONFIRMAR_SALIR
;====================================================================
CONFIRMAR_RENDIRSE PROC
    PUSH DX
    LEA  DX, MSG_CONFIRMAR_SALIR
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


;====================================================================
; IMPRIMIR_NICK_ACTIVO
;====================================================================
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


;====================================================================
; IMPRIMIR_NICK_RAW
;====================================================================
IMPRIMIR_NICK_RAW PROC
    PUSH AX
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
    POP  AX
    RET
IMPRIMIR_NICK_RAW ENDP


;====================================================================
; IMPRIMIR_ESTADO_PALABRA
;====================================================================
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


;====================================================================
; IMPRIMIR_LETRAS_USADAS
;====================================================================
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


;====================================================================
; LEER_NICKNAME
;====================================================================
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


;====================================================================
; VALIDAR_NICKNAME
;====================================================================
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


;====================================================================
; MODULOS BASICOS DE I/O
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

LEER_TECLA_DIRECTA PROC
    MOV  AH, 08H
    INT  21H
    CMP  AL, 'a'
    JB   LTD_FIN
    CMP  AL, 'z'
    JA   LTD_FIN
    SUB  AL, 20H
LTD_FIN:
    RET
LEER_TECLA_DIRECTA ENDP

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