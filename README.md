# Modulo de Logica Principal - Proyecto Ahorcado 8086

## 1. Introduccion

Este documento describe el modulo de logica principal del juego del Ahorcado desarrollado en ensamblador 8086, asi como las instrucciones para integrarlo con los modulos de interfaz (Persona 1) y de archivos (Persona 3).

El modulo cubre las siguientes responsabilidades definidas en la division del proyecto:

- Comparacion de letras contra la palabra secreta
- Validacion de letras repetidas
- Sistema de intentos (maximo 6 errores)
- Deteccion de victoria y derrota
- Sistema de puntuacion basado en la tabla del enunciado
- Cambio de turnos para la modalidad Jugador vs Jugador

Todas las rutinas siguen las convenciones del 8086 en modo real, usan unicamente interrupciones DOS (INT 21h) y BIOS (INT 10h), y son compatibles con EMU8086, MASM y TASM.


## 2. Variables globales compartidas

Estas son las variables que el modulo lee o escribe. Algunas las inicializa Persona 1 desde el menu principal, otras Persona 3 al cargar la palabra, y otras se mantienen actualizadas durante el juego.

### 2.1 Variables del juego

```
PALABRA       DB 'CASA', 16 DUP(0)    ; palabra secreta (max 20 chars)
LONG_PALABRA  DB 4                    ; longitud real de la palabra
ESTADO        DB '____', 16 DUP(0)    ; lo que ve el jugador con guiones
ERRORES       DB 0                    ; intentos fallidos (0-6)
LETRA_ACTUAL  DB 0                    ; letra que se esta evaluando
USADAS        DB 26 DUP(0)            ; 0=no usada, 1=ya usada (A=0, Z=25)
TURNO         DB 1                    ; 1 = J1, 2 = J2
MODALIDAD     DB 1                    ; 1 = Maq vs J, 2 = PvP
```

### 2.2 Variables de puntaje

```
TABLA_PUNTAJES DB 100, 100, 85, 70, 50, 30, 10  ; indexada por ERRORES
PUNTAJE_ACTUAL DB 0                              ; del turno en curso
PUNTAJE_J1     DW 0                              ; acumulado del J1
PUNTAJE_J2     DW 0                              ; acumulado del J2

MAX_ERRORES    EQU 6                             ; limite de intentos
```

Una observacion importante: PUNTAJE_ACTUAL es un byte (DB) porque solo guarda 0-100, pero PUNTAJE_J1 y PUNTAJE_J2 son words (DW) porque acumulan varias rondas y pueden pasar de 255.


## 3. Modulos de logica

### 3.1 COMPARAR_LETRA

Es el corazon del juego. Recibe la letra que el jugador escribio (ya guardada en LETRA_ACTUAL), la busca en la palabra secreta y por cada coincidencia revela esa posicion en el arreglo ESTADO. Si no encuentra ninguna coincidencia, incrementa el contador de errores.

Por ejemplo, si la palabra es CASA, ESTADO es '____' y la letra es 'A', despues de llamar a este PROC, ESTADO queda '_A_A'.

```
COMPARAR_LETRA PROC
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DX
    
    XOR  SI, SI              ; indice = 0
    XOR  BX, BX              ; contador de aciertos = 0
    MOV  CL, LONG_PALABRA    ; CL = longitud para el LOOP
    MOV  CH, 0               ; limpiar parte alta de CX
    MOV  AL, LETRA_ACTUAL    ; AL = letra a buscar
    
COMP_LOOP:
    CMP  PALABRA[SI], AL     ; coincide?
    JNE  COMP_NO_MATCH
    MOV  ESTADO[SI], AL      ; revelar letra en ESTADO
    INC  BX                  ; sumar acierto
COMP_NO_MATCH:
    INC  SI
    LOOP COMP_LOOP
    
    CMP  BX, 0               ; hubo aciertos?
    JNE  COMP_FIN
    INC  ERRORES             ; no hubo: sumar error
COMP_FIN:
    MOV  AL, BL              ; retornar # aciertos en AL
    POP  DX
    POP  SI
    POP  CX
    POP  BX
    RET
COMPARAR_LETRA ENDP
```

Devuelve en AL la cantidad de aciertos del turno, por si la rutina llamante necesita saberlo (por ejemplo, para mostrar un mensaje de "acertaste 2 letras"). El estado del juego queda actualizado en las variables globales.


### 3.2 VALIDAR_REPETIDA

