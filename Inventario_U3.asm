; ================================================================
; PROYECTO: VENTAS E INVENTARIO EN ENSAMBLADOR (MASM x86 + Irvine32)
; VERSION DE LA UNIDAD 3: MACROS, PROCEDIMIENTOS Y USES
; NEGOCIO:  TIENDA DE VIDEOJUEGOS Y ACCESORIOS
; MATERIA:  LENGUAJES DE INTERFAZ
; ALUMNO: Beltran Momtoya Esau 
; DOCENTE:  Dr.Jose Luis Medina Jimenez 
; ================================================================
; Regla adicional del negocio: DESCUENTO POR CANTIDAD
;   5 a 9 unidades en una venta  -> 5% sobre el importe base
;   10 o mas unidades            -> 10% sobre el importe base
;   menos de 5 unidades          -> sin descuento
;   Las fracciones de centavo se descartan (division entera).
; Ademas, tras cada venta se avisa si la existencia queda en 5 o menos.
; ================================================================
; CONVENCIONES DE ESTA VERSION
;   - USES guarda y restaura los registros que el procedimiento
;     modifica. Los registros que entregan un resultado (EAX, y ESI en
;     BuscarCodigo y PedirYBuscar) NO se declaran en USES.
;   - Los procedimientos de captura devuelven EAX = 1 si todo salio bien
;     y EAX = 0 si hubo un rechazo (ya impreso).
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

; ================================================================
; MACROS
; ================================================================

; mMostrar: imprime una cadena terminada en 0.
;   Recibe:   msg = etiqueta de la cadena
;   Modifica: EDX
mMostrar MACRO msg
    mov  edx, OFFSET msg
    call WriteString
ENDM

; mMostrarYSalir: imprime un mensaje (de rechazo, de exito o de aviso) y salta al final
;   del procedimiento.
;   Recibe:   msg = etiqueta del mensaje, destino = etiqueta de salida
;   Modifica: EDX
mMostrarYSalir MACRO msg, destino
    mMostrar msg
    jmp  destino
ENDM

; mFueraDeRango: salta a destino si registro < minimo o registro > maximo
;   (comparacion sin signo). Sirve para letras, digitos y limites numericos.
;   Recibe:   registro, minimo, maximo, destino
;   Modifica: solo banderas
mFueraDeRango MACRO registro, minimo, maximo, destino
    cmp  registro, minimo
    jb   destino
    cmp  registro, maximo
    ja   destino
ENDM

; mSiFalla: llama a un procedimiento que devuelve EAX = 1/0 y salta a
;   destino si devolvio 0.
;   Recibe:   procedimiento, destino
;   Modifica: EAX y lo que modifique el procedimiento
mSiFalla MACRO procedimiento, destino
    call procedimiento
    cmp  eax, 0
    je   destino
ENDM

; mMostrarImporte: imprime un mensaje seguido de un importe en MXN y salto de linea.
;   Recibe:   msg = etiqueta del mensaje, valor = centavos (registro o variable)
;   Modifica: EAX, EDX
mMostrarImporte MACRO msg, valor
    mMostrar msg
    mov  eax, valor
    call MostrarPrecio
    call Crlf
ENDM

; mMostrarEntero: imprime un mensaje seguido de un entero y salto de linea.
;   Recibe:   msg = etiqueta del mensaje, valor = entero (registro o variable)
;   Modifica: EAX, EDX
mMostrarEntero MACRO msg, valor
    mMostrar msg
    mov  eax, valor
    call MostrarNumero
    call Crlf
ENDM

; mAvanzarRegistro: pasa ESI al siguiente registro y repite mientras queden (ECX).
;   Recibe:   etiqueta = inicio del ciclo
;   Modifica: ESI, ECX
mAvanzarRegistro MACRO etiqueta
    add  esi, REG_SIZE
    dec  ecx
    jnz  etiqueta
ENDM

; mSiVacio: si contador es 0, imprime msg y salta a destino.
;   Lleva una etiqueta interna, por eso usa LOCAL.
;   Recibe:   contador (registro o variable), msg, destino
;   Modifica: EDX (solo si el contador es 0)
mSiVacio MACRO contador, msg, destino
    LOCAL hay
    cmp  contador, 0
    jne  hay
    mMostrar msg
    jmp  destino
hay:
ENDM

; mOpcionMenu: si AL es la tecla indicada, llama al procedimiento y regresa al menu.
;   Lleva una etiqueta interna, por eso usa LOCAL.
;   Recibe:   caracter, procedimiento
;   Modifica: lo que modifique el procedimiento
mOpcionMenu MACRO caracter, procedimiento
    LOCAL siguiente
    cmp  al, caracter
    jne  siguiente
    call procedimiento
    jmp  menu_loop
