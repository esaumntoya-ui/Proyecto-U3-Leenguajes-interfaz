; ================================================================
; PROYECTO: VENTAS E INVENTARIO EN ENSAMBLADOR (MASM x86 + Irvine32)
; NEGOCIO:  TIENDA DE VIDEOJUEGOS Y ACCESORIOS
; MATERIA:  LENGUAJES DE INTERFAZ - UNIDAD 2
; ALUMNO:   Beltran Montoya Esau 
; DOCENTE:   Dr.Jose Luis Medina Jimenez
; ================================================================
; Regla adicional del negocio: DESCUENTO POR CANTIDAD
;   5 a 9 unidades en una venta  -> 5% sobre el importe base
;   10 o mas unidades            -> 10% sobre el importe base
;   menos de 5 unidades          -> sin descuento
;   Las fracciones de centavo se descartan (division entera).
; Ademas, tras cada venta se avisa si la existencia queda en 5 o menos.
; ================================================================

INCLUDE Irvine32.inc

MAX_PROD    = 10            ; maximo de productos en el catalogo
REG_SIZE    = 48            ; bytes por registro
HDR_SIZE    = 8             ; cabecera del archivo: magic (4) + cantidad (4)
OFF_COD     = 0             ; 8 bytes  codigo ABC-123 + 0
OFF_NOM     = 8             ; 26 bytes nombre (hasta 25 caracteres + 0)
OFF_PRE     = 36            ; DWORD    precio en centavos
OFF_EXI     = 40            ; DWORD    existencia
OFF_VEN     = 44            ; DWORD    unidades vendidas acumuladas
MAX_EXIST   = 100
STOCK_BAJO  = 5
PRECIO_MAX  = 999999        ; $9999.99 en centavos

.data
; --- Bloque que se guarda en el archivo (deben quedar contiguos) ---
catMagic        BYTE "INV2"
cantidad        DWORD 0
registros       BYTE MAX_PROD*REG_SIZE DUP(0)
; -------------------------------------------------------------------

ingresos        DWORD 0             ; ingresos de la sesion (no se guardan)
cambios         BYTE 0
hayBajo         BYTE 0

nombreArchivo   BYTE "inventario.dat",0
hArchivo        DWORD 0
bytesPedidos    DWORD 0
bytesEscritos   DWORD 0
bytesLeidos     DWORD 0
inicioRegs      DWORD 0
bufArchivo      BYTE 500 DUP(0)     ; cabecera + 10 registros = 488 bytes

bufEntrada      BYTE 81 DUP(0)      ; ReadString lee maximo 80 + el 0 final
bufNum          BYTE 24 DUP(0)

tmpCodigo       BYTE 8 DUP(0)
tmpNombre       BYTE 26 DUP(0)
tmpPrecio       DWORD 0
tmpExist        DWORD 0
valorLeido      DWORD 0

cantVenta       DWORD 0
pctDesc         DWORD 0
ventaBase       DWORD 0
ventaDesc       DWORD 0
ventaFinal      DWORD 0

menuTxt         BYTE 0Dh,0Ah
                BYTE "====== TIENDA DE VIDEOJUEGOS: VENTAS E INVENTARIO ======",0Dh,0Ah
                BYTE " 1. Registrar producto",0Dh,0Ah
                BYTE " 2. Mostrar inventario",0Dh,0Ah
                BYTE " 3. Buscar producto por codigo",0Dh,0Ah
                BYTE " 4. Recibir mercancia",0Dh,0Ah
                BYTE " 5. Vender",0Dh,0Ah
                BYTE " 6. Resumen",0Dh,0Ah
                BYTE " 7. Guardar inventario",0Dh,0Ah
                BYTE " 8. Cargar inventario",0Dh,0Ah
                BYTE " 9. Eliminar producto",0Dh,0Ah
                BYTE " 0. Salir",0Dh,0Ah
                BYTE "=======================================================",0Dh,0Ah,0

msgOpcion       BYTE "Opcion: ",0
msgOpcionMal    BYTE "Opcion invalida.",0Dh,0Ah,0
msgCodigo       BYTE "Codigo (formato ABC-123): ",0
msgNombre       BYTE "Nombre (1 a 25 caracteres): ",0
msgPrecio       BYTE "Precio en MXN (ej. 185.50): ",0
msgExistencia   BYTE "Existencia inicial (0 a 100): ",0
msgCantRecibir  BYTE "Unidades a recibir (mayor que 0): ",0
msgCantVender   BYTE "Unidades a vender (mayor que 0): ",0

msgLleno        BYTE "RECHAZADO: el catalogo ya tiene 10 productos.",0Dh,0Ah,0
msgCodigoMal    BYTE "RECHAZADO: codigo incorrecto (3 letras MAYUSCULAS, guion, 3 digitos).",0Dh,0Ah,0
msgDuplicado    BYTE "RECHAZADO: ya existe un producto con ese codigo.",0Dh,0Ah,0
msgNombreMal    BYTE "RECHAZADO: el nombre debe tener de 1 a 25 caracteres.",0Dh,0Ah,0
msgPrecioMal    BYTE "RECHAZADO: precio invalido (0.01 a 9999.99, maximo 2 decimales).",0Dh,0Ah,0
msgExistMal     BYTE "RECHAZADO: existencia invalida (entero de 0 a 100).",0Dh,0Ah,0
msgNoExiste     BYTE "RECHAZADO: no existe un producto con ese codigo.",0Dh,0Ah,0
msgCantMal      BYTE "RECHAZADO: cantidad invalida (entero mayor que 0).",0Dh,0Ah,0
msgExcede       BYTE "RECHAZADO: la existencia no puede pasar de 100 unidades.",0Dh,0Ah,0
msgSinStock     BYTE "RECHAZADO: no hay existencias suficientes.",0Dh,0Ah,0
msgDesborde     BYTE "RECHAZADO: desbordamiento en el calculo.",0Dh,0Ah,0