Este PROC se debe llamar SIEMPRE antes de COMPARAR_LETRA. Revisa el arreglo USADAS para saber si la letra ya fue ingresada en este turno. Si no fue usada, la marca como usada. Si ya estaba usada, no la marca y avisa con el flag CF=1.

El truco esta en que el arreglo USADAS tiene 26 posiciones (una por letra del abecedario), y el indice se obtiene restando 'A' al codigo ASCII de la letra. Asi A=0, B=1, ..., Z=25.

```
VALIDAR_REPETIDA PROC
    PUSH AX
    PUSH BX
    
    MOV  AL, LETRA_ACTUAL    ; AL = letra (ej: 'C')
    SUB  AL, 'A'             ; AL = indice (ej: 'C'-'A' = 2)
    
    MOV  BL, AL              ; BX = indice (16 bits) para direccionar
    MOV  BH, 0
    
    CMP  USADAS[BX], 1       ; ya estaba marcada?
    JE   VR_REPETIDA
    
    MOV  USADAS[BX], 1       ; marcar como usada
    CLC                      ; CF=0: letra nueva, continuar flujo
    JMP  VR_FIN
    
VR_REPETIDA:
    STC                      ; CF=1: letra repetida, NO continuar
    
VR_FIN:
    POP  BX
    POP  AX
    RET
VALIDAR_REPETIDA ENDP
```

La salida va por el Carry Flag (CF). Esto significa que la rutina llamante debe usar JC o JNC inmediatamente despues del CALL, antes de cualquier instruccion que toque las banderas.


### 3.3 DETECTAR_VICTORIA

Recorre el arreglo ESTADO buscando guiones bajos. Si no encuentra ninguno, significa que todas las letras fueron reveladas, por lo tanto el jugador gano. La salida va por CF: 1 si gano, 0 si aun sigue el juego.

```
DETECTAR_VICTORIA PROC
    PUSH AX
    PUSH CX
    PUSH SI
    
    XOR  SI, SI
    MOV  CL, LONG_PALABRA
    MOV  CH, 0
    
DV_LOOP:
    CMP  ESTADO[SI], '_'     ; hay guion bajo?
    JE   DV_NO_GANO          ; si: aun no gana
    INC  SI
    LOOP DV_LOOP
    
    STC                      ; no encontro '_': gano
    JMP  DV_FIN
    
DV_NO_GANO:
    CLC                      ; sigue jugando
    
DV_FIN:
    POP  SI
    POP  CX
    POP  AX
    RET
DETECTAR_VICTORIA ENDP
```


### 3.4 DETECTAR_DERROTA

Compara ERRORES con la constante MAX_ERRORES (6). Si ERRORES llego al maximo, el jugador perdio. Igual que las anteriores, la respuesta va por CF.

```
DETECTAR_DERROTA PROC
    PUSH AX
    
    MOV  AL, ERRORES
    CMP  AL, MAX_ERRORES
    JB   DD_SIGUE            ; si ERRORES < 6, sigue jugando
    
    STC                      ; errores >= 6: derrota
    JMP  DD_FIN
    
DD_SIGUE:
    CLC
    
DD_FIN:
    POP  AX
    RET
DETECTAR_DERROTA ENDP
```

Importante: DETECTAR_VICTORIA debe llamarse ANTES que DETECTAR_DERROTA. Si en el ultimo intento el jugador adivina la palabra completa, debe ganar, no perder. El orden importa.


### 3.5 CALCULAR_PUNTAJE

Usa una tabla de busqueda (lookup table) en lugar de comparaciones encadenadas. La tabla TABLA_PUNTAJES esta indexada por la cantidad de errores: posicion 0 da 100, posicion 2 da 85, posicion 6 da 10.

Este PROC se llama en cada iteracion del loop de turno para que PUNTAJE_ACTUAL siempre refleje el puntaje que el jugador obtendria si ganara ahora mismo. Asi Persona 1 puede mostrarlo en pantalla en tiempo real.

```
CALCULAR_PUNTAJE PROC
    PUSH BX
    
    MOV  BL, ERRORES         ; BL = errores actuales
    MOV  BH, 0               ; BX = indice valido 0-6
    
    MOV  AL, TABLA_PUNTAJES[BX]   ; lookup en la tabla
    MOV  PUNTAJE_ACTUAL, AL
    
    POP  BX
    RET
CALCULAR_PUNTAJE ENDP
```

