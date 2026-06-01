;====================================================================
; PROYECTO: AHORCADO - Ensamblador 8086 
; Version: Integrada PERSONA 2 + PERSONA 3
;====================================================================

ORG 100H                    ; Inicio de archivo .COM
JMP MAIN                    ; Saltar por encima de los datos

;====================================================================
; SECCION DE DATOS 
;====================================================================

;Variables de Persona 2
PALABRA       DB 20 DUP(0)      ; Palabra actual/secreta (20 bytes max)
LONG_PALABRA  DB 0              ; Longitud de la palabra
ESTADO        DB 20 DUP('_')    ; Estado mostrado (_ = no adivinada)
ERRORES       DB 0              ; Errores cometidos en este turno
LETRA_ACTUAL  DB 0              ; Ultima letra ingresada
USADAS        DB 26 DUP(0)      ; Letras ya usadas (A=pos0, B=pos1...)
TURNO         DB 1              ; 1=Jugador 1, 2=Jugador 2
MODALIDAD     DB 1              ; 1=Maquina vs Jugador, 2=Jugador vs Jugador

TABLA_PUNTAJES DB 100, 100, 85, 70, 50, 30, 10  ; Puntaje segun errores

PUNTAJE_ACTUAL DB 0
PUNTAJE_J1     DW 0
PUNTAJE_J2     DW 0

MAX_ERRORES   EQU 6             ; Maximo de errores permitidos

;Variables de Persona 3 (archivos + aleatoriedad)
DIFICULTAD    DB 1              ; 1=facil, 2=medio, 3=dificil
BUFFER_ARCH   DB 2000 DUP(0)    ; Buffer para leer archivo completo
BYTES_LEIDOS  DW 0              ; Bytes leidos del archivo
CONT_PALABRAS DB 0              ; Cuantas palabras hay en el archivo
INDICE_SEL    DB 0              ; Indice de palabra elegida al azar
FILE_HANDLE   DW 0              ; Handle del archivo abierto

;Nombres de archivo (formato ASCII)
ARCH_FACIL    DB 'facil.txt', 0
ARCH_MEDIO    DB 'medio.txt', 0
ARCH_DIFICIL  DB 'dificil.txt', 0

;Palabra de respaldo (si falla el archivo)
PAL_DEFAULT   DB 'PRUEBA'
LEN_DEFAULT   DB 6

;Mensajes de Persona 2
MSG_TITULO    DB 'AHORCADO 8086', 0DH, 0AH, '$'
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

;Configuracion + PvP
MSG_MODO      DB 'Modo de juego:', 0DH, 0AH
              DB '1. Maquina vs Jugador', 0DH, 0AH
              DB '2. Jugador vs Jugador', 0DH, 0AH
              DB 'Opcion: $'
MSG_DIFIC     DB 0DH, 0AH, 'Dificultad (1=Facil, 2=Medio, 3=Dificil): $'

MSG_PVP_J1    DB 0DH, 0AH
              DB 'Jugador 1, ingrese la palabra secreta', 0DH, 0AH
              DB '(Que el Jugador 2 NO mire): ', 0DH, 0AH, '$'
MSG_PVP_J2    DB 0DH, 0AH
              DB 'Jugador 2, ingrese la palabra secreta', 0DH, 0AH
              DB '(Que el Jugador 1 NO mire): ', 0DH, 0AH, '$'
MSG_OCULTA    DB 0DH, 0AH, 'Palabra (oculta): $'
MSG_CAMBIAR   DB 0DH, 0AH
              DB '>>> PASE EL TECLADO AL OTRO JUGADOR <<<', 0DH, 0AH
              DB 'Presione ENTER para continuar...$'

MSG_ERROR_ARCH DB 0DH, 0AH, '*** ERROR: Archivo no encontrado ***', 0DH, 0AH, '$'
MSG_USA_DEF   DB '(Usando palabra por defecto)', 0DH, 0AH, '$'


;====================================================================
;                    PROGRAMA PRINCIPAL                             
;====================================================================

MAIN:
    CALL LIMPIAR_PANTALLA       

    ;Mostrar titulo
    LEA  DX, MSG_TITULO
    CALL IMPRIMIR_CADENA

    ;SELECCION DE MODO DE JUEGO
    LEA  DX, MSG_MODO           ; "Modo de juego: 1. Maq vs J  2. PvP"
    CALL IMPRIMIR_CADENA
    CALL LEER_TECLA              ; Leer opcion del usuario
    CMP  AL, '2'                ; Eligio PvP?
    JE   CONFIG_PVP              ; Si, configurar PvP
    MOV  [MODALIDAD], 1          ; No, es Maquina vs Jugador

    ;SELECCION DE DIFICULTAD (solo modo Maquina)
    LEA  DX, MSG_DIFIC          ; "Dificultad (1=Facil, 2=Medio, 3=Dificil):"
    CALL IMPRIMIR_CADENA
    CALL LEER_TECLA              ; Leer dificultad
    SUB  AL, '0'                ; Convertir ASCII a numero
    MOV  [DIFICULTAD], AL        ; Guardar dificultad (1, 2 o 3)
    JMP  CONFIG_LISTO