msgAltaOk       BYTE "Producto registrado.",0Dh,0Ah,0
msgBajaOk       BYTE "Producto eliminado.",0Dh,0Ah,0
msgNoHay        BYTE "No hay productos registrados.",0Dh,0Ah,0
msgEncabezado   BYTE "--- Inventario ---",0Dh,0Ah,0
msgRecibidoOk   BYTE "Mercancia recibida. Nueva existencia: ",0
msgVentaOk      BYTE "Venta aceptada.",0Dh,0Ah,0
msgBase         BYTE "  Importe base:   ",0
msgDesc1        BYTE "  Descuento (",0
msgDesc2        BYTE "%):  ",0
msgSinDesc      BYTE "  Sin descuento (5% desde 5 unidades, 10% desde 10).",0Dh,0Ah,0
msgTotal        BYTE "  TOTAL A COBRAR: ",0
msgAlertaStock  BYTE "  AVISO: existencia minima (5 o menos), conviene reabastecer.",0Dh,0Ah,0

msgRepTitulo    BYTE "--- Resumen ---",0Dh,0Ah,0
msgResUnid      BYTE "Unidades disponibles:  ",0
msgResValor     BYTE "Valor del inventario:  ",0
msgResIngr      BYTE "Ingresos de la sesion: ",0
msgBajoTitulo   BYTE "Productos con existencia minima (5 o menos):",0Dh,0Ah,0
msgNingunoBajo  BYTE "  Ninguno.",0Dh,0Ah,0

msgGuardado     BYTE "Inventario guardado en inventario.dat",0Dh,0Ah,0
msgErrCrear     BYTE "ERROR: no se pudo crear el archivo.",0Dh,0Ah,0
msgErrEscribir  BYTE "ERROR: no se escribieron todos los datos.",0Dh,0Ah,0
msgCargado      BYTE "Inventario cargado. Productos: ",0
msgNoArchivo    BYTE "ERROR: inventario.dat no existe o no se pudo abrir. Catalogo sin cambios.",0Dh,0Ah,0
msgErrLeer      BYTE "ERROR: no se pudo leer el archivo. Catalogo sin cambios.",0Dh,0Ah,0
msgArchivoMal   BYTE "ERROR: archivo danado o con datos invalidos. Catalogo sin cambios.",0Dh,0Ah,0
msgConfCargar   BYTE "Hay cambios sin guardar y se perderan. Continuar? (S/N): ",0
msgSinGuardar   BYTE "Hay cambios sin guardar. Salir de todas formas? (S/N): ",0
msgAdios        BYTE "Hasta luego.",0Dh,0Ah,0

txtCodigo       BYTE "Codigo: ",0
txtNombre       BYTE " | Nombre: ",0
txtPrecio       BYTE " | Precio: ",0
txtExist        BYTE " | Existencia: ",0
txtVend         BYTE " | Vendidas: ",0
txtMXN          BYTE " MXN",0

.code

; ================================================================
; PROGRAMA PRINCIPAL
; ================================================================
main PROC
menu_loop:
    mov  edx, OFFSET menuTxt
    call WriteString
    mov  edx, OFFSET msgOpcion
    call PedirTexto
    cmp  eax, 1
    jne  opcion_mal
    mov  al, bufEntrada

    cmp  al, '1'
    je   op1
    cmp  al, '2'
    je   op2
    cmp  al, '3'
    je   op3
    cmp  al, '4'
    je   op4
    cmp  al, '5'
    je   op5
    cmp  al, '6'
    je   op6
    cmp  al, '7'
    je   op7
    cmp  al, '8'
    je   op8
    cmp  al, '9'
    je   op9
    cmp  al, '0'
    je   op0
opcion_mal:
    mov  edx, OFFSET msgOpcionMal
    call WriteString
    jmp  menu_loop

op1:
    call Alta
    jmp  menu_loop
op2:
    call MostrarInventario
    jmp  menu_loop
op3:
    call BuscarProducto
    jmp  menu_loop
op4:
    call Recibir
    jmp  menu_loop
op5:
    call Vender
    jmp  menu_loop
op6:
    call Resumen
    jmp  menu_loop
op7:
    call Guardar
    jmp  menu_loop
op8:
    call Cargar
    jmp  menu_loop
op9:
    call Eliminar
    jmp  menu_loop

op0:
    cmp  cambios, 0
    je   salir
    mov  edx, OFFSET msgSinGuardar
    call PedirTexto
    cmp  eax, 1
    jne  menu_loop
    mov  al, bufEntrada
    cmp  al, 'S'
    je   salir
    cmp  al, 's'
    je   salir
    jmp  menu_loop

salir:
    mov  edx, OFFSET msgAdios
    call WriteString
    exit
main ENDP

; ================================================================
; ENTRADA DE DATOS
; ================================================================

; ----------------------------------------------------------------
; PedirTexto
;   Entrada:  EDX = direccion del mensaje a mostrar
;   Salida:   EAX = numero de caracteres capturados
;             bufEntrada = texto capturado, terminado en 0
;   Modifica: EAX, bufEntrada (conserva ECX y EDX)
; ----------------------------------------------------------------
PedirTexto PROC
    push ecx
    push edx
    call WriteString
    mov  edx, OFFSET bufEntrada     ; EDX = buffer destino
    mov  ecx, 80                    ; ECX = maximo de caracteres
    call ReadString                 ; EAX = caracteres leidos
    pop  edx
    pop  ecx
    ret
PedirTexto ENDP