siguiente:
ENDM

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
    mMostrar menuTxt
    mov  edx, OFFSET msgOpcion
    call PedirTexto
    cmp  eax, 1
    jne  opcion_mal
    mov  al, bufEntrada

    mOpcionMenu '1', Alta
    mOpcionMenu '2', MostrarInventario
    mOpcionMenu '3', BuscarProducto
    mOpcionMenu '4', Recibir
    mOpcionMenu '5', Vender
    mOpcionMenu '6', Resumen
    mOpcionMenu '7', Guardar
    mOpcionMenu '8', Cargar
    mOpcionMenu '9', Eliminar

    cmp  al, '0'
    jne  opcion_mal
    cmp  cambios, 0
    je   salir
    mov  edx, OFFSET msgSinGuardar
    call PedirSN
    cmp  eax, 1
    jne  menu_loop
salir:
    mMostrar msgAdios
    exit
opcion_mal:
    mMostrar msgOpcionMal
    jmp  menu_loop
main ENDP

; ================================================================
; ENTRADA DE DATOS
; ================================================================

; ----------------------------------------------------------------
; PedirTexto
;   Recibe:    EDX = direccion del mensaje a mostrar
;   Devuelve:  EAX = numero de caracteres capturados
;              bufEntrada = texto capturado, terminado en 0
;   Modifica:  EAX, bufEntrada
;   Conserva:  ECX, EDX (USES)
; ----------------------------------------------------------------
PedirTexto PROC USES ecx edx
    call WriteString
    mov  edx, OFFSET bufEntrada     ; EDX = buffer destino
    mov  ecx, 80                    ; ECX = maximo de caracteres
    call ReadString                 ; EAX = caracteres leidos
    ret
PedirTexto ENDP

; ----------------------------------------------------------------
; PedirSN  (NUEVO: sustituye dos bloques repetidos de confirmacion)
;   Recibe:    EDX = mensaje de la pregunta
;   Devuelve:  EAX = 1 si respondio S o s, 0 en otro caso
;   Modifica:  EAX, bufEntrada
;   Conserva:  ECX, EDX (los conserva PedirTexto). No necesita USES porque
;              el unico registro que modifica es EAX, que es la salida.
; ----------------------------------------------------------------
PedirSN PROC
    call PedirTexto
    cmp  eax, 1
    jne  sn_no
    mov  al, bufEntrada
    cmp  al, 'S'
    je   sn_si
    cmp  al, 's'
    jne  sn_no
sn_si:
    mov  eax, 1
    ret
sn_no:
    xor  eax, eax
    ret
PedirSN ENDP

; ----------------------------------------------------------------
; LeerEntero
;   Recibe:    ESI = cadena terminada en 0
;   Devuelve:  EAX = 1 si es un entero valido (valor en valorLeido), 0 si no
;   Modifica:  EAX, valorLeido
;   Conserva:  EBX, ECX, EDX, ESI (USES)
; ----------------------------------------------------------------
LeerEntero PROC USES ebx ecx edx esi
    xor  eax, eax
    cmp  BYTE PTR [esi], 0
    je   le_mal
    mov  ecx, 10
le_ciclo:
    movzx ebx, BYTE PTR [esi]
    cmp  ebx, 0
    je   le_ok
    mFueraDeRango ebx, '0', '9', le_mal
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
    ret
le_mal:
    xor  eax, eax
    ret
LeerEntero ENDP

; ----------------------------------------------------------------
; PedirEntero
;   Recibe:    EDX = mensaje
;   Devuelve:  EAX = 1 si es entero valido (valor en valorLeido), 0 si no
;   Modifica:  EAX, bufEntrada, valorLeido
;   Conserva:  ESI (USES)
; ----------------------------------------------------------------
PedirEntero PROC USES esi
    call PedirTexto
    mov  esi, OFFSET bufEntrada
    call LeerEntero
    ret
PedirEntero ENDP

; ----------------------------------------------------------------
; PedirCantidad  (NUEVO: sustituye dos bloques repetidos en Recibir y Vender)
;   Pide una cantidad entera mayor que cero.
;   Recibe:    EDX = mensaje
;   Devuelve:  EAX = 1 y valorLeido = cantidad; o EAX = 0 tras imprimir
;              el mensaje de cantidad invalida
;   Modifica:  EAX, bufEntrada, valorLeido
;   Conserva:  EDX (USES)
; ----------------------------------------------------------------
PedirCantidad PROC USES edx
    call PedirEntero
    cmp  eax, 0
    je   pcn_mal
    cmp  valorLeido, 0
    je   pcn_mal
    mov  eax, 1
    ret