CONFIG_PVP:
    MOV  [MODALIDAD], 2          ; Guardar modo PvP

CONFIG_LISTO:
    ;Inicializar partida
    MOV  TURNO, 1
    MOV  PUNTAJE_J1, 0
    MOV  PUNTAJE_J2, 0

RONDA:
    CALL IMPRIMIR_TURNO
    CALL CARGAR_PALABRA          ; Se carga la palabra

LOOP_TURNO:
    CALL CALCULAR_PUNTAJE        ; actualizar puntaje potencial
    CALL MOSTRAR_ESTADO_PRUEBA

    LEA  DX, MSG_PEDIR
    CALL IMPRIMIR_CADENA
    CALL LEER_TECLA

    CMP  AL, '0'                 ; '0' = rendirse
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
    ;Mostrar estadisticas finales
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

;--------------------------------------------------------------------
; MOSTRAR_ESTADO_PRUEBA - Muestra ESTADO + ERRORES + PUNTAJE
;--------------------------------------------------------------------
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


;====================================================================
;     PROCEDIMIENTOS DE I/O             
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


;====================================================================
;     MODULO: COMPARAR_LETRA      
;====================================================================

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

CALCULAR_PUNTAJE PROC
    PUSH BX

    MOV  BL, ERRORES
    MOV  BH, 0

    MOV  AL, TABLA_PUNTAJES[BX]
    MOV  PUNTAJE_ACTUAL, AL

    POP  BX
    RET
CALCULAR_PUNTAJE ENDP

PUNTAJE_DERROTA PROC
    MOV  PUNTAJE_ACTUAL, 0
    RET
PUNTAJE_DERROTA ENDP

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

IMPRIMIR_PUNTAJE PROC
    PUSH AX

    MOV  AL, PUNTAJE_ACTUAL
    MOV  AH, 0
    CALL IMPRIMIR_NUMERO

    POP  AX
    RET
IMPRIMIR_PUNTAJE ENDP

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



;====================================================================
; CARGAR_PALABRA - Carga la palabra segun MODALIDAD
;   MODALIDAD=1: elige palabra aleatoria desde archivo .txt
;   MODALIDAD=2: lee palabra oculta del teclado (modo PvP)
;   Si no se carga nada, usa 'PRUEBA' como respaldo.
;   Resetea ESTADO, ERRORES y USADAS al finalizar.
;====================================================================
CARGAR_PALABRA PROC
    CMP  [MODALIDAD], 2
    JE   CP_PVP

    CALL CARGAR_PALABRA_ARCHIVO
    JMP  CP_VERIFICAR

CP_PVP:
    CALL LEER_PALABRA_OCULTA

CP_VERIFICAR:
    ;Proteccion: LONG_PALABRA=0 causaria loops infinitos en Persona 2
    CMP  [LONG_PALABRA], 0
    JNE  CP_RESETEAR

    PUSH DS
    POP  ES
    MOV  [LONG_PALABRA], 6
    LEA  SI, PAL_DEFAULT
    LEA  DI, PALABRA
    MOV  CX, 6
    REP  MOVSB

CP_RESETEAR:
    CALL REINICIAR_ESTADO
    MOV  [ERRORES], 0
    CALL REINICIAR_USADAS
    RET
CARGAR_PALABRA ENDP


;====================================================================
; CARGAR_PALABRA_ARCHIVO - Carga palabra aleatoria desde archivo .txt
;   1. Abre el archivo segun DIFICULTAD (facil/medio/dificil.txt)
;   2. Cuenta palabras, elige indice aleatorio, extrae la elegida
;   Si falla (archivo no existe, vacio), usa 'PRUEBA' como respaldo.
;====================================================================
CARGAR_PALABRA_ARCHIVO PROC
    PUSH AX
    PUSH CX
    PUSH DX

    CALL ABRIR_ARCHIVO
    JC   CPA_ERROR

    CALL CONTAR_PALABRAS

    CMP  [CONT_PALABRAS], 0
    JE   CPA_ERROR

    CALL GENERAR_ALEATORIO

    CALL EXTRAER_PALABRA

    CMP  [LONG_PALABRA], 0
    JNE  CPA_FIN

CPA_ERROR:
    LEA  DX, MSG_ERROR_ARCH
    CALL IMPRIMIR_CADENA
    LEA  DX, MSG_USA_DEF
    CALL IMPRIMIR_CADENA

    PUSH DS
    POP  ES
    MOV  CL, [LEN_DEFAULT]
    MOV  [LONG_PALABRA], CL
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