; ----------------------------------------------------------------
; LeerEntero
;   Entrada:  ESI = cadena terminada en 0
;   Salida:   EAX = 1 si es un entero valido (valor en valorLeido), 0 si no
;   Modifica: EAX, valorLeido (conserva EBX, ECX, EDX, ESI)
; ----------------------------------------------------------------
LeerEntero PROC
    push ebx
    push ecx
    push edx
    push esi
    xor  eax, eax
    cmp  BYTE PTR [esi], 0
    je   le_mal
    mov  ecx, 10
le_ciclo:
    movzx ebx, BYTE PTR [esi]
    cmp  ebx, 0
    je   le_ok
    cmp  ebx, '0'
    jb   le_mal
    cmp  ebx, '9'
    ja   le_mal
    sub  ebx, '0'
    mul  ecx                        ; EDX:EAX = EAX * 10
    jc   le_mal                     ; desbordamiento
    add  eax, ebx
    jc   le_mal
    inc  esi
    jmp  le_ciclo
le_ok:
    mov  valorLeido, eax
    mov  eax, 1
    jmp  le_fin
le_mal:
    xor  eax, eax
le_fin:
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    ret
LeerEntero ENDP

; ----------------------------------------------------------------
; PedirEntero
;   Entrada:  EDX = mensaje
;   Salida:   EAX = 1 si es entero valido (valor en valorLeido), 0 si no
;   Modifica: EAX, bufEntrada, valorLeido (conserva ESI)
; ----------------------------------------------------------------
PedirEntero PROC
    push esi
    call PedirTexto
    mov  esi, OFFSET bufEntrada
    call LeerEntero
    pop  esi
    ret
PedirEntero ENDP

; ----------------------------------------------------------------
; LeerPrecio
;   Convierte "185.50", "12.5" o "300" a centavos enteros.
;   Acepta pesos enteros o punto con 1 o 2 decimales. Rechaza simbolos,
;   separadores de miles, un tercer decimal y precios fuera de 0.01-9999.99
;   Entrada:  ESI = cadena terminada en 0
;   Salida:   EAX = 1 si es valido (centavos en tmpPrecio), 0 si no
;   Modifica: EAX, tmpPrecio (conserva EBX, ECX, EDX, ESI)
; ----------------------------------------------------------------
LeerPrecio PROC
    push ebx
    push ecx
    push edx
    push esi
    xor  eax, eax                   ; pesos acumulados
    xor  ecx, ecx                   ; digitos enteros leidos
lp_ent:
    movzx ebx, BYTE PTR [esi]
    cmp  ebx, 0
    je   lp_sin_dec
    cmp  ebx, '.'
    je   lp_punto
    cmp  ebx, '0'
    jb   lp_mal
    cmp  ebx, '9'
    ja   lp_mal
    sub  ebx, '0'
    imul eax, eax, 10
    add  eax, ebx
    cmp  eax, 9999
    ja   lp_mal
    inc  ecx
    inc  esi
    jmp  lp_ent

lp_sin_dec:
    cmp  ecx, 0
    je   lp_mal
    imul eax, eax, 100              ; pesos a centavos
    jmp  lp_listo

lp_punto:
    cmp  ecx, 0                     ; el punto no puede ir al inicio
    je   lp_mal
    imul eax, eax, 100
    inc  esi
    ; primer decimal (obligatorio si hay punto)
    movzx ebx, BYTE PTR [esi]
    cmp  ebx, '0'
    jb   lp_mal
    cmp  ebx, '9'
    ja   lp_mal
    sub  ebx, '0'
    imul ebx, ebx, 10               ; decenas de centavo
    add  eax, ebx
    inc  esi
    ; segundo decimal (opcional)
    movzx ebx, BYTE PTR [esi]
    cmp  ebx, 0
    je   lp_listo
    cmp  ebx, '0'
    jb   lp_mal
    cmp  ebx, '9'
    ja   lp_mal
    sub  ebx, '0'
    add  eax, ebx
    inc  esi
    cmp  BYTE PTR [esi], 0          ; un tercer caracter se rechaza
    jne  lp_mal

lp_listo:
    cmp  eax, 1
    jb   lp_mal
    cmp  eax, PRECIO_MAX
    ja   lp_mal
    mov  tmpPrecio, eax
    mov  eax, 1
    jmp  lp_fin
lp_mal:
    xor  eax, eax
lp_fin:
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    ret
LeerPrecio ENDP

; ----------------------------------------------------------------
; ValidarCodigo
;   Verifica el formato ABC-123 (3 mayusculas, guion, 3 digitos, fin)
;   Entrada:  ESI = cadena terminada en 0
;   Salida:   EAX = 1 si el formato es correcto, 0 si no
;   Modifica: EAX (conserva EBX, ECX, ESI)
; ----------------------------------------------------------------
ValidarCodigo PROC
    push ebx
    push ecx
    push esi
    xor  eax, eax
    mov  ecx, 3
vc_letras:
    movzx ebx, BYTE PTR [esi]
    cmp  ebx, 'A'
    jb   vc_fin
    cmp  ebx, 'Z'
    ja   vc_fin
    inc  esi
    loop vc_letras
    cmp  BYTE PTR [esi], '-'
    jne  vc_fin
    inc  esi
    mov  ecx, 3
vc_digitos:
    movzx ebx, BYTE PTR [esi]
    cmp  ebx, '0'
    jb   vc_fin
    cmp  ebx, '9'
    ja   vc_fin
    inc  esi
    loop vc_digitos
    cmp  BYTE PTR [esi], 0
    jne  vc_fin
    mov  eax, 1
vc_fin:
    pop  esi
    pop  ecx
    pop  ebx
    ret
ValidarCodigo ENDP