Una nota importante: este PROC asume que ERRORES esta en el rango 0-6. Como DETECTAR_DERROTA termina el flujo cuando ERRORES llega a 6, no deberia haber problemas, pero si en pruebas se pone manualmente un valor mayor, la tabla lee memoria fuera de rango.


### 3.6 PUNTAJE_DERROTA y ACUMULAR_PUNTAJE

PUNTAJE_DERROTA es trivial: cuando el jugador pierde o se rinde, su puntaje del turno es cero. Existe como PROC separado para mantener el codigo limpio y para que Persona 1 pueda llamarlo desde el menu "Rendirse" sin hacer logica adicional.

```
PUNTAJE_DERROTA PROC
    MOV  PUNTAJE_ACTUAL, 0
    RET
PUNTAJE_DERROTA ENDP
```

ACUMULAR_PUNTAJE suma PUNTAJE_ACTUAL al total del jugador en turno. Se debe llamar UNA SOLA VEZ al terminar la ronda, despues de calcular el puntaje (o despues de PUNTAJE_DERROTA si perdio). Si se llama dos veces, el puntaje se suma dos veces.

```
ACUMULAR_PUNTAJE PROC
    PUSH AX
    
    MOV  AL, PUNTAJE_ACTUAL  ; cargar como word
    MOV  AH, 0
    
    CMP  TURNO, 1            ; sumar a J1 o J2?
    JNE  AP_JUGADOR_2
    
    ADD  PUNTAJE_J1, AX
    JMP  AP_FIN
    
AP_JUGADOR_2:
    ADD  PUNTAJE_J2, AX
    
AP_FIN:
    POP  AX
    RET
ACUMULAR_PUNTAJE ENDP
```


### 3.7 CAMBIO_TURNO

Este PROC se llama UNICAMENTE en modalidad PvP (MODALIDAD=2) al terminar una ronda. Alterna TURNO entre 1 y 2 y deja todas las variables del estado del juego listas para el siguiente jugador: ERRORES en 0, PUNTAJE_ACTUAL en 0 y el arreglo USADAS limpio.

```
CAMBIO_TURNO PROC
    PUSH AX
    
    MOV  AL, TURNO
    CMP  AL, 1
    JE   CT_PASA_A_2
    
    MOV  TURNO, 1            ; venia 2, ahora 1
    JMP  CT_LIMPIAR
    
CT_PASA_A_2:
    MOV  TURNO, 2            ; venia 1, ahora 2
    
CT_LIMPIAR:
    MOV  ERRORES, 0
    MOV  PUNTAJE_ACTUAL, 0
    CALL REINICIAR_USADAS
    
    POP  AX
    RET
CAMBIO_TURNO ENDP
```

Despues de llamar a CAMBIO_TURNO, Persona 3 debe cargar la nueva palabra del siguiente jugador (en PvP, esa palabra la escribe el jugador anterior en secreto). El PROC CARGAR_PALABRA tambien se encarga de reiniciar ESTADO con guiones bajos del nuevo tamano.


## 4. Rutinas auxiliares de soporte

### 4.1 REINICIAR_USADAS y REINICIAR_ESTADO

Estas dos rutinas limpian arreglos. REINICIAR_USADAS pone 26 ceros en USADAS, y REINICIAR_ESTADO llena ESTADO con guiones bajos segun LONG_PALABRA. Ambas usan la instruccion REP STOSB, que es el metodo estandar del 8086 para llenar bloques de memoria.

```
REINICIAR_USADAS PROC
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH ES
    
    PUSH DS                  ; ES = DS (truco con la pila)
    POP  ES
    
    LEA  DI, USADAS
    MOV  CX, 26
    MOV  AL, 0
    REP  STOSB               ; ES:[DI] = AL, DI++, CX--, repetir
    
    POP  ES
    POP  DI
    POP  CX
    POP  AX
    RET
REINICIAR_USADAS ENDP
```

REINICIAR_ESTADO sigue la misma estructura pero usa LONG_PALABRA como contador y '_' como valor a escribir.


### 4.2 IMPRIMIR_PUNTAJE e IMPRIMIR_NUMERO

DOS no tiene una funcion nativa para imprimir numeros decimales, asi que IMPRIMIR_NUMERO los convierte digito por digito usando divisiones sucesivas entre 10. Los digitos se apilan al sacarlos (porque salen en orden inverso) y luego se imprimen sacandolos de la pila.

