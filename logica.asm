;==============================================================
; PROYECTO AHORCADO - ENSAMBLADOR 8086
; Prueba v5: + CAMBIO_TURNO + IMPRIMIR_TURNO + simulacion PvP
; Compatible con EMU8086 (COM template)
;==============================================================

ORG 100H

JMP MAIN

;==============================================================
; SECCION DE DATOS
;==============================================================
    PALABRA       DB 'CASA', 16 DUP(0)
    LONG_PALABRA  DB 4
    ESTADO        DB '____', 16 DUP(0)
    ERRORES       DB 0
    LETRA_ACTUAL  DB 0
    USADAS        DB 26 DUP(0)
    TURNO         DB 1                ; 1 = J1, 2 = J2
    MODALIDAD     DB 2                ; 1 = Maq vs J, 2 = PvP (para prueba, PvP)
    
    TABLA_PUNTAJES DB 100, 100, 85, 70, 50, 30, 10
    
    PUNTAJE_ACTUAL DB 0
    PUNTAJE_J1     DW 0
    PUNTAJE_J2     DW 0
    
    ; Palabras simuladas para la prueba (en proyecto final, Persona 3 las carga)
    PAL_J1         DB 'CASA'
    LEN_J1         DB 4
    PAL_J2         DB 'PERRO'
    LEN_J2         DB 5
    
    MAX_ERRORES   EQU 6
    
    MSG_TITULO    DB 'PRUEBA - AHORCADO 8086 (modo PvP)', 0DH, 0AH, '$'
    MSG_TURNO_J1  DB 0DH, 0AH, '--- Turno del Jugador 1 ---', 0DH, 0AH, '$'
    MSG_TURNO_J2  DB 0DH, 0AH, '--- Turno del Jugador 2 ---', 0DH, 0AH, '$'
    MSG_PEDIR     DB 0DH, 0AH, 'Ingrese una letra (0 para rendirse): $'
    MSG_ESTADO    DB 0DH, 0AH, 'Palabra: $'
    MSG_ERRORES   DB '   Errores: $'
    MSG_PT_POT    DB '   Puntaje potencial: $'
    MSG_REPETIDA  DB 0DH, 0AH, 'Letra ya usada, intente otra.', 0DH, 0AH, '$'
    MSG_VICTORIA  DB 0DH, 0AH, 'GANASTE la ronda!', 0DH, 0AH, '$'
    MSG_DERROTA   DB 0DH, 0AH, 'PERDISTE la ronda!', 0DH, 0AH, '$'
    MSG_PT_RONDA  DB 'Puntaje de esta ronda: $'
    MSG_STATS     DB 0DH, 0AH, '=== ESTADISTICAS FINALES ===', 0DH, 0AH, '$'
    MSG_TOTAL_J1  DB 'Jugador 1: $'
    MSG_TOTAL_J2  DB 0DH, 0AH, 'Jugador 2: $'
    MSG_FIN       DB 0DH, 0AH, 0DH, 0AH, 'Fin de la partida.', 0DH, 0AH, '$'

;==============================================================
; PROGRAMA PRINCIPAL
;==============================================================
MAIN:
    CALL LIMPIAR_PANTALLA
    LEA  DX, MSG_TITULO
    CALL IMPRIMIR_CADENA
    
    ; --- Inicializar partida PvP ---
    MOV  TURNO, 1
    MOV  PUNTAJE_J1, 0
    MOV  PUNTAJE_J2, 0
    
RONDA:
    CALL IMPRIMIR_TURNO
    CALL CARGAR_PALABRA_SIMULADA     ; en proyecto final: CALL CARGAR_PALABRA (Persona 3)
    