; ----------------------------------------------------------------
; PedirCodigo
;   Pide un codigo, valida su formato y lo deja en tmpCodigo.
;   Entrada:  ninguna
;   Salida:   EAX = 1 si es valido (codigo en tmpCodigo).
;             Si no, imprime el error y EAX = 0
;   Modifica: EAX, bufEntrada, tmpCodigo (conserva EDX, ESI, EDI)
; ----------------------------------------------------------------
PedirCodigo PROC
    push edx
    push esi
    push edi
    mov  edx, OFFSET msgCodigo
    call PedirTexto
    mov  esi, OFFSET bufEntrada
    call ValidarCodigo
    cmp  eax, 0
    je   pc_mal
    mov  edi, OFFSET tmpCodigo
    call CopiarCadena
    mov  eax, 1
    jmp  pc_fin
pc_mal:
    mov  edx, OFFSET msgCodigoMal
    call WriteString
    xor  eax, eax
pc_fin:
    pop  edi
    pop  esi
    pop  edx
    ret
PedirCodigo ENDP

; ================================================================
; BUSQUEDA
; ================================================================

; ----------------------------------------------------------------
; CodigosIguales
;   Compara los 7 caracteres de dos codigos
;   Entrada:  ESI = primer codigo, EDI = segundo codigo
;   Salida:   EAX = 1 si son iguales, 0 si no
;   Modifica: EAX (conserva EBX, ECX, ESI, EDI)
; ----------------------------------------------------------------
CodigosIguales PROC
    push ebx
    push ecx
    push esi
    push edi
    mov  ecx, 7
ci_loop:
    mov  bl, [esi]
    cmp  bl, [edi]
    jne  ci_no
    inc  esi
    inc  edi
    dec  ecx
    jnz  ci_loop
    mov  eax, 1
    jmp  ci_fin
ci_no:
    xor  eax, eax
ci_fin:
    pop  edi
    pop  esi
    pop  ecx
    pop  ebx
    ret
CodigosIguales ENDP

; ----------------------------------------------------------------
; BuscarCodigo
;   Recorre el catalogo con ESI buscando tmpCodigo
;   Entrada:  tmpCodigo = codigo a buscar, cantidad = productos registrados
;   Salida:   EAX = 1 y ESI = inicio del registro si lo encuentra;
;             EAX = 0 si no existe (ESI sin significado)
;   Modifica: EAX, ESI (conserva ECX y EDI)
; ----------------------------------------------------------------
BuscarCodigo PROC
    push ecx
    push edi
    mov  esi, OFFSET registros
    mov  edi, OFFSET tmpCodigo
    mov  ecx, cantidad
    cmp  ecx, 0
    je   bc_no
bc_loop:
    call CodigosIguales             ; compara [ESI] contra [EDI]
    cmp  eax, 1
    je   bc_fin
    add  esi, REG_SIZE              ; siguiente registro
    dec  ecx
    jnz  bc_loop
bc_no:
    xor  eax, eax
bc_fin:
    pop  edi
    pop  ecx
    ret
BuscarCodigo ENDP

; ----------------------------------------------------------------
; PedirYBuscar
;   Pide un codigo y lo busca. Imprime el error si es invalido o no existe.
;   Salida:   EAX = 1 y ESI = registro si existe, 0 si no
;   Modifica: EAX, ESI, bufEntrada, tmpCodigo (conserva EDX)
; ----------------------------------------------------------------
PedirYBuscar PROC
    push edx
    call PedirCodigo
    cmp  eax, 0
    je   pyb_fin
    call BuscarCodigo
    cmp  eax, 1
    je   pyb_fin
    mov  edx, OFFSET msgNoExiste
    call WriteString
    xor  eax, eax
pyb_fin:
    pop  edx
    ret
PedirYBuscar ENDP

; ================================================================
; UTILIDADES DE CADENAS Y NUMEROS
; ================================================================

; ----------------------------------------------------------------
; CopiarCadena
;   Entrada:  ESI = origen, EDI = destino (el destino debe tener espacio)
;   Salida:   cadena copiada con su 0 final
;   Modifica: solo la memoria destino (conserva EAX, ESI, EDI)
; ----------------------------------------------------------------
CopiarCadena PROC
    push eax
    push esi
    push edi
cc_loop:
    mov  al, [esi]
    mov  [edi], al
    inc  esi
    inc  edi
    cmp  al, 0
    jne  cc_loop
    pop  edi
    pop  esi
    pop  eax
    ret
CopiarCadena ENDP

; ----------------------------------------------------------------
; EnteroACadena
;   Convierte EAX a digitos ASCII. Divide entre 10: cada residuo es un digito
;   (se apila) y al sacarlos de la pila quedan en el orden correcto.
;   Entrada:  EAX = numero, EDI = destino
;   Salida:   digitos escritos en [EDI] con 0 final
;   Modifica: EDI (queda apuntando al 0 final, para seguir concatenando)
;             y la memoria destino. Conserva EAX, EBX, ECX, EDX
; ----------------------------------------------------------------
EnteroACadena PROC
    push eax
    push ebx
    push ecx
    push edx
    mov  ebx, 10
    xor  ecx, ecx
ea_div:
    xor  edx, edx
    div  ebx                        ; EAX = cociente, EDX = residuo
    push edx
    inc  ecx
    test eax, eax
    jnz  ea_div
ea_sacar:
    pop  edx
    add  dl, '0'                    ; digito -> ASCII
    mov  [edi], dl
    inc  edi
    loop ea_sacar
    mov  BYTE PTR [edi], 0
    pop  edx
    pop  ecx
    pop  ebx
    pop  eax
    ret
EnteroACadena ENDP