```
IMPRIMIR_NUMERO PROC          ; recibe AX = numero a imprimir
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    
    MOV  BX, 10              ; divisor
    MOV  CX, 0               ; contador de digitos
    
    CMP  AX, 0               ; caso especial: cero
    JNE  IN_LOOP_DIV
    MOV  DL, '0'
    CALL IMPRIMIR_CARACTER
    JMP  IN_FIN
    
IN_LOOP_DIV:
    CMP  AX, 0
    JE   IN_LOOP_PRINT
    MOV  DX, 0
    DIV  BX                  ; AX/=10, DX=AX mod 10
    PUSH DX                  ; guardar digito en pila
    INC  CX
    JMP  IN_LOOP_DIV
    
IN_LOOP_PRINT:
    CMP  CX, 0
    JE   IN_FIN
    POP  DX                  ; sacar digito
    ADD  DL, '0'             ; a ASCII
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
```

IMPRIMIR_PUNTAJE es simplemente un wrapper que carga PUNTAJE_ACTUAL en AX y llama a IMPRIMIR_NUMERO. Para imprimir PUNTAJE_J1 o PUNTAJE_J2, se carga directamente la variable en AX y se llama a IMPRIMIR_NUMERO.


## 5. Como integrar este modulo

Esta seccion explica como Persona 1 (interfaz) y Persona 3 (archivos) deben usar las rutinas de este modulo. La idea es que cada uno trabaje en paralelo y al final solo conectemos las piezas.

### 5.1 Para Persona 1 (interfaz y entrada)

Cuando el jugador presiona una letra, hay que ejecutar el flujo de validacion en este orden:

```
; Persona 1: capturar tecla y guardarla
CALL LEER_TECLA              ; AL = letra en mayuscula
MOV  LETRA_ACTUAL, AL

; Llamar a la logica
CALL VALIDAR_REPETIDA
JC   letra_repetida          ; CF=1: ya se uso, mostrar mensaje

CALL COMPARAR_LETRA          ; actualiza ESTADO o ERRORES

CALL DETECTAR_VICTORIA       ; siempre primero
JC   gano

CALL DETECTAR_DERROTA        ; despues
JC   perdio

; Si llego aqui, sigue el juego: redibujar pantalla y pedir otra letra
```

Para mostrar la informacion en pantalla, leer estas variables:

- **Nickname:** el de tu propia variable interna
- **Intentos restantes:** calcular como 6 - ERRORES
- **Puntaje actual:** leer PUNTAJE_ACTUAL (debe llamarse CALCULAR_PUNTAJE primero en cada iteracion del loop)
- **Palabra con guiones:** recorrer ESTADO hasta LONG_PALABRA
- **Letras usadas:** recorrer USADAS, si es 1 imprimir la letra (A + indice)
- **Puntaje total del jugador:** leer PUNTAJE_J1 o PUNTAJE_J2 segun TURNO

Para los botones del menu inferior:

```
; Boton 'Rendirse' (R)
CALL PUNTAJE_DERROTA         ; puntaje del turno = 0
CALL ACUMULAR_PUNTAJE        ; sumar 0 al total

CMP  MODALIDAD, 2            ; estamos en PvP?
JNE  fin_partida             ; no: termina el juego
CALL CAMBIO_TURNO            ; si: pasar al otro jugador
; luego Persona 3 carga nueva palabra

; Boton 'Reset' (X)
MOV  PUNTAJE_J1, 0
MOV  PUNTAJE_J2, 0
MOV  TURNO, 1
MOV  ERRORES, 0
; volver a la pantalla inicial (pedir nickname, modalidad, etc)

; Boton 'Salir' (S)
; mostrar estadisticas, luego INT 21h/4Ch
```


### 5.2 Para Persona 3 (archivos y datos)

Cuando se carga una palabra nueva (al inicio de la partida o al cambiar de turno en PvP), tu rutina CARGAR_PALABRA debe dejar listas estas variables:

- `PALABRA`: la palabra en MAYUSCULAS, solo A-Z, sin tildes ni enie
- `LONG_PALABRA`: la cantidad real de letras
- `ESTADO`: lleno con guiones bajos segun LONG_PALABRA (usa REINICIAR_ESTADO)
- `USADAS`: lleno con 26 ceros (usa REINICIAR_USADAS)
- `ERRORES`: en 0

Es decir, tu PROC podria tener esta estructura:

```
CARGAR_PALABRA PROC
    ; ... tu logica para leer archivo segun DIFICULTAD ...
    ; ... copiar la palabra elegida a PALABRA ...
    ; ... actualizar LONG_PALABRA ...
    
    ; Limpiar el estado del juego para la nueva ronda
    CALL REINICIAR_ESTADO    ; pone '_' segun LONG_PALABRA
    CALL REINICIAR_USADAS    ; pone 26 ceros
    MOV  ERRORES, 0
    
    RET
CARGAR_PALABRA ENDP
```

Si cumples con esto, el resto de la logica funciona sin tocar tu codigo. Lo mismo aplica para la entrada oculta del PvP: cuando el J1 escribe su palabra secreta, simplemente copiala a PALABRA y actualiza LONG_PALABRA.


## 6. Flujo completo de una partida

Para que quede claro como se conectan todas las piezas, aqui esta el flujo de una partida PvP de principio a fin:

```
; --- INICIO ---
; Persona 1: pedir nickname, modalidad, dificultad
MOV  MODALIDAD, 2            ; PvP
MOV  TURNO, 1
MOV  PUNTAJE_J1, 0
MOV  PUNTAJE_J2, 0

RONDA:
    ; Persona 3 carga la palabra (del archivo o input secreto del J1)
    CALL CARGAR_PALABRA
    
LOOP_TURNO:
    CALL CALCULAR_PUNTAJE    ; actualizar PUNTAJE_ACTUAL potencial
    ; Persona 1: dibujar pantalla con todo el estado
    
    ; Persona 1: capturar tecla
    CALL LEER_TECLA
    MOV  LETRA_ACTUAL, AL
    
    CALL VALIDAR_REPETIDA
    JC   LETRA_REPETIDA
    
    CALL COMPARAR_LETRA
    
    CALL DETECTAR_VICTORIA
    JC   GANO
    
    CALL DETECTAR_DERROTA
    JC   PERDIO
    
    JMP  LOOP_TURNO

LETRA_REPETIDA:
    ; Persona 1: mostrar mensaje
    JMP  LOOP_TURNO

GANO:
    CALL CALCULAR_PUNTAJE
    CALL ACUMULAR_PUNTAJE
    JMP  FIN_RONDA

PERDIO:
    CALL PUNTAJE_DERROTA
    CALL ACUMULAR_PUNTAJE

FIN_RONDA:
    CMP  TURNO, 2            ; ya jugaron ambos?
    JE   FIN_PARTIDA
    CALL CAMBIO_TURNO
    JMP  RONDA

FIN_PARTIDA:
    ; Persona 1: mostrar estadisticas finales
```


## 7. Interrupciones DOS y BIOS utilizadas

El modulo de logica no necesita muchas interrupciones porque su trabajo es procesar variables en memoria. Las que se usan son:

- `INT 21h, AH=01h`: leer una tecla del teclado con eco. Devuelve el ASCII en AL. Lo usa LEER_TECLA.
- `INT 21h, AH=02h`: imprimir el caracter que esta en DL. Lo usa IMPRIMIR_CARACTER y IMPRIMIR_NUMERO.
- `INT 21h, AH=09h`: imprimir cadena terminada en '$' apuntada por DS:DX. Lo usa IMPRIMIR_CADENA.
- `INT 21h, AH=4Ch`: terminar el programa devolviendo control a DOS. Solo se usa al cerrar.
- `INT 10h, AH=00h, AL=03h`: cambiar a modo texto 80x25. Su efecto colateral es limpiar la pantalla. Lo usa LIMPIAR_PANTALLA.


## 8. Resumen

El modulo entrega 10 procedimientos PROC listos para integrar:

- COMPARAR_LETRA
- VALIDAR_REPETIDA
- DETECTAR_VICTORIA
- DETECTAR_DERROTA
- CALCULAR_PUNTAJE
- PUNTAJE_DERROTA
- ACUMULAR_PUNTAJE
- CAMBIO_TURNO
- REINICIAR_ESTADO (auxiliar compartido con Persona 3)
- REINICIAR_USADAS (auxiliar compartido con Persona 3)

Mas las rutinas de I/O usadas como soporte (LIMPIAR_PANTALLA, IMPRIMIR_CADENA, IMPRIMIR_CARACTER, IMPRIMIR_NUMERO, IMPRIMIR_PUNTAJE, NUEVA_LINEA, LEER_TECLA) que Persona 1 puede reutilizar si lo desea.

Todos los procedimientos preservan los registros que usan mediante PUSH/POP, excepto por el Carry Flag que se usa intencionalmente como valor de retorno en las rutinas de validacion.