pcn_mal:
    mMostrar msgCantMal
    xor  eax, eax
    ret
PedirCantidad ENDP

; ----------------------------------------------------------------
; LeerPrecio
;   Convierte "185.50", "12.5" o "300" a centavos enteros. Acepta pesos
;   enteros o punto con 1 o 2 decimales. Rechaza simbolos, separadores de
;   miles, un tercer decimal y precios fuera de 0.01 a 9999.99
;   Recibe:    ESI = cadena terminada en 0
;   Devuelve:  EAX = 1 si es valido (centavos en tmpPrecio), 0 si no
;   Modifica:  EAX, tmpPrecio
;   Conserva:  EBX, ECX, EDX, ESI (USES)
; ----------------------------------------------------------------
LeerPrecio PROC USES ebx ecx edx esi
    xor  eax, eax                   ; pesos acumulados
    xor  ecx, ecx                   ; digitos enteros leidos
lp_ent:
    movzx ebx, BYTE PTR [esi]
    cmp  ebx, 0
    je   lp_sin_dec
    cmp  ebx, '.'
    je   lp_punto
    mFueraDeRango ebx, '0', '9', lp_mal
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
    movzx ebx, BYTE PTR [esi]       ; primer decimal (obligatorio)
    mFueraDeRango ebx, '0', '9', lp_mal
    sub  ebx, '0'
    imul ebx, ebx, 10               ; decenas de centavo
    add  eax, ebx
    inc  esi
    movzx ebx, BYTE PTR [esi]       ; segundo decimal (opcional)
    cmp  ebx, 0
    je   lp_listo
    mFueraDeRango ebx, '0', '9', lp_mal
    sub  ebx, '0'
    add  eax, ebx
    inc  esi
    cmp  BYTE PTR [esi], 0          ; un tercer caracter se rechaza
    jne  lp_mal

lp_listo:
    mFueraDeRango eax, 1, PRECIO_MAX, lp_mal
    mov  tmpPrecio, eax
    mov  eax, 1
    ret
lp_mal:
    xor  eax, eax
    ret
LeerPrecio ENDP

; ----------------------------------------------------------------
; ValidarCodigo
;   Verifica el formato ABC-123 (3 mayusculas, guion, 3 digitos, fin)
;   Recibe:    ESI = cadena terminada en 0
;   Devuelve:  EAX = 1 si el formato es correcto, 0 si no
;   Modifica:  EAX
;   Conserva:  EBX, ECX, ESI (USES)
; ----------------------------------------------------------------
ValidarCodigo PROC USES ebx ecx esi
    xor  eax, eax
    mov  ecx, 3
vc_letras:
    movzx ebx, BYTE PTR [esi]
    mFueraDeRango ebx, 'A', 'Z', vc_fin
    inc  esi
    loop vc_letras
    cmp  BYTE PTR [esi], '-'
    jne  vc_fin
    inc  esi
    mov  ecx, 3
vc_digitos:
    movzx ebx, BYTE PTR [esi]
    mFueraDeRango ebx, '0', '9', vc_fin
    inc  esi
    loop vc_digitos
    cmp  BYTE PTR [esi], 0
    jne  vc_fin
    mov  eax, 1
vc_fin:
    ret
ValidarCodigo ENDP

; ----------------------------------------------------------------
; PedirCodigo
;   Pide un codigo, valida su formato y lo deja en tmpCodigo.
;   Recibe:    nada
;   Devuelve:  EAX = 1 si es valido (codigo en tmpCodigo); si no, imprime
;              el error y EAX = 0
;   Modifica:  EAX, bufEntrada, tmpCodigo
;   Conserva:  EDX, ESI, EDI (USES)
; ----------------------------------------------------------------
PedirCodigo PROC USES edx esi edi
    mov  edx, OFFSET msgCodigo
    call PedirTexto
    mov  esi, OFFSET bufEntrada
    call ValidarCodigo
    cmp  eax, 0
    je   pc_mal
    mov  edi, OFFSET tmpCodigo
    call CopiarCadena
    mov  eax, 1
    ret
pc_mal:
    mMostrar msgCodigoMal
    xor  eax, eax
    ret
PedirCodigo ENDP

; ----------------------------------------------------------------
; PedirNombre  (NUEVO: separado de Alta)
;   Recibe:    nada
;   Devuelve:  EAX = 1 y tmpNombre (1 a 25 caracteres); o EAX = 0 tras
;              imprimir el error
;   Modifica:  EAX, bufEntrada, tmpNombre
;   Conserva:  EDX, ESI, EDI (USES)
; ----------------------------------------------------------------
PedirNombre PROC USES edx esi edi
    mov  edx, OFFSET msgNombre
    call PedirTexto
    mFueraDeRango eax, 1, 25, pn_mal
    mov  esi, OFFSET bufEntrada
    mov  edi, OFFSET tmpNombre
    call CopiarCadena
    mov  eax, 1
    ret