; ----------------------------------------------------------------
; MostrarNumero
;   Entrada:  EAX = numero
;   Salida:   imprime el numero en decimal
;   Modifica: bufNum (conserva todos los registros)
; ----------------------------------------------------------------
MostrarNumero PROC
    push edx
    push edi
    mov  edi, OFFSET bufNum
    call EnteroACadena
    mov  edx, OFFSET bufNum
    call WriteString
    pop  edi
    pop  edx
    ret
MostrarNumero ENDP

; ----------------------------------------------------------------
; MostrarPrecio
;   Imprime centavos como "$123.45 MXN". DIV entre 100 separa pesos
;   (EAX) y centavos (EDX); otro DIV entre 10 da decenas y unidades,
;   asi un residuo de 5 se muestra como 05.
;   Entrada:  EAX = importe en centavos
;   Salida:   imprime el importe con dos decimales y la etiqueta MXN
;   Modifica: bufNum (conserva todos los registros)
; ----------------------------------------------------------------
MostrarPrecio PROC
    push eax
    push ebx
    push edx
    push edi
    mov  edi, OFFSET bufNum
    mov  BYTE PTR [edi], '$'
    inc  edi
    xor  edx, edx                   ; dividendo = EDX:EAX
    mov  ebx, 100
    div  ebx                        ; EAX = pesos, EDX = centavos
    push edx
    call EnteroACadena
    pop  eax                        ; EAX = centavos
    mov  BYTE PTR [edi], '.'
    inc  edi
    xor  edx, edx
    mov  ebx, 10
    div  ebx                        ; EAX = decenas, EDX = unidades
    add  al, '0'
    mov  [edi], al
    inc  edi
    add  dl, '0'
    mov  [edi], dl
    inc  edi
    mov  BYTE PTR [edi], 0
    mov  edx, OFFSET bufNum
    call WriteString
    mov  edx, OFFSET txtMXN
    call WriteString
    pop  edi
    pop  edx
    pop  ebx
    pop  eax
    ret
MostrarPrecio ENDP

; ----------------------------------------------------------------
; ImprimirProducto
;   Entrada:  ESI = inicio de un registro
;   Salida:   imprime una linea con codigo, nombre, precio, existencia y vendidas
;   Modifica: bufNum (conserva todos los registros)
; ----------------------------------------------------------------
ImprimirProducto PROC
    push eax
    push edx
    mov  edx, OFFSET txtCodigo
    call WriteString
    mov  edx, esi                   ; el codigo esta al inicio del registro
    call WriteString
    mov  edx, OFFSET txtNombre
    call WriteString
    lea  edx, [esi + OFF_NOM]
    call WriteString
    mov  edx, OFFSET txtPrecio
    call WriteString
    mov  eax, [esi + OFF_PRE]
    call MostrarPrecio
    mov  edx, OFFSET txtExist
    call WriteString
    mov  eax, [esi + OFF_EXI]
    call MostrarNumero
    mov  edx, OFFSET txtVend
    call WriteString
    mov  eax, [esi + OFF_VEN]
    call MostrarNumero
    call Crlf
    pop  edx
    pop  eax
    ret
ImprimirProducto ENDP

; ================================================================
; OPERACIONES DEL MENU (cada una conserva todos los registros con
; PUSHAD/POPAD y solo modifica la memoria indicada)
; ================================================================

; ----------------------------------------------------------------
; Alta
;   Registra un producto. Todo se valida antes de escribir en el catalogo,
;   asi un rechazo conserva los datos anteriores.
;   Modifica: registros, cantidad, cambios, tmpCodigo, tmpNombre,
;             tmpPrecio, tmpExist, bufEntrada
; ----------------------------------------------------------------
Alta PROC
    pushad
    cmp  cantidad, MAX_PROD
    jae  al_lleno

    call PedirCodigo
    cmp  eax, 0
    je   al_fin                     ; PedirCodigo ya imprimio el error
    call BuscarCodigo
    cmp  eax, 1
    je   al_duplicado

    mov  edx, OFFSET msgNombre
    call PedirTexto
    cmp  eax, 1
    jb   al_nombre_mal
    cmp  eax, 25
    ja   al_nombre_mal
    mov  esi, OFFSET bufEntrada
    mov  edi, OFFSET tmpNombre
    call CopiarCadena

    mov  edx, OFFSET msgPrecio
    call PedirTexto
    mov  esi, OFFSET bufEntrada
    call LeerPrecio
    cmp  eax, 0
    je   al_precio_mal

    mov  edx, OFFSET msgExistencia
    call PedirEntero
    cmp  eax, 0
    je   al_exist_mal
    mov  eax, valorLeido
    cmp  eax, MAX_EXIST
    ja   al_exist_mal
    mov  tmpExist, eax

    ; direccion del nuevo registro = registros + cantidad * REG_SIZE
    mov  eax, cantidad
    mov  ebx, REG_SIZE
    mul  ebx
    mov  edi, OFFSET registros
    add  edi, eax
    mov  ebx, edi                   ; EBX = inicio del registro

    mov  ecx, REG_SIZE              ; limpiar el registro
    xor  al, al
    cld
    rep  stosb

    mov  esi, OFFSET tmpCodigo
    mov  edi, ebx
    call CopiarCadena
    mov  esi, OFFSET tmpNombre
    lea  edi, [ebx + OFF_NOM]
    call CopiarCadena
    mov  eax, tmpPrecio
    mov  [ebx + OFF_PRE], eax
    mov  eax, tmpExist
    mov  [ebx + OFF_EXI], eax

    inc  cantidad
    mov  cambios, 1
    mov  edx, OFFSET msgAltaOk
    jmp  al_msg

al_lleno:
    mov  edx, OFFSET msgLleno
    jmp  al_msg