LOOP_TURNO:
    CALL CALCULAR_PUNTAJE            ; actualizar puntaje potencial
    CALL MOSTRAR_ESTADO_PRUEBA
    
    LEA  DX, MSG_PEDIR
    CALL IMPRIMIR_CADENA
    CALL LEER_TECLA
    
    CMP  AL, '0'                     ; '0' = rendirse en esta prueba
    JE   PERDIO_RONDA
    
    MOV  LETRA_ACTUAL, AL
    
    CALL VALIDAR_REPETIDA
    JC   LETRA_YA_USADA
    
    CALL COMPARAR_LETRA
    
    CALL DETECTAR_VICTORIA
    JC   GANO_RONDA
    
    CALL DETECTAR_DERROTA
    JC   PERDIO_RONDA
    
    JMP  LOOP_TURNO

LETRA_YA_USADA:
    LEA  DX, MSG_REPETIDA
    CALL IMPRIMIR_CADENA
    JMP  LOOP_TURNO

GANO_RONDA:
    CALL MOSTRAR_ESTADO_PRUEBA
    LEA  DX, MSG_VICTORIA
    CALL IMPRIMIR_CADENA
    CALL CALCULAR_PUNTAJE
    CALL ACUMULAR_PUNTAJE
    
    LEA  DX, MSG_PT_RONDA
    CALL IMPRIMIR_CADENA
    CALL IMPRIMIR_PUNTAJE
    JMP  FIN_RONDA

PERDIO_RONDA:
    CALL MOSTRAR_ESTADO_PRUEBA
    LEA  DX, MSG_DERROTA
    CALL IMPRIMIR_CADENA
    CALL PUNTAJE_DERROTA
    CALL ACUMULAR_PUNTAJE
    
    LEA  DX, MSG_PT_RONDA
    CALL IMPRIMIR_CADENA
    CALL IMPRIMIR_PUNTAJE

FIN_RONDA:
    ; Si ya jugaron ambos, mostrar estadisticas
    CMP  TURNO, 2
    JE   FIN_PARTIDA
    
    ; Sino, cambiar turno y empezar nueva ronda
    CALL CAMBIO_TURNO
    JMP  RONDA

FIN_PARTIDA:
    ; --- Mostrar estadisticas finales ---
    LEA  DX, MSG_STATS
    CALL IMPRIMIR_CADENA
    
    LEA  DX, MSG_TOTAL_J1
    CALL IMPRIMIR_CADENA
    MOV  AX, PUNTAJE_J1
    CALL IMPRIMIR_NUMERO
    
    LEA  DX, MSG_TOTAL_J2
    CALL IMPRIMIR_CADENA
    MOV  AX, PUNTAJE_J2
    CALL IMPRIMIR_NUMERO
    
    LEA  DX, MSG_FIN
    CALL IMPRIMIR_CADENA
    MOV  AH, 4CH
    INT  21H


;==============================================================
; RUTINA DE PRUEBA: muestra ESTADO + ERRORES + PUNTAJE_ACTUAL
;==============================================================
MOSTRAR_ESTADO_PRUEBA PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    
    LEA  DX, MSG_ESTADO
    CALL IMPRIMIR_CADENA
    
    XOR  SI, SI
    MOV  CL, LONG_PALABRA
    MOV  CH, 0
ME_LOOP:
    MOV  DL, ESTADO[SI]
    CALL IMPRIMIR_CARACTER
    MOV  DL, ' '
    CALL IMPRIMIR_CARACTER
    INC  SI
    LOOP ME_LOOP
    
    LEA  DX, MSG_ERRORES
    CALL IMPRIMIR_CADENA
    MOV  DL, ERRORES
    ADD  DL, '0'
    CALL IMPRIMIR_CARACTER
    
    LEA  DX, MSG_PT_POT
    CALL IMPRIMIR_CADENA
    CALL IMPRIMIR_PUNTAJE
    
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
MOSTRAR_ESTADO_PRUEBA ENDP