pn_mal:
    mMostrar msgNombreMal
    xor  eax, eax
    ret
PedirNombre ENDP

; ----------------------------------------------------------------
; PedirPrecio  (NUEVO: separado de Alta)
;   Recibe:    nada
;   Devuelve:  EAX = 1 y tmpPrecio en centavos; o EAX = 0 tras imprimir el error
;   Modifica:  EAX, bufEntrada, tmpPrecio
;   Conserva:  EDX, ESI (USES)
; ----------------------------------------------------------------
PedirPrecio PROC USES edx esi
    mov  edx, OFFSET msgPrecio
    call PedirTexto
    mov  esi, OFFSET bufEntrada
    call LeerPrecio
    cmp  eax, 0
    jne  pp_fin
    mMostrar msgPrecioMal
    xor  eax, eax
pp_fin:
    ret
PedirPrecio ENDP

; ----------------------------------------------------------------
; PedirExistencia  (NUEVO: separado de Alta)
;   Recibe:    nada
;   Devuelve:  EAX = 1 y tmpExist (0 a 100); o EAX = 0 tras imprimir el error
;   Modifica:  EAX, bufEntrada, valorLeido, tmpExist
;   Conserva:  EDX (USES)
; ----------------------------------------------------------------
PedirExistencia PROC USES edx
    mov  edx, OFFSET msgExistencia
    call PedirEntero
    cmp  eax, 0
    je   pe_mal
    mov  eax, valorLeido
    cmp  eax, MAX_EXIST
    ja   pe_mal
    mov  tmpExist, eax
    mov  eax, 1
    ret
pe_mal:
    mMostrar msgExistMal
    xor  eax, eax
    ret
PedirExistencia ENDP

; ================================================================
; BUSQUEDA
; ================================================================

; ----------------------------------------------------------------
; CodigosIguales
;   Compara los 7 caracteres de dos codigos
;   Recibe:    ESI = primer codigo, EDI = segundo codigo
;   Devuelve:  EAX = 1 si son iguales, 0 si no
;   Modifica:  EAX
;   Conserva:  EBX, ECX, ESI, EDI (USES)
; ----------------------------------------------------------------
CodigosIguales PROC USES ebx ecx esi edi
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
    ret
ci_no:
    xor  eax, eax
    ret
CodigosIguales ENDP

; ----------------------------------------------------------------
; BuscarCodigo
;   Recorre el catalogo con ESI buscando tmpCodigo
;   Recibe:    tmpCodigo = codigo a buscar, cantidad = productos registrados
;   Devuelve:  EAX = 1 y ESI = inicio del registro si lo encuentra;
;              EAX = 0 si no existe (ESI sin significado)
;   Modifica:  EAX, ESI (son salidas, por eso no van en USES)
;   Conserva:  ECX, EDI (USES)
; ----------------------------------------------------------------
BuscarCodigo PROC USES ecx edi
    mov  esi, OFFSET registros
    mov  edi, OFFSET tmpCodigo
    mov  ecx, cantidad
    cmp  ecx, 0
    je   bc_no
bc_loop:
    call CodigosIguales             ; compara [ESI] contra [EDI]
    cmp  eax, 1
    je   bc_fin
    mAvanzarRegistro bc_loop
bc_no:
    xor  eax, eax
bc_fin:
    ret
BuscarCodigo ENDP

; ----------------------------------------------------------------
; PedirYBuscar
;   Pide un codigo y lo busca. Imprime el error si es invalido o no existe.
;   Recibe:    nada
;   Devuelve:  EAX = 1 y ESI = registro si existe, 0 si no
;   Modifica:  EAX, ESI (salidas), bufEntrada, tmpCodigo
;   Conserva:  EDX (USES)
; ----------------------------------------------------------------
PedirYBuscar PROC USES edx
    mSiFalla PedirCodigo, pyb_fin   ; si falla, EAX ya es 0
    call BuscarCodigo
    cmp  eax, 1
    je   pyb_fin
    mMostrar msgNoExiste
    xor  eax, eax
pyb_fin:
    ret
PedirYBuscar ENDP

; ================================================================
; UTILIDADES DE CADENAS Y NUMEROS
; ================================================================

; ----------------------------------------------------------------
; CopiarCadena
;   Recibe:    ESI = origen, EDI = destino (el destino debe tener espacio)
;   Devuelve:  cadena copiada con su 0 final
;   Modifica:  solo la memoria destino
;   Conserva:  EAX, ESI, EDI (USES)
; ----------------------------------------------------------------
CopiarCadena PROC USES eax esi edi
cc_loop:
    mov  al, [esi]
    mov  [edi], al
    inc  esi
    inc  edi
    cmp  al, 0
    jne  cc_loop
    ret