al_duplicado:
    mov  edx, OFFSET msgDuplicado
    jmp  al_msg
al_nombre_mal:
    mov  edx, OFFSET msgNombreMal
    jmp  al_msg
al_precio_mal:
    mov  edx, OFFSET msgPrecioMal
    jmp  al_msg
al_exist_mal:
    mov  edx, OFFSET msgExistMal
al_msg:
    call WriteString
al_fin:
    popad
    ret
Alta ENDP

; ----------------------------------------------------------------
; MostrarInventario
;   Recorre todos los registros con ESI e imprime cada producto.
;   Modifica: bufNum
; ----------------------------------------------------------------
MostrarInventario PROC
    pushad
    mov  ecx, cantidad
    cmp  ecx, 0
    jne  mi_hay
    mov  edx, OFFSET msgNoHay
    call WriteString
    jmp  mi_fin
mi_hay:
    mov  edx, OFFSET msgEncabezado
    call WriteString
    mov  esi, OFFSET registros
mi_loop:
    call ImprimirProducto
    add  esi, REG_SIZE
    dec  ecx
    jnz  mi_loop
mi_fin:
    popad
    ret
MostrarInventario ENDP

; ----------------------------------------------------------------
; BuscarProducto
;   Pide un codigo e imprime el producto si existe.
;   Modifica: bufEntrada, tmpCodigo, bufNum
; ----------------------------------------------------------------
BuscarProducto PROC
    pushad
    call PedirYBuscar
    cmp  eax, 1
    jne  bp_fin
    call ImprimirProducto
bp_fin:
    popad
    ret
BuscarProducto ENDP

; ----------------------------------------------------------------
; Recibir
;   Suma unidades a un producto sin pasar de MAX_EXIST (100).
;   Modifica: existencia del producto, cambios, bufEntrada, valorLeido
; ----------------------------------------------------------------
Recibir PROC
    pushad
    call PedirYBuscar
    cmp  eax, 1
    jne  rc_fin

    mov  edx, OFFSET msgCantRecibir
    call PedirEntero
    cmp  eax, 0
    je   rc_cant_mal
    mov  eax, valorLeido
    cmp  eax, 0
    je   rc_cant_mal

    add  eax, [esi + OFF_EXI]
    jc   rc_excede
    cmp  eax, MAX_EXIST
    ja   rc_excede

    mov  [esi + OFF_EXI], eax       ; solo aqui se modifica el registro
    mov  cambios, 1
    mov  edx, OFFSET msgRecibidoOk
    call WriteString
    call MostrarNumero
    call Crlf
    jmp  rc_fin

rc_cant_mal:
    mov  edx, OFFSET msgCantMal
    call WriteString
    jmp  rc_fin
rc_excede:
    mov  edx, OFFSET msgExcede
    call WriteString
rc_fin:
    popad
    ret
Recibir ENDP

; ----------------------------------------------------------------
; Vender
;   Valida existencias, calcula importe base, descuento por cantidad
;   y total. Existencia, vendidas e ingresos se actualizan hasta el
;   final, cuando ya no hay posibilidad de rechazo.
;   Modifica: existencia y vendidas del producto, ingresos, cambios,
;             cantVenta, pctDesc, ventaBase, ventaDesc, ventaFinal
; ----------------------------------------------------------------
Vender PROC
    pushad
    call PedirYBuscar
    cmp  eax, 1
    jne  ve_fin

    mov  edx, OFFSET msgCantVender
    call PedirEntero
    cmp  eax, 0
    je   ve_cant_mal
    mov  eax, valorLeido
    cmp  eax, 0
    je   ve_cant_mal
    mov  cantVenta, eax
    cmp  eax, [esi + OFF_EXI]
    ja   ve_sin_stock

    ; importe base = precio * cantidad
    mov  eax, [esi + OFF_PRE]
    mul  cantVenta
    jc   ve_desborda
    mov  ventaBase, eax

    ; porcentaje de descuento segun la cantidad
    mov  pctDesc, 0
    cmp  cantVenta, 10
    jae  ve_p10
    cmp  cantVenta, 5
    jae  ve_p5
    jmp  ve_calc
ve_p10:
    mov  pctDesc, 10
    jmp  ve_calc
ve_p5:
    mov  pctDesc, 5

ve_calc:
    mov  eax, ventaBase
    mul  pctDesc
    jc   ve_desborda
    xor  edx, edx
    mov  ebx, 100
    div  ebx                        ; EAX = descuento (fraccion de centavo descartada)
    mov  ventaDesc, eax

    mov  eax, ventaBase
    sub  eax, ventaDesc
    mov  ventaFinal, eax
    add  eax, ingresos
    jc   ve_desborda

    ; todo validado: ahora si se modifican los datos
    mov  ingresos, eax
    mov  eax, [esi + OFF_EXI]
    sub  eax, cantVenta
    mov  [esi + OFF_EXI], eax
    mov  eax, [esi + OFF_VEN]
    add  eax, cantVenta
    mov  [esi + OFF_VEN], eax
    mov  cambios, 1

    mov  edx, OFFSET msgVentaOk
    call WriteString
    mov  edx, OFFSET msgBase
    call WriteString
    mov  eax, ventaBase
    call MostrarPrecio
    call Crlf
    cmp  pctDesc, 0
    je   ve_sin_desc
    mov  edx, OFFSET msgDesc1
    call WriteString
    mov  eax, pctDesc
    call MostrarNumero
    mov  edx, OFFSET msgDesc2
    call WriteString
    mov  eax, ventaDesc
    call MostrarPrecio
    call Crlf
    jmp  ve_total
ve_sin_desc:
    mov  edx, OFFSET msgSinDesc
    call WriteString