;====================================================================
; ABRIR_ARCHIVO - Abre el .txt segun DIFICULTAD y lo lee completo
;   Segun DIFICULTAD (1,2,3) selecciona facil/medio/dificil.txt.
;   Lee hasta 2000 bytes en BUFFER_ARCH, guarda total en BYTES_LEIDOS.
;   Interrupciones: INT 21h (3Dh=abrir, 3Fh=leer, 3Eh=cerrar)
;   Retorna: CF=0 exito, CF=1 error
;====================================================================
ABRIR_ARCHIVO PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    MOV  AL, [DIFICULTAD]
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

    MOV  [FILE_HANDLE], AX

    MOV  AH, 3FH
    MOV  BX, [FILE_HANDLE]
    LEA  DX, BUFFER_ARCH
    MOV  CX, 2000
    INT  21H
    JC   AA_ERROR_CERRAR

    MOV  [BYTES_LEIDOS], AX

    MOV  AH, 3EH
    MOV  BX, [FILE_HANDLE]
    INT  21H

    CLC
    JMP  AA_FIN

AA_ERROR_CERRAR:
    MOV  AH, 3EH
    MOV  BX, [FILE_HANDLE]
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


;====================================================================
; CONTAR_PALABRAS - Cuenta palabras en BUFFER_ARCH
;   Recorre el buffer byte a byte. Cada grupo de caracteres que
;   NO es CR (0Dh) ni LF (0Ah) cuenta como una palabra.
;   Resultado en CONT_PALABRAS.
;====================================================================
CONTAR_PALABRAS PROC
    PUSH AX
    PUSH CX
    PUSH SI

    LEA  SI, BUFFER_ARCH
    MOV  CX, [BYTES_LEIDOS]
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
    MOV  [CONT_PALABRAS], AL

    POP  SI
    POP  CX
    POP  AX
    RET
CONTAR_PALABRAS ENDP


;====================================================================
; EXTRAER_PALABRA - Copia la palabra INDICE_SEL del buffer a PALABRA
;   Recorre BUFFER_ARCH contando palabras. Al llegar al indice
;   buscado, copia sus letras a PALABRA y guarda long en LONG_PALABRA.
;   Maximo 20 caracteres por palabra.
;====================================================================
EXTRAER_PALABRA PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI

    LEA  SI, BUFFER_ARCH
    MOV  CX, [BYTES_LEIDOS]
    XOR  BL, BL
    LEA  DI, PALABRA
    MOV  [LONG_PALABRA], 0

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

    CMP  BL, [INDICE_SEL]
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

    CMP  [LONG_PALABRA], 20
    JAE  EP_FIN

    MOV  [DI], AL
    INC  DI
    INC  [LONG_PALABRA]
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


;====================================================================
; GENERAR_ALEATORIO - Selecciona un indice al azar
;   Usa el reloj del sistema (INT 21h/AH=2Ch) para obtener
;   centesimas de segundo (0-99) y calcula modulo CONT_PALABRAS.
;   INDICE_SEL queda entre 0 y (CONT_PALABRAS - 1).
;====================================================================
GENERAR_ALEATORIO PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    CMP  [CONT_PALABRAS], 0
    JE   GA_CERO

    MOV  AH, 2CH
    INT  21H

    MOV  AL, DL
    MOV  AH, 0

    MOV  BL, [CONT_PALABRAS]
    DIV  BL
    MOV  [INDICE_SEL], AH
    JMP  GA_FIN

GA_CERO:
    MOV  [INDICE_SEL], 0

GA_FIN:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
GENERAR_ALEATORIO ENDP


;====================================================================
; LEER_PALABRA_OCULTA - Entrada con asteriscos para modo PvP
;   Muestra '*' por cada letra para ocultar la palabra al rival.
;   Segun TURNO, pide la palabra al jugador que NO esta adivinando.
;   Soporta Backspace, convierte a mayusculas, solo acepta A-Z,
;   maximo 20 letras. Al terminar limpia la pantalla.
;   INT 21h: AH=08h (leer sin eco), AH=02h (mostrar '*')
;====================================================================
LEER_PALABRA_OCULTA PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    ;El que NO adivina ingresa la palabra
    CMP  [TURNO], 1
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

    CMP  AL, 0DH                  ; ENTER = terminar
    JE   LO_FIN

    CMP  AL, 08H                  ; BACKSPACE = borrar
    JE   LO_BORRAR

    CMP  AL, 'a'
    JB   LO_FILTRAR
    CMP  AL, 'z'
    JA   LO_FILTRAR
    SUB  AL, 20H                  ; a-z -> A-Z

LO_FILTRAR:
    CMP  AL, 'A'
    JB   LO_LEER
    CMP  AL, 'Z'
    JA   LO_LEER

    CMP  BL, 20                   ; Maximo 20 letras
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

    MOV  AH, 02H                  ; Borrar visualmente: BS + espacio + BS
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
    MOV  [LONG_PALABRA], BL

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
END