CopiarCadena ENDP

; ----------------------------------------------------------------
; EnteroACadena
;   Convierte EAX a digitos ASCII. Divide entre 10: cada residuo es un
;   digito (se apila) y al sacarlos de la pila quedan en el orden correcto.
;   Recibe:    EAX = numero, EDI = destino
;   Devuelve:  digitos escritos en [EDI] con 0 final
;   Modifica:  EDI (queda en el 0 final, para seguir concatenando; es una
;              salida, por eso no va en USES) y la memoria destino
;   Conserva:  EAX, EBX, ECX, EDX (USES)
; ----------------------------------------------------------------
EnteroACadena PROC USES eax ebx ecx edx
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
    ret
EnteroACadena ENDP

; ----------------------------------------------------------------
; MostrarNumero
;   Recibe:    EAX = numero
;   Devuelve:  imprime el numero en decimal
;   Modifica:  bufNum
;   Conserva:  EDX, EDI (USES)
; ----------------------------------------------------------------
MostrarNumero PROC USES edx edi
    mov  edi, OFFSET bufNum
    call EnteroACadena
    mMostrar bufNum
    ret
MostrarNumero ENDP

; ----------------------------------------------------------------
; MostrarPrecio
;   Imprime centavos como "$123.45 MXN". DIV entre 100 separa pesos (EAX)
;   y centavos (EDX); otro DIV entre 10 da decenas y unidades, asi un
;   residuo de 5 se muestra como 05.
;   Recibe:    EAX = importe en centavos
;   Devuelve:  imprime el importe con dos decimales y la etiqueta MXN
;   Modifica:  bufNum
;   Conserva:  EAX, EBX, EDX, EDI (USES)
; ----------------------------------------------------------------
MostrarPrecio PROC USES eax ebx edx edi
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
    mMostrar bufNum
    mMostrar txtMXN
    ret
MostrarPrecio ENDP

; ----------------------------------------------------------------
; ImprimirProducto
;   Recibe:    ESI = inicio de un registro
;   Devuelve:  imprime una linea con codigo, nombre, precio, existencia y vendidas
;   Modifica:  bufNum
;   Conserva:  EAX, EDX (USES), ESI no se modifica
; ----------------------------------------------------------------
ImprimirProducto PROC USES eax edx
    mMostrar txtCodigo
    mov  edx, esi                   ; el codigo esta al inicio del registro
    call WriteString
    mMostrar txtNombre
    lea  edx, [esi + OFF_NOM]
    call WriteString
    mMostrar txtPrecio
    mov  eax, [esi + OFF_PRE]
    call MostrarPrecio
    mMostrar txtExist
    mov  eax, [esi + OFF_EXI]
    call MostrarNumero
    mMostrar txtVend
    mov  eax, [esi + OFF_VEN]
    call MostrarNumero
    call Crlf
    ret
ImprimirProducto ENDP

; ================================================================
; CALCULO DE IMPORTES
; ================================================================

; ----------------------------------------------------------------
; PorcentajeDescuento  (NUEVO: aisla la regla del negocio)
;   Recibe:    EAX = unidades de la venta
;   Devuelve:  EAX = porcentaje de descuento (0, 5 o 10)
;   Modifica:  EAX (entrada y salida, por eso no usa USES)
; ----------------------------------------------------------------
PorcentajeDescuento PROC
    cmp  eax, 10
    jae  pd_10
    cmp  eax, 5
    jae  pd_5
    xor  eax, eax
    ret
pd_10:
    mov  eax, 10
    ret
pd_5:
    mov  eax, 5
    ret
PorcentajeDescuento ENDP

; ----------------------------------------------------------------
; CalcularVenta  (NUEVO: separado de Vender; no modifica ningun dato del catalogo)
;   Calcula importe base, descuento por cantidad y total.
;   Recibe:    ESI = registro del producto, cantVenta = unidades
;   Devuelve:  EAX = 1 si el calculo es correcto, 0 si hubo desbordamiento;
;              pctDesc, ventaBase, ventaDesc y ventaFinal (centavos)
;   Modifica:  EAX, pctDesc, ventaBase, ventaDesc, ventaFinal
;   Conserva:  EBX, EDX (USES), ESI no se modifica
; ----------------------------------------------------------------
CalcularVenta PROC USES ebx edx
    mov  eax, [esi + OFF_PRE]
    mul  cantVenta                  ; precio * cantidad
    jc   cv_mal
    mov  ventaBase, eax
    mov  eax, cantVenta
    call PorcentajeDescuento
    mov  pctDesc, eax
    mov  eax, ventaBase
    mul  pctDesc
    jc   cv_mal
    xor  edx, edx
    mov  ebx, 100
    div  ebx                        ; EAX = descuento (fraccion de centavo descartada)
    mov  ventaDesc, eax
    mov  eax, ventaBase
    sub  eax, ventaDesc
    mov  ventaFinal, eax
    mov  eax, 1
    ret