ve_total:
    mov  edx, OFFSET msgTotal
    call WriteString
    mov  eax, ventaFinal
    call MostrarPrecio
    call Crlf
    cmp  DWORD PTR [esi + OFF_EXI], STOCK_BAJO
    ja   ve_fin
    mov  edx, OFFSET msgAlertaStock
    call WriteString
    jmp  ve_fin

ve_cant_mal:
    mov  edx, OFFSET msgCantMal
    jmp  ve_msg
ve_sin_stock:
    mov  edx, OFFSET msgSinStock
    jmp  ve_msg
ve_desborda:
    mov  edx, OFFSET msgDesborde
ve_msg:
    call WriteString
ve_fin:
    popad
    ret
Vender ENDP

; ----------------------------------------------------------------
; Eliminar
;   Borra un producto y recorre los siguientes para no dejar huecos.
;   Modifica: registros, cantidad, cambios, bufEntrada, tmpCodigo
; ----------------------------------------------------------------
Eliminar PROC
    pushad
    call PedirYBuscar
    cmp  eax, 1
    jne  el_fin

    mov  edi, esi                   ; destino = registro a borrar
    mov  eax, cantidad
    mov  ebx, REG_SIZE
    mul  ebx
    add  eax, OFFSET registros      ; EAX = fin de los registros
    lea  ecx, [esi + REG_SIZE]      ; origen = registro siguiente
    mov  esi, ecx
    sub  eax, ecx
    mov  ecx, eax                   ; bytes a recorrer
    cld
    rep  movsb

    dec  cantidad
    mov  cambios, 1
    mov  edx, OFFSET msgBajaOk
    call WriteString
el_fin:
    popad
    ret
Eliminar ENDP

; ----------------------------------------------------------------
; Resumen
;   Unidades disponibles, valor del inventario (suma de precio x
;   existencia), ingresos de la sesion y productos con existencia minima.
;   Modifica: hayBajo, bufNum
; ----------------------------------------------------------------
Resumen PROC
    pushad
    mov  edx, OFFSET msgRepTitulo
    call WriteString
    xor  ebx, ebx                   ; total de unidades
    xor  edi, edi                   ; valor del inventario (centavos)
    mov  ecx, cantidad
    cmp  ecx, 0
    je   rp_mostrar
    mov  esi, OFFSET registros
rp_loop:
    mov  eax, [esi + OFF_EXI]
    add  ebx, eax
    mul  DWORD PTR [esi + OFF_PRE]
    jc   rp_desborda
    add  edi, eax
    jc   rp_desborda
    add  esi, REG_SIZE
    dec  ecx
    jnz  rp_loop

rp_mostrar:
    mov  edx, OFFSET msgResUnid
    call WriteString
    mov  eax, ebx
    call MostrarNumero
    call Crlf
    mov  edx, OFFSET msgResValor
    call WriteString
    mov  eax, edi
    call MostrarPrecio
    call Crlf
    mov  edx, OFFSET msgResIngr
    call WriteString
    mov  eax, ingresos
    call MostrarPrecio
    call Crlf

    ; productos con existencia minima
    mov  edx, OFFSET msgBajoTitulo
    call WriteString
    mov  hayBajo, 0
    mov  ecx, cantidad
    cmp  ecx, 0
    je   rp_bajo_fin
    mov  esi, OFFSET registros
rp_bajo:
    cmp  DWORD PTR [esi + OFF_EXI], STOCK_BAJO
    ja   rp_sig
    call ImprimirProducto
    mov  hayBajo, 1
rp_sig:
    add  esi, REG_SIZE
    dec  ecx
    jnz  rp_bajo
rp_bajo_fin:
    cmp  hayBajo, 0
    jne  rp_fin
    mov  edx, OFFSET msgNingunoBajo
    call WriteString
    jmp  rp_fin

rp_desborda:
    mov  edx, OFFSET msgDesborde
    call WriteString
rp_fin:
    popad
    ret
Resumen ENDP

; ================================================================
; ARCHIVO
;   Formato: "INV2" (4 bytes) + cantidad (DWORD) + cantidad registros
;   de 48 bytes. Tamano esperado = 8 + cantidad * 48
; ================================================================

; ----------------------------------------------------------------
; Guardar
;   Escribe el bloque catMagic..registros en inventario.dat y verifica
;   que EAX (bytes escritos) coincida con los bytes solicitados.
;   Modifica: hArchivo, bytesPedidos, bytesEscritos, cambios
; ----------------------------------------------------------------
Guardar PROC
    pushad
    mov  edx, OFFSET nombreArchivo
    call CreateOutputFile           ; EAX = handle
    cmp  eax, INVALID_HANDLE_VALUE
    je   gu_err_crear
    mov  hArchivo, eax

    mov  eax, cantidad
    mov  ebx, REG_SIZE
    mul  ebx
    add  eax, HDR_SIZE
    mov  bytesPedidos, eax

    mov  eax, hArchivo
    mov  edx, OFFSET catMagic
    mov  ecx, bytesPedidos
    call WriteToFile                ; EAX = bytes escritos
    mov  bytesEscritos, eax
    mov  eax, hArchivo
    call CloseFile

    mov  eax, bytesEscritos
    cmp  eax, bytesPedidos
    jne  gu_err_escribir
    mov  cambios, 0
    mov  edx, OFFSET msgGuardado
    jmp  gu_msg
gu_err_crear:
    mov  edx, OFFSET msgErrCrear
    jmp  gu_msg
gu_err_escribir:
    mov  edx, OFFSET msgErrEscribir
gu_msg:
    call WriteString
    popad
    ret
Guardar ENDP