;==============================================================
; SIMULACION: CARGAR_PALABRA (lo hara Persona 3 en proyecto final)
;==============================================================
CARGAR_PALABRA_SIMULADA PROC
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI
    PUSH ES
    
    PUSH DS
    POP  ES
    
    ; Elegir palabra segun TURNO (en proyecto final, segun DIFICULTAD)
    CMP  TURNO, 1
    JNE  SIM_J2
    
    LEA  SI, PAL_J1
    MOV  CL, LEN_J1
    JMP  SIM_COPIAR
    
SIM_J2:
    LEA  SI, PAL_J2
    MOV  CL, LEN_J2
    
SIM_COPIAR:
    MOV  CH, 0
    MOV  AL, CL              ; guardar longitud
    MOV  LONG_PALABRA, AL
    LEA  DI, PALABRA
    REP  MOVSB               ; copiar PALx -> PALABRA
    
    ; Resetear ESTADO con guiones segun LONG_PALABRA
    CALL REINICIAR_ESTADO
    
    ; Resetear errores y usadas (Persona 3 hara esto tambien)
    MOV  ERRORES, 0
    CALL REINICIAR_USADAS
    
    POP  ES
    POP  DI
    POP  SI
    POP  CX
    POP  AX
    RET
CARGAR_PALABRA_SIMULADA ENDP


;==============================================================
; MODULOS BASICOS DE I/O
;==============================================================

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


LEER_TECLA PROC
    MOV  AH, 01H
    INT  21H
    CMP  AL, 'a'
    JB   LEER_FIN
    CMP  AL, 'z'
    JA   LEER_FIN
    SUB  AL, 20H
LEER_FIN:
    RET
LEER_TECLA ENDP


;==============================================================
; MODULO: COMPARAR_LETRA
;==============================================================
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


;==============================================================
; MODULO: VALIDAR_REPETIDA
;==============================================================
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


;==============================================================
; MODULO: REINICIAR_USADAS
;==============================================================
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


;==============================================================
; MODULO: REINICIAR_ESTADO
; Llena ESTADO con '_' segun LONG_PALABRA
;==============================================================
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


;==============================================================
; MODULO: DETECTAR_VICTORIA
;==============================================================
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


;==============================================================
; MODULO: DETECTAR_DERROTA
;==============================================================
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


;==============================================================
; MODULO: CALCULAR_PUNTAJE
;==============================================================
CALCULAR_PUNTAJE PROC
    PUSH BX
    
    MOV  BL, ERRORES
    MOV  BH, 0
    
    MOV  AL, TABLA_PUNTAJES[BX]
    MOV  PUNTAJE_ACTUAL, AL
    
    POP  BX
    RET
CALCULAR_PUNTAJE ENDP


;==============================================================
; MODULO: PUNTAJE_DERROTA
;==============================================================
PUNTAJE_DERROTA PROC
    MOV  PUNTAJE_ACTUAL, 0
    RET
PUNTAJE_DERROTA ENDP


;==============================================================
; MODULO: ACUMULAR_PUNTAJE
;==============================================================
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


;==============================================================
; MODULO: IMPRIMIR_PUNTAJE
; Imprime PUNTAJE_ACTUAL como decimal
;==============================================================
IMPRIMIR_PUNTAJE PROC
    PUSH AX
    
    MOV  AL, PUNTAJE_ACTUAL
    MOV  AH, 0
    CALL IMPRIMIR_NUMERO
    
    POP  AX
    RET
IMPRIMIR_PUNTAJE ENDP


;==============================================================
; MODULO: IMPRIMIR_NUMERO
; Imprime AX como decimal (sirve tanto para PUNTAJE_ACTUAL como J1/J2)
; Entrada: AX = numero a imprimir (0-65535)
;==============================================================
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


;==============================================================
; MODULO: CAMBIO_TURNO
; Alterna TURNO entre 1 y 2 y resetea variables del nuevo turno
;==============================================================
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


;==============================================================
; MODULO: IMPRIMIR_TURNO
; Muestra "Turno del Jugador X" segun TURNO
;==============================================================
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

END