cv_mal:
    xor  eax, eax
    ret
CalcularVenta ENDP

; ================================================================
; OPERACIONES DEL MENU
; ================================================================

; ----------------------------------------------------------------
; AgregarRegistro  (NUEVO: separado de Alta)
;   Escribe el producto de tmpCodigo/tmpNombre/tmpPrecio/tmpExist en el
;   siguiente registro libre.
;   Recibe:    variables tmp* ya validadas
;   Devuelve:  catalogo con un producto mas
;   Modifica:  registros, cantidad, cambios
;   Conserva:  EAX, EBX, ECX, EDX, ESI, EDI (USES)
; ----------------------------------------------------------------
AgregarRegistro PROC USES eax ebx ecx edx esi edi
    mov  eax, cantidad              ; direccion = registros + cantidad * REG_SIZE
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
    ret
AgregarRegistro ENDP

; ----------------------------------------------------------------
; Alta
;   Registra un producto. Todo se valida antes de escribir en el catalogo,
;   asi un rechazo conserva los datos anteriores.
;   Modifica:  catalogo, cantidad, cambios, tmp*, bufEntrada
;   Conserva:  EAX, EDX, ESI (USES)
; ----------------------------------------------------------------
Alta PROC USES eax edx esi
    cmp  cantidad, MAX_PROD
    jae  al_lleno
    mSiFalla PedirCodigo, al_fin    ; PedirCodigo ya imprimio el error
    call BuscarCodigo
    cmp  eax, 1
    je   al_duplicado
    mSiFalla PedirNombre, al_fin
    mSiFalla PedirPrecio, al_fin
    mSiFalla PedirExistencia, al_fin
    call AgregarRegistro
    mMostrarYSalir msgAltaOk, al_fin
al_lleno:
    mMostrarYSalir msgLleno, al_fin
al_duplicado:
    mMostrarYSalir msgDuplicado, al_fin
al_fin:
    ret
Alta ENDP

; ----------------------------------------------------------------
; MostrarInventario
;   Recorre todos los registros con ESI e imprime cada producto.
;   Modifica:  bufNum
;   Conserva:  ECX, EDX, ESI (USES)
; ----------------------------------------------------------------
MostrarInventario PROC USES ecx edx esi
    mov  ecx, cantidad
    mSiVacio ecx, msgNoHay, mi_fin
    mMostrar msgEncabezado
    mov  esi, OFFSET registros
mi_loop:
    call ImprimirProducto
    mAvanzarRegistro mi_loop
mi_fin:
    ret
MostrarInventario ENDP

; ----------------------------------------------------------------
; BuscarProducto
;   Pide un codigo e imprime el producto si existe.
;   Modifica:  bufEntrada, tmpCodigo, bufNum
;   Conserva:  EAX, ESI (USES)
; ----------------------------------------------------------------
BuscarProducto PROC USES eax esi
    mSiFalla PedirYBuscar, bp_fin
    call ImprimirProducto
bp_fin:
    ret
BuscarProducto ENDP

; ----------------------------------------------------------------
; Recibir
;   Suma unidades a un producto sin pasar de MAX_EXIST (100).
;   Modifica:  existencia del producto, cambios, bufEntrada, valorLeido
;   Conserva:  EAX, EDX, ESI (USES)
; ----------------------------------------------------------------
Recibir PROC USES eax edx esi
    mSiFalla PedirYBuscar, rc_fin
    mov  edx, OFFSET msgCantRecibir
    mSiFalla PedirCantidad, rc_fin  ; PedirCantidad ya imprimio el error
    mov  eax, valorLeido
    add  eax, [esi + OFF_EXI]
    jc   rc_excede
    cmp  eax, MAX_EXIST
    ja   rc_excede
    mov  [esi + OFF_EXI], eax       ; solo aqui se modifica el registro
    mov  cambios, 1
    mMostrarEntero msgRecibidoOk, eax
    jmp  rc_fin
rc_excede:
    mMostrarYSalir msgExcede, rc_fin
rc_fin:
    ret
Recibir ENDP