; ----------------------------------------------------------------
; ValidarArchivo
;   Valida cada registro leido: codigo ABC-123, nombre de 1 a 25
;   caracteres con 0 final, precio 0.01-9999.99, existencia 0-100
;   y codigos no repetidos.
;   Entrada:  ESI = primer registro, ECX = cuantos registros
;   Salida:   EAX = 1 si todos son validos, 0 si alguno no
;   Modifica: EAX, inicioRegs (conserva EBX, ECX, EDX, ESI, EDI)
; ----------------------------------------------------------------
ValidarArchivo PROC
    push ebx
    push ecx
    push edx
    push esi
    push edi
    mov  inicioRegs, esi
    cmp  ecx, 0
    je   va_ok
va_reg:
    call ValidarCodigo              ; ESI = registro actual
    cmp  eax, 0
    je   va_mal

    cmp  BYTE PTR [esi + OFF_NOM], 0
    je   va_mal                     ; nombre vacio
    xor  edx, edx
va_nom:
    cmp  BYTE PTR [esi + OFF_NOM + edx], 0
    je   va_nom_ok
    inc  edx
    cmp  edx, 25
    jbe  va_nom
    jmp  va_mal                     ; sin 0 final dentro de los 26 bytes
va_nom_ok:
    mov  ebx, [esi + OFF_PRE]
    cmp  ebx, 1
    jb   va_mal
    cmp  ebx, PRECIO_MAX
    ja   va_mal
    cmp  DWORD PTR [esi + OFF_EXI], MAX_EXIST
    ja   va_mal

    ; codigo repetido entre los registros anteriores
    mov  edi, inicioRegs
va_dup:
    cmp  edi, esi
    je   va_dup_ok
    call CodigosIguales             ; compara [ESI] contra [EDI]
    cmp  eax, 1
    je   va_mal
    add  edi, REG_SIZE
    jmp  va_dup
va_dup_ok:
    add  esi, REG_SIZE
    dec  ecx
    jnz  va_reg
va_ok:
    mov  eax, 1
    jmp  va_fin
va_mal:
    xor  eax, eax
va_fin:
    pop  edi
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    ret
ValidarArchivo ENDP

; ----------------------------------------------------------------
; LeerArchivo
;   Lee inventario.dat a bufArchivo y lo valida (tamano, firma,
;   cantidad y registros) sin tocar el catalogo.
;   Salida:   EAX = 1 si el archivo es valido, 0 si no (ya imprimio el error)
;   Modifica: EAX, hArchivo, bytesLeidos, bufArchivo
;             (conserva EBX, ECX, EDX, ESI)
; ----------------------------------------------------------------
LeerArchivo PROC
    push ebx
    push ecx
    push edx
    push esi
    mov  edx, OFFSET nombreArchivo
    call OpenInputFile              ; EAX = handle
    cmp  eax, INVALID_HANDLE_VALUE
    je   la_no_abre
    mov  hArchivo, eax

    mov  edx, OFFSET bufArchivo
    mov  ecx, 499                   ; capacidad del buffer - 1
    call ReadFromFile               ; EAX = bytes leidos, CF = error
    jc   la_err_leer
    mov  bytesLeidos, eax
    mov  eax, hArchivo
    call CloseFile

    cmp  bytesLeidos, HDR_SIZE
    jb   la_malo
    mov  eax, DWORD PTR bufArchivo
    cmp  eax, DWORD PTR catMagic
    jne  la_malo
    mov  eax, DWORD PTR [bufArchivo + 4]
    cmp  eax, MAX_PROD
    ja   la_malo
    mov  ebx, REG_SIZE
    mul  ebx
    add  eax, HDR_SIZE
    cmp  eax, bytesLeidos           ; el tamano debe coincidir exactamente
    jne  la_malo

    mov  esi, OFFSET bufArchivo
    add  esi, HDR_SIZE
    mov  ecx, DWORD PTR [bufArchivo + 4]
    call ValidarArchivo
    cmp  eax, 0
    je   la_malo
    mov  eax, 1
    jmp  la_fin

la_err_leer:
    mov  eax, hArchivo
    call CloseFile
    mov  edx, OFFSET msgErrLeer
    jmp  la_msg
la_no_abre:
    mov  edx, OFFSET msgNoArchivo
    jmp  la_msg
la_malo:
    mov  edx, OFFSET msgArchivoMal
la_msg:
    call WriteString
    xor  eax, eax
la_fin:
    pop  esi
    pop  edx
    pop  ecx
    pop  ebx
    ret
LeerArchivo ENDP

; ----------------------------------------------------------------
; Cargar
;   Reemplaza el catalogo solo si LeerArchivo valido el archivo.
;   Modifica: cantidad, registros, cambios (y lo que modifica LeerArchivo)
; ----------------------------------------------------------------
Cargar PROC
    pushad
    cmp  cambios, 0
    je   ca_leer
    mov  edx, OFFSET msgConfCargar
    call PedirTexto
    cmp  eax, 1
    jne  ca_fin
    mov  al, bufEntrada
    cmp  al, 'S'
    je   ca_leer
    cmp  al, 's'
    jne  ca_fin

ca_leer:
    call LeerArchivo
    cmp  eax, 0
    je   ca_fin

    mov  eax, DWORD PTR [bufArchivo + 4]
    mov  cantidad, eax
    mov  ebx, REG_SIZE
    mul  ebx
    mov  ecx, eax                   ; bytes de registros a copiar
    mov  esi, OFFSET bufArchivo
    add  esi, HDR_SIZE
    mov  edi, OFFSET registros
    cld
    rep  movsb

    mov  cambios, 0
    mov  edx, OFFSET msgCargado
    call WriteString
    mov  eax, cantidad
    call MostrarNumero
    call Crlf
ca_fin:
    popad
    ret
Cargar ENDP

END main
