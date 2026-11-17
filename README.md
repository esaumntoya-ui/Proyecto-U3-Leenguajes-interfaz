# Proyecto-U3-Leenguajes-interfaz
# Sistema de ventas e inventario en ensamblador (MASM x86 + Irvine32)

**Negocio:** tienda de videojuegos y accesorios

Sistema de consola que registra hasta 10 productos, controla su existencia,
registra ventas con descuento por cantidad y guarda o carga el catalogo en un archivo.

## Contenido del repositorio

| Ruta | Descripcion |
| --- | --- |
| `src/Inventario.asm` | Version de la Unidad 2 (sin macros ni USES) |
| `src/Inventario_U3.asm` | **Version de la Unidad 3**: macros, procedimientos nuevos y USES |
| `data/inventario.dat` | Archivo de inventario de prueba con 3 productos |
| `docs/` | Informe actualizado (incluye la seccion "Version de la Unidad 3") |
| Solucion de Visual Studio | Archivos `.sln` y `.vcxproj` del proyecto |

> Solo un archivo con `main` puede compilarse a la vez. En el proyecto de Visual Studio
> debe estar activo **`Inventario_U3.asm`**; `Inventario.asm` se conserva como referencia
> de la Unidad 2 y queda excluido de la compilacion (ver paso 5).

## Requisitos

- Visual Studio con la carga de trabajo *Desarrollo para el escritorio con C++* (incluye MASM).
- Biblioteca **Irvine32** instalada (por ejemplo en `C:\Irvine`).
- Plataforma de compilacion **x86 (Win32)**.

## Instrucciones de compilacion (Visual Studio)

1. Abre la solucion (`.sln`) o crea un **proyecto vacio de C++** y agregalo a una solucion nueva.
2. Activa MASM: clic derecho en el proyecto, *Dependencias de compilacion*, *Personalizaciones de compilacion*, marca **masm(.targets, .props)**.
3. Agrega `src/Inventario_U3.asm` al proyecto (*Agregar, Elemento existente*).
4. Configura el proyecto (configuracion *Debug*, plataforma **x86**) con las rutas de tu instalacion de Irvine32; las que siguen son un ejemplo con `C:\Irvine`:
   - *Microsoft Macro Assembler, General, Include Paths*: `C:\Irvine`
   - *Vinculador, General, Directorios de bibliotecas adicionales*: `C:\Irvine`
   - *Vinculador, Entrada, Dependencias adicionales*: `Irvine32.lib;kernel32.lib;user32.lib`
   - *Vinculador, Sistema, Subsistema*: **Console**
   - *Vinculador, Avanzadas, Imagen con controladores de excepciones seguros (SAFESEH)*: **No**
5. Si el proyecto tambien incluye `Inventario.asm`: clic derecho sobre ese archivo, *Propiedades*, *General*, *Excluido de la compilacion*: **Si**.
6. Compila con *Compilar, Recompilar solucion* y ejecuta con **Ctrl+F5**.

Si ya tienes un proyecto de Visual Studio para Irvine32 que compila otros programas, basta con
agregar el `.asm` y repetir los pasos 5 y 6.

## Archivo de inventario de prueba

`data/inventario.dat` se abre desde el **directorio de trabajo** del programa. Con Visual Studio
(*Depurar, Iniciar sin depurar*) es la carpeta del proyecto (`$(ProjectDir)`). Copia ahi el archivo
y usa la opcion **8. Cargar inventario**. Contiene:

| Codigo | Nombre | Precio | Existencia |
| --- | --- | --- | --- |
| VID-001 | Control inalambrico | $849.00 MXN | 12 |
| VID-002 | Cable HDMI 2m | $129.50 MXN | 30 |
| VID-003 | Tarjeta de memoria 64GB | $189.99 MXN | 4 |

Formato: firma `INV2` (4 bytes), cantidad de productos (DWORD) y 48 bytes por producto.
Tamano esperado = 8 + cantidad x 48 (152 bytes en el archivo de prueba).

## Uso rapido

Menu: 1 Registrar, 2 Mostrar inventario, 3 Buscar por codigo, 4 Recibir mercancia, 5 Vender,
6 Resumen, 7 Guardar, 8 Cargar, 9 Eliminar, 0 Salir.

- Codigo con formato `ABC-123`.
- Precio en pesos con 0, 1 o 2 decimales (por ejemplo `185.50`).
- Regla adicional: descuento por cantidad (5 % de 5 a 9 unidades, 10 % desde 10 unidades) y aviso
  de existencia minima (5 o menos).

## Version de la Unidad 3

Mejoras respecto a la Unidad 2: 9 macros (dos con `LOCAL`), 10 procedimientos nuevos y `USES`
en 33 de 36 procedimientos. Las lineas de codigo fuente (sin vacias ni comentarios) pasan de
1068 a 889. El detalle esta en el informe de `docs/`.