; ----------------------------------------------------------------
; Vender
;   Valida existencias y calcula el importe (CalcularVenta). Existencia,
;   vendidas e ingresos se actualizan hasta el final, cuando ya no hay
;   posibilidad de rechazo.
;   Modifica:  existencia y vendidas del producto, ingresos, cambios,
;              cantVenta y las variables de CalcularVenta
;   Conserva:  EAX, EDX, ESI (USES)
; ----------------------------------------------------------------
Vender PROC USES eax edx esi
    mSiFalla PedirYBuscar, ve_fin
    mov  edx, OFFSET msgCantVender
    mSiFalla PedirCantidad, ve_fin
    mov  eax, valorLeido
    mov  cantVenta, eax
    cmp  eax, [esi + OFF_EXI]
    ja   ve_sin_stock
    mSiFalla CalcularVenta, ve_desborda
    mov  eax, ventaFinal
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

    mMostrar msgVentaOk
    mMostrarImporte msgBase, ventaBase
    cmp  pctDesc, 0
    je   ve_sin_desc
    mMostrar msgDesc1
    mov  eax, pctDesc
    call MostrarNumero
    mMostrarImporte msgDesc2, ventaDesc
    jmp  ve_total
ve_sin_desc:
    mMostrar msgSinDesc
ve_total:
    mMostrarImporte msgTotal, ventaFinal
    cmp  DWORD PTR [esi + OFF_EXI], STOCK_BAJO
    ja   ve_fin
    mMostrarYSalir msgAlertaStock, ve_fin
ve_sin_stock:
    mMostrarYSalir msgSinStock, ve_fin
ve_desborda:
    mMostrarYSalir msgDesborde, ve_fin
ve_fin:
    ret
Vender ENDP

; ----------------------------------------------------------------
; Eliminar
;   Borra un producto y recorre los siguientes para no dejar huecos.
;   Modifica:  registros, cantidad, cambios, bufEntrada, tmpCodigo
;   Conserva:  EAX, EBX, ECX, EDX, ESI, EDI (USES)
; ----------------------------------------------------------------
Eliminar PROC USES eax ebx ecx edx esi edi
    mSiFalla PedirYBuscar, el_fin
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
    mMostrar msgBajaOk
el_fin:
    ret
Eliminar ENDP

; ----------------------------------------------------------------
; Resumen
;   Unidades disponibles, valor del inventario (suma de precio x
;   existencia), ingresos de la sesion y productos con existencia minima.
;   Modifica:  hayBajo, bufNum
;   Conserva:  EAX, EBX, ECX, EDX, ESI, EDI (USES)
; ----------------------------------------------------------------
Resumen PROC USES eax ebx ecx edx esi edi
    mMostrar msgRepTitulo
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
    mAvanzarRegistro rp_loop

rp_mostrar:
    mMostrarEntero msgResUnid, ebx
    mMostrarImporte msgResValor, edi
    mMostrarImporte msgResIngr, ingresos

    mMostrar msgBajoTitulo          ; productos con existencia minima
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
    mAvanzarRegistro rp_bajo
rp_bajo_fin:
    mSiVacio hayBajo, msgNingunoBajo, rp_fin
    jmp  rp_fin
rp_desborda:
    mMostrarYSalir msgDesborde, rp_fin
rp_fin:
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
;   Modifica:  hArchivo, bytesPedidos, bytesEscritos, cambios
;   Conserva:  EAX, EBX, ECX, EDX (USES)
; ----------------------------------------------------------------
Guardar PROC USES eax ebx ecx edx
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
    mMostrarYSalir msgGuardado, gu_fin
gu_err_crear:
    mMostrarYSalir msgErrCrear, gu_fin
gu_err_escribir:
    mMostrarYSalir msgErrEscribir, gu_fin
gu_fin:
    ret
Guardar ENDP

; ----------------------------------------------------------------
; ValidarRegistro  (NUEVO: separado de ValidarArchivo)
;   Valida un registro leido del archivo: codigo ABC-123, nombre de 1 a
;   25 caracteres con 0 final, precio 0.01-9999.99 y existencia 0-100.
;   Recibe:    ESI = inicio del registro
;   Devuelve:  EAX = 1 si es valido, 0 si no
;   Modifica:  EAX
;   Conserva:  EBX, EDX (USES), ESI no se modifica
; ----------------------------------------------------------------
ValidarRegistro PROC USES ebx edx
    call ValidarCodigo              ; si falla, EAX ya es 0
    cmp  eax, 0
    je   vr_fin
    cmp  BYTE PTR [esi + OFF_NOM], 0
    je   vr_mal                     ; nombre vacio
    xor  edx, edx
vr_nom:
    cmp  BYTE PTR [esi + OFF_NOM + edx], 0
    je   vr_nom_ok
    inc  edx
    cmp  edx, 25
    jbe  vr_nom
    jmp  vr_mal                     ; sin 0 final dentro de los 26 bytes
vr_nom_ok:
    mov  ebx, [esi + OFF_PRE]
    mFueraDeRango ebx, 1, PRECIO_MAX, vr_mal
    cmp  DWORD PTR [esi + OFF_EXI], MAX_EXIST
    ja   vr_mal
    mov  eax, 1
    ret
vr_mal:
    xor  eax, eax
vr_fin:
    ret
ValidarRegistro ENDP

; ----------------------------------------------------------------
; ValidarArchivo
;   Valida todos los registros leidos y que no haya codigos repetidos.
;   Recibe:    ESI = primer registro, ECX = cuantos registros
;   Devuelve:  EAX = 1 si todos son validos, 0 si alguno no
;   Modifica:  EAX, inicioRegs
;   Conserva:  ECX, ESI, EDI (USES)
; ----------------------------------------------------------------
ValidarArchivo PROC USES ecx esi edi
    mov  inicioRegs, esi
    cmp  ecx, 0
    je   va_ok
va_reg:
    mSiFalla ValidarRegistro, va_fin
    mov  edi, inicioRegs            ; EDI recorre los registros anteriores
va_dup:
    cmp  edi, esi
    je   va_dup_ok
    call CodigosIguales             ; compara [ESI] contra [EDI]
    cmp  eax, 1
    je   va_mal
    add  edi, REG_SIZE
    jmp  va_dup
va_dup_ok:
    mAvanzarRegistro va_reg
va_ok:
    mov  eax, 1
    ret
va_mal:
    xor  eax, eax
va_fin:
    ret
ValidarArchivo ENDP

; ----------------------------------------------------------------
; ValidarCabecera  (NUEVO: separado de LeerArchivo)
;   Comprueba bytes leidos, firma, cantidad y tamano exacto del archivo.
;   Recibe:    bufArchivo y bytesLeidos
;   Devuelve:  EAX = 1 si la cabecera y el tamano son correctos, 0 si no
;   Modifica:  EAX
;   Conserva:  EBX, EDX (USES)
; ----------------------------------------------------------------
ValidarCabecera PROC USES ebx edx
    cmp  bytesLeidos, HDR_SIZE
    jb   vh_mal
    mov  eax, DWORD PTR bufArchivo
    cmp  eax, DWORD PTR catMagic
    jne  vh_mal
    mov  eax, DWORD PTR [bufArchivo + 4]
    cmp  eax, MAX_PROD
    ja   vh_mal
    mov  ebx, REG_SIZE
    mul  ebx
    add  eax, HDR_SIZE
    cmp  eax, bytesLeidos           ; el tamano debe coincidir exactamente
    jne  vh_mal
    mov  eax, 1
    ret
vh_mal:
    xor  eax, eax
    ret
ValidarCabecera ENDP

; ----------------------------------------------------------------
; LeerArchivo
;   Lee inventario.dat a bufArchivo y lo valida sin tocar el catalogo.
;   Recibe:    nada
;   Devuelve:  EAX = 1 si el archivo es valido, 0 si no (ya imprimio el error)
;   Modifica:  EAX, hArchivo, bytesLeidos, bufArchivo
;   Conserva:  ECX, EDX, ESI (USES)
; ----------------------------------------------------------------
LeerArchivo PROC USES ecx edx esi
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
    mSiFalla ValidarCabecera, la_malo
    mov  esi, OFFSET bufArchivo
    add  esi, HDR_SIZE
    mov  ecx, DWORD PTR [bufArchivo + 4]
    mSiFalla ValidarArchivo, la_malo
    mov  eax, 1
    ret
la_err_leer:
    mov  eax, hArchivo
    call CloseFile
    mMostrarYSalir msgErrLeer, la_fallo
la_no_abre:
    mMostrarYSalir msgNoArchivo, la_fallo
la_malo:
    mMostrar msgArchivoMal
la_fallo:
    xor  eax, eax
    ret
LeerArchivo ENDP

; ----------------------------------------------------------------
; Cargar
;   Reemplaza el catalogo solo si LeerArchivo valido el archivo.
;   Modifica:  cantidad, registros, cambios (y lo que modifica LeerArchivo)
;   Conserva:  EAX, EBX, ECX, EDX, ESI, EDI (USES)
; ----------------------------------------------------------------
Cargar PROC USES eax ebx ecx edx esi edi
    cmp  cambios, 0
    je   ca_leer
    mov  edx, OFFSET msgConfCargar
    call PedirSN
    cmp  eax, 1
    jne  ca_fin
ca_leer:
    mSiFalla LeerArchivo, ca_fin
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
    mMostrarEntero msgCargado, cantidad
ca_fin:
    ret
Cargar ENDP

END main
