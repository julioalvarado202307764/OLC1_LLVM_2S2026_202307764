# Compilador OLC1 con LLVM IR y firmware para Raspberry Pi Pico (RP2040)

**Universidad de San Carlos de Guatemala · Facultad de Ingeniería · Ingeniería en Ciencias y Sistemas**  
**Curso:** Organización de Lenguajes y Compiladores 1 (OLC1), segundo semestre de 2026  
**Proyecto/repositorio:** `OLC1_LLVM_2S2026_202307764`  
**Carné:** `202307764`  
**Arquitectura asignada:** Raspberry Pi Pico original, microcontrolador RP2040, procesador ARM Cortex-M0+ (Thumb/ARMv6-M)  
**Estado documentado:** 30 de octubre de 2026

> **Alcance y evidencia.** Este documento describe el código fuente proporcionado del compilador y los cambios de integración aplicados mediante `integrar_pico_olc1.ps1` y `habilitar_usb_olc1.ps1`, contrastados con las salidas de pruebas y compilación compartidas el 30/10/2026. Los scripts se aplicaron satisfactoriamente en Windows y se confirmaron 117/117 pruebas después de habilitar USB. El firmware UART y el USB se generaron y examinaron mediante `picotool`; **ninguno se ha ejecutado físicamente en la Raspberry Pi Pico**. No se dispone de un volcado posterior de todos los archivos del directorio local del estudiante; cualquier cambio manual adicional que no figure en los materiales examinados no puede certificarse aquí.

---

## 1. Descripción general y objetivos

El proyecto implementa en **C** un compilador para un lenguaje pequeño de declaraciones y expresiones aritméticas. Usa **Flex** para reconocer tokens, **Bison** para analizar la gramática, un **árbol de sintaxis abstracta (AST)** propio, una tabla de símbolos y análisis semántico con tipos. Tras comprobar el programa, produce **LLVM IR** (`.ll`). El backend de LLVM convierte ese IR en ensamblador ARM Thumb para **Cortex-M0+**. Finalmente, el **Pico SDK** y un runtime escrito en C proporcionan el punto de entrada y las funciones de impresión necesarias para enlazar un firmware de la Raspberry Pi Pico en los formatos **ELF, BIN y UF2**.

Existen **dos modos de salida LLVM**, sin cambiar la sintaxis del lenguaje:

- **Modo normal:** genera `define i32 @main()`; preserva la interfaz anterior y las pruebas IR/OB.
- **Modo Pico (`--target pico`):** genera `define i32 @olc_program()`; su `main()` se implementa en `targets/pico/olc_entry.c`.

En Pico existen **dos configuraciones de compilación** del mismo programa: **UART0** (variante de respaldo) y **USB CDC** (consola serie USB). Los archivos UF2 están preparados para una futura carga mediante BOOTSEL; su comportamiento en la placa sigue pendiente de prueba física.

## 2. Arquitectura y flujo de compilación

```text
Programa .olc
    │
    ▼
Flex (src/lexer.l) → tokens y posiciones
    │
    ▼
Bison (src/parser.y) → AST propio
    │
    ▼
Análisis semántico (src/semantic.c + src/symtab.c)
    │    └─ verifica variables y tipos; ante errores detiene la generación
    ▼
Generador (src/codegen.c) → LLVM IR (.ll)
    │
    ├─ modo normal: define i32 @main()
    │
    └─ --target pico: define i32 @olc_program()
                               │
                               ▼
             llvm-as / opt (verificación)
                               │
                               ▼
             llc -mtriple=thumbv6m-none-eabi
                 -mcpu=cortex-m0plus -filetype=asm
                               │
                               ▼
                    build/pico_program.S
                               │
                               ├───────────────┐
                               ▼               ▼
                  CMake/Pico SDK         Código runtime C
                  + toolchain ARM       + entrada main()
                               └───────┬───────┘
                                       ▼
                                 olc_pico.elf
                                       │
                              pico_add_extra_outputs
                                       ▼
                         olc_pico.bin / olc_pico.uf2
                                       │
                                       ▼
                   BOOTSEL / RPI-RP2 (carga no probada)
```

La construcción con LLVM **no ejecuta** el programa en el microcontrolador. Generar un objeto ARM, enlazar un ELF, producir un UF2 y observar el comportamiento real de una placa son verificaciones distintas.

## 3. Estructura del proyecto

La raíz local utilizada en las pruebas de Windows fue `C:\Users\daish\Documents\U\LLVM`. Esa ruta es **un ejemplo del equipo de desarrollo**, no una dependencia fija del código.

```text
LLVM/
├── .gitignore
├── DOCUMENTACION.md                  # documentación anterior en el ZIP recibido
├── DOCUMENTACIÓN.md                  # nombre de esta versión actualizada
├── build.ps1                         # construcción del compilador y drivers de pruebas
├── integrar_pico_olc1.ps1            # script aplicado para integrar Pico, si se conserva
├── habilitar_usb_olc1.ps1            # script aplicado para habilitar USB, si se conserva
├── src/
│   ├── main.c                        # CLI, análisis y selección del modo IR
│   ├── lexer.l                       # especificación Flex
│   ├── parser.y                      # gramática Bison
│   ├── ast.c, ast.h                   # AST
│   ├── symtab.c, symtab.h             # tabla de símbolos
│   ├── semantic.c, semantic.h         # comprobaciones semánticas
│   ├── tipos.h                       # tipos del lenguaje
│   ├── codegen.c, codegen.h           # LLVM IR, normal/Pico
│   └── errors.c, errors.h             # diagnósticos
├── ejemplos/
│   ├── area.olc, area.ll              # ejemplo decimal original
│   ├── resultado.olc, resultado.ll    # ejemplo entero original
│   └── pico_demo.olc                  # ejemplo de integración añadido
├── runtime/
│   └── pico/olc_runtime.c             # print_i32 y print_f64
├── targets/
│   └── pico/
│       ├── olc_entry.c                # main() del firmware, LED y espera USB opcional
│       └── CMakeLists.txt             # construcción UART o USB
├── tests/
│   ├── run_lexer.ps1
│   ├── run_sintaxis.ps1
│   ├── run_ast.ps1
│   ├── run_symtab.ps1
│   ├── run_semantica.ps1
│   ├── run_ir.ps1
│   ├── run_validacion.ps1
│   ├── run_objeto.ps1
│   ├── run_todo.ps1                     # reconstruye y ejecuta las 117 pruebas
│   ├── verificar_clon.ps1             # verificación independiente de clon limpio
│   ├── verificar_entrega.ps1          # controles de entrega existentes
│   └── tools/                         # drivers C de pruebas
└── build/                              # GENERADO; puede ser eliminado por build.ps1
    ├── compilador.exe
    ├── parser.tab.c, parser.tab.h, lex.yy.c
    ├── pico_program.ll, pico_program.S  # GENERADOS después de las pruebas
    ├── pico/                          # configuración/construcción UART utilizada
    └── pico_usb/                      # configuración/construcción USB utilizada
```

Las herramientas externas (`pico-sdk`, `tinyusb`, `picotool`) se instalaron **fuera del repositorio**, en `C:\Users\daish\Documents\U\pico-tools`. Los scripts de integración se entregaron y ejecutaron durante el desarrollo; su presencia posterior en la raíz debe comprobarse si se desea distribuirlos.

**Precaución:** `build.ps1` elimina y recrea toda la carpeta `build/`. Por tanto, **también elimina** el ensamblador `pico_program.S` y los directorios de construcción `build/pico*`. Para generar firmware después de ejecutar las pruebas se debe regenerar primero el `.ll` y el `.S`, y volver a configurar CMake. Los archivos de respaldo conservados en `pico-tools/firmware-olc` no dependen de `build/`.

## 4. Lenguaje fuente implementado

### 4.1. Sentencias

```text
let identificador = expresion;
print expresion;
```

- `let` declara e inicializa una variable; su tipo se **infiere** a partir de la expresión.
- Las variables se usan después de su declaración. El lenguaje no permite reasignación.
- `print` imprime el valor de una expresión a través de una función del runtime correspondiente al tipo.
- El programa contiene **una o más instrucciones**; la gramática examinada no define una producción vacía.
- Todos los identificadores están en un **único ámbito global** y distinguen mayúsculas y minúsculas.

### 4.2. Tipos y literales

| Tipo semántico | Representación LLVM | Ejemplo |
|---|---|---|
| `TIPO_ENTERO` | `i32` | `10`, `0`, `2147483647` |
| `TIPO_DECIMAL` | `double` (64 bits) | `10.5`, `20.0`, `0.1` |
| `TIPO_DESCONOCIDO` | estado interno | antes del análisis |
| `TIPO_ERROR` | estado interno | expresión con error previo |

El lexer reconoce enteros **no negativos escritos sin signo** como `[0-9]+`. Si el literal supera `2147483647`, registra error léxico. El signo negativo no es un operador unario de la gramática: `-3` no constituye un literal permitido. Los decimales requieren dígitos a ambos lados del punto (`[0-9]+\.[0-9]+`). No hay conversiones implícitas entre `i32` y `double`.

### 4.3. Expresiones y operadores

| Operador | Significado | Precedencia |
|---|---|---|
| `*` | multiplicación | alta |
| `/` | división | alta |
| `+` | suma | baja |
| `-` | resta binaria | baja |
| `( )` | agrupación | fuerza el orden |

Los operadores de cada nivel se asocian **de izquierda a derecha**. La gramática separa `expresion`, `termino` y `factor`, por lo que no necesita `%left`, `%right` ni `%prec`.

Ejemplo válido, también utilizado para el firmware:

```text
let a = 10;
let b = 20;
print a + b * 2;
let ancho = 10.5;
let alto = 20.0;
print ancho * alto;
```

Los resultados matemáticos esperados son **50** y **210.0**. En el runtime actual, `print_f64` usa `printf("%.17g\r\n", valor)`, por lo que **la representación textual esperada del segundo es `210`**, no necesariamente `210.0`.

### 4.4. Funcionalidades no incluidas

La gramática implementada **no contiene**: `if`, `else`, ciclos, funciones de usuario, arreglos, cadenas, comentarios, asignaciones posteriores a `let`, ámbitos anidados, operadores unarios, comparadores, notación científica para literales ni llamadas arbitrarias al hardware desde el lenguaje fuente. El LED utilizado en la integración pertenece al **runtime C**, no al lenguaje `.olc`.

## 5. Análisis léxico (`src/lexer.l`)

Flex reconoce:

| Token / categoría | Patrón o lexema |
|---|---|
| `LET` | `let` |
| `PRINT` | `print` |
| `ID` | `[A-Za-z_][A-Za-z0-9_]*` |
| `ENTERO` | `[0-9]+` |
| `DECIMAL` | `[0-9]+\.[0-9]+` |
| Operadores | `+`, `-`, `*`, `/` |
| Delimitadores | `(`, `)`, `=`, `;` |
| Espacios | espacios, tabulaciones, `\r`, `\n` (ignorados) |

`YY_USER_ACTION` registra las posiciones de token mediante `yylloc`: línea y columna (base 1). Los saltos de línea incrementan la línea y reinician la columna. El lexer reporta caracteres no reconocidos e identifica literales enteros fuera de rango. Los errores pasan por `error_reportar` y los mensajes muestran tipo de error y posición. Los identificadores se copian a memoria dinámica y los destructores de Bison ayudan a liberar valores descartados.

Los identificadores del lenguaje se limitan a letras ASCII, dígitos y guion bajo; las columnas se contabilizan según el recorrido de caracteres del lexer, no mediante una normalización Unicode. No se implementan reglas para comentarios.

## 6. Análisis sintáctico (`src/parser.y`)

La gramática esencial, expresada de manera resumida, es:

```bison
programa     : instrucciones ;
instrucciones: instrucciones instruccion | instruccion ;
instruccion  : LET ID '=' expresion ';'
             | PRINT expresion ';' ;
expresion    : expresion '+' termino
             | expresion '-' termino
             | termino ;
termino      : termino '*' factor
             | termino '/' factor
             | factor ;
factor       : ENTERO | DECIMAL | ID | '(' expresion ')' ;
```

Bison utiliza `%locations`, mensajes detallados (`%define parse.error verbose`) y construye nodos mediante las funciones de `ast.c`. La variable `ast_programa` recibe la raíz **solo al completar correctamente** el análisis. El proyecto no emplea reglas generales de recuperación sintáctica; en los errores reportados, el análisis suele interrumpirse. `build.ps1` prohíbe directivas de precedencia y pasa `-Werror=conflicts-sr` y `-Werror=conflicts-rr` a Bison para rechazar conflictos.

## 7. Árbol de sintaxis abstracta (AST)

`src/ast.h` define los tipos:

- `NODO_PROGRAMA`: lista dinámica de instrucciones.
- `NODO_LET`: nombre de variable y expresión inicializadora.
- `NODO_PRINT`: expresión que se imprimirá.
- `NODO_BINARIO`: operador y subárboles izquierdo y derecho.
- `NODO_ENTERO` y `NODO_DECIMAL`: literales.
- `NODO_ID`: referencia a variable.

Cada nodo guarda `tipo_dato`, línea y columna. Durante la construcción, el tipo semántico permanece inicialmente desconocido; `semantic.c` lo anota. `ast_liberar` libera recursivamente el árbol y sus recursos; `ast_imprimir` permite mostrar el árbol con posiciones (`AST_POSICIONES`) y tipos (`AST_TIPOS`). `ast_nodos_vivos` permite verificar en las pruebas que se liberaron los nodos creados.

## 8. Tabla de símbolos y análisis semántico

### 8.1. Tabla de símbolos

`src/symtab.c` almacena un arreglo dinámico de punteros a `Simbolo`. Cada símbolo guarda nombre, tipo, línea/columna de declaración, referencia a su expresión inicializadora y un texto `operando` que el generador asigna durante la emisión LLVM. El nombre se copia; el AST es propietario de la expresión inicializadora. `tabla_buscar` compara nombres mediante `strcmp` (sensible a mayúsculas), y `tabla_insertar` rechaza duplicados. No hay tabla por ámbito o función.

### 8.2. Reglas implementadas

El analizador de `src/semantic.c` recorre las instrucciones en orden y comprueba:

1. Una variable referenciada debe estar declarada previamente.
2. No puede declararse dos veces el mismo nombre.
3. En cada operación binaria, ambos operandos deben tener el **mismo tipo**.
4. Si un subárbol ya tiene error, se propaga `TIPO_ERROR` sin emitir diagnósticos de tipos derivados innecesarios.
5. Una expresión de `let` o `print` queda anotada con su tipo.

No hay conversión automática `i32 ↔ double`. El análisis puede acumular varios errores semánticos a lo largo de un programa; si `error_total()` es mayor que cero, `main.c` **no escribe el LLVM IR**. No existen comprobaciones semánticas de división entre cero ni desbordamiento aritmético.

Ejemplo inválido:

```text
let x = 5;
print x + 2.5;
```

Causa: mezcla de `i32` y `double` en `+`. Otro ejemplo inválido es `print y;` cuando `y` no se declaró previamente.

## 9. Generación de LLVM IR

`src/codegen.c` recorre el AST ya analizado y escribe instrucciones SSA en orden. Sus temporales se llaman `%t1`, `%t2`, etc., sin reutilización dentro de una generación. `let` asigna a la variable el texto de un operando (literal o temporal), **no crea una variable mutable en memoria**.

| Operación | `i32` | `double` |
|---|---|---|
| Suma | `add` | `fadd` |
| Resta | `sub` | `fsub` |
| Multiplicación | `mul` | `fmul` |
| División | `sdiv` | `fdiv` |

El módulo declara siempre:

```llvm
declare void @print_i32(i32)
declare void @print_f64(double)
```

Para modo normal, el cuerpo comienza con `define i32 @main() {`; en modo Pico, con `define i32 @olc_program() {`. Ambos finalizan con `ret i32 0`. Los tipos y operaciones son los mismos, lo cual mantiene compatible la interfaz de lenguaje. El literal `double` se formatea procurando preservar su valor binario; algunos números grandes o valores especiales pueden emitirse en la representación hexadecimal aceptada por LLVM.

Ejemplo abreviado de la salida normal para `ejemplos/area.olc`:

```llvm
declare void @print_i32(i32)
declare void @print_f64(double)

define i32 @main() {
entry:
  %t1 = fmul double 10.5, 20.0
  call void @print_f64(double %t1)
  ret i32 0
}
```

Para la Pico se genera el mismo contenido aritmético, pero la función pública es `@olc_program()` en lugar de `@main()`.

### 9.1. Validación del IR

**[POWERSHELL]** Desde la raíz del proyecto y con `C:\LLVM\bin` disponible:

```powershell
& "C:\LLVM\bin\llvm-as.exe" .\build\pico_program.ll -o .\build\pico_program.bc
if ($LASTEXITCODE -ne 0) { throw "llvm-as fallo" }

& "C:\LLVM\bin\opt.exe" -passes=verify -disable-output .\build\pico_program.ll
if ($LASTEXITCODE -ne 0) { throw "opt verify fallo" }
```

`llvm-as` valida y convierte a bitcode `.bc`; `opt -passes=verify` comprueba las invariantes del LLVM IR. El sistema de pruebas contiene una suite VL de 24 verificaciones, aprobadas en la ejecución informada.

## 10. Generación de ensamblador ARM Cortex-M0+

**Objetivo real de `llc`:** `thumbv6m-none-eabi`, CPU `cortex-m0plus`, ABI de punto flotante por software (la configuración final del enlace utiliza `-mfloat-abi=soft`).

**[POWERSHELL]** Desde la raíz del repositorio, **después** de `build.ps1` o `run_todo.ps1`:

```powershell
.\build\compilador.exe .\ejemplos\pico_demo.olc --target pico -o .\build\pico_program.ll
if ($LASTEXITCODE -ne 0) { throw "Compilador OLC fallo" }

& "C:\LLVM\bin\llc.exe" `
    -mtriple=thumbv6m-none-eabi `
    -mcpu=cortex-m0plus `
    -filetype=asm `
    .\build\pico_program.ll `
    -o .\build\pico_program.S
if ($LASTEXITCODE -ne 0) { throw "llc fallo" }
```

Se utiliza LLVM 23.1.0 instalado en Windows; se comprobó que `llc` reconoce los backends ARM y Thumb. En el firmware UART se observó, por desensamblado:

```asm
100002b4 <olc_program>:
    push {r4, lr}
    movs r0, #50
    bl   print_i32
    ...
    bl   print_f64
```

Para la llamada decimal, los registros `r0:r1` contienen los bits de `0x406A400000000000`, equivalentes a `210.0` como `double` IEEE-754. No se observó una conversión a `float`. La inspección `readelf -A` del ELF UART informó `Tag_CPU_name: "6S-M"` y `Tag_CPU_arch: v6S-M`.

La suite OB de 7 pruebas genera e inspecciona **objetos ARM**; no comprueba por sí sola el enlace ni el firmware. El enlace completo se verificó **aparte** con Pico SDK.

## 11. Integración con Raspberry Pi Pico

### 11.1. Separación del punto de entrada

El C generado en `targets/pico/olc_entry.c` define `int main(void)` y declara:

```c
extern int olc_program(void);
```

Con ello no hay dos definiciones de `main`: el compilador genera `olc_program()` solo cuando se usa `--target pico`. El código de entrada inicializa stdio y el LED que indique `PICO_DEFAULT_LED_PIN` para la placa seleccionada.

### 11.2. Runtime de impresión

`runtime/pico/olc_runtime.c` implementa las firmas que el LLVM IR necesita:

```c
void print_i32(int32_t valor) {
    printf("%" PRId32 "\r\n", valor);
    fflush(stdout);
}

void print_f64(double valor) {
    printf("%.17g\r\n", valor);
    fflush(stdout);
}
```

Es código C del runtime, no instrucciones especiales del lenguaje `.olc`. Las llamadas desde `olc_program()` pasan un `i32` o un `double` **sin conversión silenciosa a `float`**. CMake agrega `-u _printf_float` para solicitar soporte de formato decimal con la biblioteca C embebida. En la inspección UART mediante `arm-none-eabi-nm -u` apareció `_printf_float`: el enlace terminó, pero esa salida no sustituye una comprobación funcional de `printf` sobre la placa.

### 11.3. Modo UART

Configuración con `OLC_USB_STDIO=OFF` (predeterminada en `targets/pico/CMakeLists.txt`):

```cmake
pico_enable_stdio_usb(olc_pico 0)
pico_enable_stdio_uart(olc_pico 1)
```

El UF2 UART informa `UART stdin / stdout`, `GPIO0: UART0 TX` y `GPIO1: UART0 RX`. Para **observar** los resultados hace falta un receptor UART compatible con **lógica 3.3 V** (por ejemplo, un adaptador USB-UART; conectar TX de Pico con RX del adaptador y GND común). La salida no aparece como puerto COM USB CDC mediante el solo cable de programación. La configuración de UART utilizada por defecto se asocia a la consola serie de la Pico; la tasa de baudios de la configuración efectiva debe confirmarse antes de la prueba física (en la guía de evaluación se usa 115200 como valor habitual).

### 11.4. Modo USB CDC

Configuración con `OLC_USB_STDIO=ON`:

```cmake
pico_enable_stdio_usb(olc_pico 1)
pico_enable_stdio_uart(olc_pico 0)
```

Requiere **TinyUSB**. `olc_entry.c` incluye `pico/stdio_usb.h`, inicializa stdio y espera en un bucle a que `stdio_usb_connected()` sea verdadero; a continuación duerme aproximadamente 300 ms y ejecuta `olc_program()`. El objetivo es evitar que los primeros mensajes se pierdan antes de abrir el puerto serie. La espera puede ser indefinida cuando ningún monitor serial abre la conexión con DTR activo.

En el UF2 generado para USB, `picotool` informa `USB stdin / stdout` y **ningún pin fijo**. La conexión USB CDC no ha sido observada todavía en hardware físico; el hecho de que aparezca en los metadatos del UF2 solo verifica la configuración de compilación.

### 11.5. LED integrado

En `olc_entry.c`, si está definido `PICO_DEFAULT_LED_PIN`, el runtime inicializa el pin y lo deja en alto durante el inicio. Después de regresar de `olc_program()`, entra en un bucle que lo enciende **250 ms** y lo apaga **750 ms** (patrón de un segundo). En la **Pico original**, el LED integrado se asocia a **GPIO25**. En modo USB, el LED queda encendido mientras el programa aguarda la conexión serial. **Este comportamiento es el previsto por el código; no se ha probado en una placa real.**

No se implementaron controles directos de GPIO, sensores ni periféricos adicionales desde el lenguaje `.olc`.

## 12. Construcción del firmware ELF, BIN y UF2

El archivo `targets/pico/CMakeLists.txt`:

- importa el SDK mediante `PICO_SDK_PATH`;
- declara `project(olc_pico C CXX ASM)` y ejecuta `pico_sdk_init()`;
- incluye `olc_entry.c`, `runtime/pico/olc_runtime.c` y **`build/pico_program.S`**;
- enlaza `pico_stdlib`, selecciona UART o USB mediante `OLC_USB_STDIO`;
- añade la opción de enlace `-u _printf_float`;
- ejecuta `pico_add_extra_outputs(olc_pico)` para los artefactos finales.

La existencia de `build/pico_program.S` es una **precondición verificada por CMake**. La creación del ELF no depende de reutilizar artefactos binarios de MiniBot.

### 12.1. Configurar y construir UART

**[MSYS2 CLANG64]** Desde `/c/Users/daish/Documents/U/LLVM`, después de generar `build/pico_program.S`:

```bash
cd /c/Users/daish/Documents/U/LLVM
export PICO_SDK_PATH="C:/Users/daish/Documents/U/pico-tools/pico-sdk-2.3.1"
export CC="C:/msys64/clang64/bin/clang.exe"
export CXX="C:/msys64/clang64/bin/clang++.exe"

cmake -S targets/pico -B build/pico_uart -G Ninja \
  -DPICO_BOARD=pico \
  -DPICO_SDK_PATH="$PICO_SDK_PATH" \
  -DOLC_USB_STDIO=OFF \
  -Dpicotool_DIR="C:/Users/daish/Documents/U/pico-tools/picotool-dist/picotool"
cmake --build build/pico_uart
```

Este ejemplo utiliza un directorio `build/pico_uart` distinto al `build/pico` usado históricamente durante la integración; ambos nombres son válidos si se pasan de forma consistente a CMake. La configuración USB debe construirse en otro directorio para evitar que una variante sobrescriba a la otra.

### 12.2. Configurar y construir USB CDC

**[MSYS2 CLANG64]** Desde la misma raíz:

```bash
cd /c/Users/daish/Documents/U/LLVM
export PICO_SDK_PATH="C:/Users/daish/Documents/U/pico-tools/pico-sdk-2.3.1"
export PICO_TINYUSB_PATH="C:/Users/daish/Documents/U/pico-tools/tinyusb-0.18.0"
export CC="C:/msys64/clang64/bin/clang.exe"
export CXX="C:/msys64/clang64/bin/clang++.exe"

cmake -S targets/pico -B build/pico_usb -G Ninja \
  -DPICO_BOARD=pico \
  -DPICO_SDK_PATH="$PICO_SDK_PATH" \
  -DPICO_TINYUSB_PATH="$PICO_TINYUSB_PATH" \
  -DOLC_USB_STDIO=ON \
  -Dpicotool_DIR="C:/Users/daish/Documents/U/pico-tools/picotool-dist/picotool"
cmake --build build/pico_usb
```

**Resultado esperado:** `build/pico_usb/olc_pico.elf`, `.bin` y `.uf2`. Durante la ejecución reportada se obtuvieron los tres y `picotool` confirmó el modo USB.

### 12.3. Comprobar archivos y arquitectura

**[MSYS2 CLANG64]** (ejemplo USB):

```bash
PICOTOOL="C:/Users/daish/Documents/U/pico-tools/picotool-dist/picotool/picotool.exe"
ls -lh build/pico_usb/olc_pico.{elf,bin,uf2}
"$PICOTOOL" info -a build/pico_usb/olc_pico.uf2
arm-none-eabi-readelf -h build/pico_usb/olc_pico.elf
arm-none-eabi-readelf -A build/pico_usb/olc_pico.elf
arm-none-eabi-nm build/pico_usb/olc_pico.elf | grep -E ' (main|olc_program|print_i32|print_f64)$'
arm-none-eabi-nm -u build/pico_usb/olc_pico.elf
```

En UART, el ELF fue inspeccionado como `ELF32`, máquina `ARM` y arquitectura `v6S-M`; se observaron `main`, `olc_program`, `print_i32` y `print_f64`. En USB se confirmó la identidad RP2040 del UF2, pero **no se aportó aún la salida de `readelf`/`nm` específica del ELF USB**.

### 12.4. Resultados reales obtenidos

| Variante | ELF | BIN | UF2 | Confirmación de `picotool` |
|---|---:|---:|---:|---|
| UART | **539,040 bytes** | **28,352 bytes** | **56,832 bytes** | `family ID 'rp2040'`, `UART stdin / stdout`, SDK 2.3.1 |
| USB CDC | ~748 KiB | ~42 KiB | ~83 KiB | `family ID 'rp2040'`, `USB stdin / stdout`, SDK 2.3.1 |

En el UART se observó `binary start: 0x10000000`, `binary end: 0x10006ec0`; en el USB, `binary start: 0x10000000`, `binary end: 0x1000a424`. Los tamaños USB anteriores corresponden a la salida redondeada de `ls -lh` compartida, **no** a mediciones exactas en bytes. Ambas imágenes se generaron el **30 de octubre de 2026**.

El archivo UART se respaldó fuera de `build/` en `C:\Users\daish\Documents\U\pico-tools\firmware-olc` con nombres `olc_pico.elf`, `.bin` y `.uf2`. Se indicó guardar de modo análogo los archivos USB como `olc_pico_usb.*`; **el copiado final de la variante USB a esa carpeta aún no fue confirmado**.

## 13. Carga por BOOTSEL y observación de resultados

**Procedimiento preparado, no ejecutado con el firmware OLC1:**

1. Con la Pico desconectada, mantener pulsado **BOOTSEL**.
2. Conectar un **cable USB de datos** al PC, manteniendo BOOTSEL.
3. Soltar el botón y localizar en Windows la unidad `RPI-RP2`.
4. Copiar a esa unidad el UF2 elegido, preferentemente **USB CDC** si se quiere observar `print` con el solo cable USB.
5. La unidad debe desmontarse automáticamente y la placa reiniciarse. Después, abrir el puerto COM correspondiente al dispositivo USB CDC con una terminal serial que active **DTR**.
6. Observar la salida prevista de `print`: `50` y `210`, cada uno en una línea. Al terminar, observar el patrón previsto del LED integrado.

**[POWERSHELL]** Comprobar la unidad antes de copiar:

```powershell
$vol = @(Get-Volume | Where-Object FileSystemLabel -eq 'RPI-RP2')
if ($vol.Count -ne 1 -or -not $vol[0].DriveLetter) {
    throw 'No se encontro una unica unidad RPI-RP2'
}
$uf2 = 'C:\Users\daish\Documents\U\LLVM\build\pico_usb\olc_pico.uf2'
if (-not (Test-Path $uf2)) { throw "No existe el UF2: $uf2" }
Copy-Item -LiteralPath $uf2 -Destination "$($vol[0].DriveLetter):\" -ErrorAction Stop
```

El ejemplo presupone que se construyó el firmware después de la última ejecución de `build.ps1`. Si se usa el respaldo en `pico-tools/firmware-olc`, hay que cambiar **solo** la variable `$uf2` por la ruta real de ese archivo.

**[POWERSHELL]** Lectura sencilla desde un COM *ya identificado* (cambiar `COM5` por el asignado; no es una detección automática):

```powershell
$serial = [System.IO.Ports.SerialPort]::new('COM5', 115200)
$serial.DtrEnable = $true
$serial.ReadTimeout = 15000
try {
    $serial.Open()
    1..2 | ForEach-Object { Write-Host $serial.ReadLine().Trim() }
} finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
```

**Advertencia:** la salida USB y el parpadeo son **comportamientos esperados por el código**; en este proyecto no se cuenta con una prueba física. La guía externa MiniBot documenta una prueba en otra implementación, pero eso **no demuestra** ejecución de OLC1. En modo UART no es suficiente el cable USB de la Pico para recibir `printf`; se requiere conexión UART adicional.

## 14. Instalación y configuración del entorno

### 14.1. Herramientas confirmadas

| Entorno | Herramienta | Versión informada | Uso |
|---|---|---|---|
| Windows / PowerShell | LLVM (`C:\LLVM\bin`) | **23.1.0** | `llvm-as`, `opt`, `llc` y verificaciones |
| MSYS2 UCRT64 | GCC | **16.2.0** | compilación C (herramienta disponible) |
| MSYS2 UCRT64 | Flex | **2.6.4** | lexer |
| MSYS2 UCRT64 | Bison | **3.8.2** | parser |
| Windows / PowerShell | GCC, Flex, Bison en `PATH` | rutas identificadas; versiones Windows no confirmadas en esta fase | ejecución de `build.ps1` y las 117 pruebas |
| MSYS2 CLANG64 | `arm-none-eabi-gcc` | **16.1.0** | compilación y enlace para RP2040 |
| MSYS2 CLANG64 | GNU `ld` ARM | **2.47** falló; se recomendó **2.46.1-1**, sin salida posterior de versión | enlace ARM |
| MSYS2 CLANG64 | CMake | **4.4.3** | configuración |
| MSYS2 CLANG64 | Ninja | **1.13.2** | construcción |
| MSYS2 CLANG64 | Clang / Clang++ | **22.1.8** | compiladores host para herramientas auxiliares |
| MSYS2 CLANG64 | Python | **3.14.7** | utilidades de construcción del SDK |
| Externo | Pico SDK | **2.3.1** | bibliotecas y soporte RP2040 |
| Externo | TinyUSB | archivos de la distribución **0.18.0** | USB CDC |
| Externo | `picotool` | ejecutable y `picotoolConfig.cmake` presentes; versión de ejecutable no informada | generación/inspección UF2 |

**Obligatorias para el compilador base:** PowerShell, GCC, Flex y Bison compatibles con `build.ps1`; para ejecutar toda la suite de validación, también herramientas LLVM. **Obligatorias para producir firmware:** LLVM con backend ARM, toolchain ARM, CMake, Ninja, Pico SDK y `picotool` (o la configuración compatible que seleccione CMake). **Solo para USB CDC:** TinyUSB. **Para probar físicamente:** Raspberry Pi Pico original y cable USB de datos; para ver la variante UART, además receptor UART de 3.3 V. Python y compiladores host fueron necesarios en el entorno concreto documentado para completar la configuración.

### 14.2. Ubicación del SDK y herramientas externas

Rutas **empleadas en este equipo**:

```text
C:\Users\daish\Documents\U\pico-tools\
├── pico-sdk-2.3.1\
├── tinyusb-0.18.0\
├── picotool-dist\picotool\picotool.exe
└── firmware-olc\                # respaldo confirmado de UART
```

Los archivos fueron obtenidos como paquetes ZIP externos, no mediante dependencias versionadas en el repositorio. Se verificaron `external/pico_sdk_import.cmake` (SDK), `src/tusb.h`, `hw/bsp/family_support.cmake` y `hw/bsp/rp2040/family.cmake` (TinyUSB), y los archivos de configuración CMake de `picotool`.

En una instalación nueva puede descargarse el SDK oficial y TinyUSB con las versiones documentadas:

- Pico SDK 2.3.1: `https://github.com/raspberrypi/pico-sdk/archive/refs/tags/2.3.1.zip`
- TinyUSB 0.18.0: `https://github.com/hathach/tinyusb/archive/refs/tags/0.18.0.zip`
- Herramientas Windows de Pico SDK: `https://github.com/raspberrypi/pico-sdk-tools/releases` (seleccionar una distribución de `picotool` compatible).

Después de extraerlas, ajustar las rutas de `PICO_SDK_PATH`, `PICO_TINYUSB_PATH` y `picotool_DIR` al nuevo equipo. El SDK descargado como ZIP puede no incluir submódulos externos; en esta integración USB se proporcionó TinyUSB por separado.

### 14.3. Comprobaciones por terminal

**[MSYS2 UCRT64]**:

```bash
gcc --version
flex --version
bison --version
```

**[POWERSHELL]**:

```powershell
Get-Command gcc,flex,bison,llc,llvm-as,opt -ErrorAction SilentlyContinue |
  Select-Object Name,Source
& 'C:\LLVM\bin\llc.exe' --version
```

**[MSYS2 CLANG64]**:

```bash
arm-none-eabi-gcc --version
arm-none-eabi-ld --version
cmake --version
ninja --version
python --version
```

El enlace con GNU ARM Binutils **2.47** falló realmente con `linker script file ... appears multiple times`. Después de indicar la alternativa usada en MiniBot (paquete ARM Binutils **2.46.1-1**), el estudiante presentó los archivos de firmware ya enlazados. **No se recibió la salida de `pacman -Q` posterior**, por lo que la versión exacta del enlazador que finalmente produjo ese ELF queda pendiente de confirmación. Este ajuste **solo** debe aplicarse si se reproduce ese error; no es necesario cambiar el resto del toolchain y no debe hacerse un downgrade preventivo en sistemas donde el enlace ya funciona.

## 15. Uso del compilador e interfaz CLI

**[POWERSHELL]** Ejecutar desde la raíz del proyecto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

`build.ps1` compila `build/compilador.exe` y los drivers de prueba. **Advertencia:** recrea toda la carpeta `build/`.

Sintaxis implementada en `src/main.c` tras la integración:

```text
compilador.exe <entrada.olc> [-o <salida.ll>] [--target pico]
```

| Uso | Comando | Resultado |
|---|---|---|
| Solo análisis | `.\build\compilador.exe .\ejemplos\area.olc` | analiza sin escribir `.ll` |
| LLVM IR normal | `.\build\compilador.exe .\ejemplos\area.olc -o .\build\area.ll` | genera `@main()` |
| LLVM IR Pico | `.\build\compilador.exe .\ejemplos\pico_demo.olc --target pico -o .\build\pico_program.ll` | genera `@olc_program()` |

`--target` **solo acepta `pico`** en el código examinado. No se implementaron otras plataformas ni un selector genérico de backend. El argumento `-o` puede preceder al archivo de entrada; la selección de destino no cambia el análisis del lenguaje. El compilador devuelve `0` por éxito, `1` por error de compilación o generación y `2` por uso o E/S inválida. Solo emite `.ll` cuando recibe `-o` y no hay errores; no genera `.S`, `.elf`, `.bin` o `.uf2` directamente desde la CLI: esos pasos se ejecutan con LLVM y CMake.

## 16. Pruebas, cobertura y reproducibilidad

### 16.1. Suite automática

| Suite | Script | Casos | Cobertura principal |
|---|---|---:|---|
| LX | `tests/run_lexer.ps1` | 12 | tokens, ubicaciones y errores léxicos |
| SX | `tests/run_sintaxis.ps1` | 17 | gramática, errores y ausencia de conflictos Bison |
| AS | `tests/run_ast.ps1` | 12 | estructura, posiciones y memoria del AST |
| ST | `tests/run_symtab.ps1` | 13 | operaciones y propiedades de tabla de símbolos |
| SM | `tests/run_semantica.ps1` | 14 | tipos, variables y errores semánticos |
| IR | `tests/run_ir.ps1` | 18 | generación LLVM IR y CLI original |
| VL | `tests/run_validacion.ps1` | 24 | `llvm-as`, `opt`, casos de validación |
| OB | `tests/run_objeto.ps1` | 7 | código objeto ARM, CPU y controles |
| **Total** | **`tests/run_todo.ps1`** | **117** | **117 aprobadas, 0 fallidas** |

Se informó el siguiente resultado **después** de la integración USB, el 30/10/2026:

```text
TOTAL: 117 aprobadas, 0 fallidas (esperadas 117)
RESULTADO: todas las suites coinciden con lo esperado.
Nota: las pruebas OB solo generan objetos ARM. No hay enlace, firmware ni ejecucion en la placa.
```

La nota final es el texto literal heredado de `run_todo.ps1`: describe el alcance de **esas pruebas**, no el estado de los builds adicionales de firmware, que sí fueron enlazados por CMake.

**[POWERSHELL]** Ejecución:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run_todo.ps1
```

### 16.2. Verificaciones adicionales de firmware

1. **UART:** CMake/Ninja enlazaron `olc_pico.elf` y generaron `.bin`/`.uf2`. `picotool info -a` identificó RP2040 y `UART stdin / stdout`.
2. **UART, ELF:** `readelf` identificó ELF32 ARM y `v6S-M`; `nm` mostró `main`, `olc_program`, `print_i32`, `print_f64`. En `nm -u` se observó `_printf_float`. El desensamblado mostró llamadas correctas para `50` y `210.0`.
3. **USB CDC:** se generaron ELF/BIN/UF2 con TinyUSB presente; `picotool info -a` identificó RP2040 y `USB stdin / stdout`.
4. **Prueba física:** **no disponible**; no se conectó la Pico, no se observó el LED ni la consola USB/UART en este proyecto.

### 16.3. Verificación en estado limpio

`tests/verificar_clon.ps1` ya existe para comprobar archivos versionados, exclusión de generados y las suites en un clon local. La documentación anterior registraba una validación pasada de **5/5 controles RC**; **no se presentó una nueva ejecución de ese script después de integrar Pico/USB**. Además, el script original lista los archivos del compilador base y no verifica específicamente la presencia de los archivos nuevos del runtime/target. No usar aquel resultado antiguo para afirmar que el firmware actualizado se reconstruye desde un clon limpio sin preparación externa.

`tests/verificar_entrega.ps1` también existe, pero sus verificaciones y mensajes son los de la etapa previa al firmware; **no realiza pruebas de carga ni ejecución RP2040**, y su fecha límite embebida puede estar desactualizada. No se modificó ese script al documentar la integración.

**Limitación de reproducibilidad:** la construcción de firmware depende de herramientas instaladas externamente y de regenerar `build/pico_program.S` tras cada limpieza. El enlazado y generación de ambos UF2 ya ocurrió con éxito en un entorno concreto, pero no se ha confirmado una reconstrucción integral en otra computadora o a partir de un clon limpio actualizado.

## 17. Limitaciones conocidas y asuntos por confirmar

- No se ha realizado **prueba física** con la Raspberry Pi Pico: funcionamiento real del LED, salida UART, enumeración USB CDC y resultados impresos **pendientes**.
- El UF2 USB usa espera **sin límite de tiempo** hasta que `stdio_usb_connected()` detecte conexión: puede quedarse aguardando si el monitor serial no abre el puerto con DTR.
- La variante UART requiere receptor UART externo para observar `print`; la variante USB depende de TinyUSB.
- No hay control de división por cero ni de desbordamiento entero; una división entera por cero puede producir comportamiento indefinido en LLVM IR.
- No hay reasignación, funciones del usuario, estructuras de control, comentarios, operadores unarios, conversiones implícitas, ámbitos múltiples, cadenas ni periféricos invocables desde `.olc`.
- La recuperación sintáctica es limitada; mensajes detallados de Bison pueden estar en inglés.
- Solo se aceptan identificadores ASCII y literales decimales con dígitos a ambos lados del punto; algunas conversiones decimales extremas no generan error explícito.
- Si el análisis falla, no se genera un nuevo `.ll`; un archivo de salida anterior con el mismo nombre puede permanecer intacto.
- El AST se libera recursivamente, lo que podría agotar la pila ante árboles patológicamente profundos.
- El símbolo `_printf_float` apareció como `U` en `nm -u` del **ELF UART**, aunque el enlace completó. La comprobación de impresión decimal real sigue pendiente.
- Se verificó la arquitectura del ELF **UART**; no se recibió todavía `readelf`/`nm` de la variante **USB**.
- La prueba de división asociativa en la documentación anterior cubría la estructura AST, no necesariamente todas las variantes de IR.
- Los scripts `build.ps1`, `run_todo.ps1`, `verificar_clon.ps1` y `verificar_entrega.ps1` **no** fueron actualizados para incluir una suite automática de firmware Pico.
- Los scripts de integración iniciales fueron aplicados, pero no hay inspección directa del árbol local completo **después** de posibles cambios manuales ajenos a ellos.

## 18. Solución de errores frecuentes

| Síntoma | Causa observada o posible | Procedimiento específico |
|---|---|---|
| `flex`, `bison` o `gcc` no encontrado por `build.ps1` | Herramienta no visible desde PowerShell | Revisar `Get-Command`; incluir las instalaciones correspondientes en `PATH` y volver a ejecutar `build.ps1`. |
| Error o conflictos de Bison | Gramática cambiada / directivas prohibidas | Revisar `src/parser.y`; `build.ps1` ejecuta Bison con `-Werror=conflicts-*` y prohíbe precedencias explícitas. |
| `llc` no disponible en CLANG64 | LLVM instalado solo en Windows | Invocar explícitamente `C:\LLVM\bin\llc.exe` desde PowerShell, como se hizo en este entorno. |
| `llc` no admite ARM | Instalación LLVM sin backend | Comprobar `llc --version`; debe enumerar `arm` y `thumb`. |
| CMake: falta `pico_program.S` | `build.ps1` o `run_todo.ps1` borraron `build/` | Volver a generar `pico_program.ll` con `--target pico` y luego `pico_program.S` con `llc` **antes** de configurar CMake. |
| CMake: no encuentra `PICO_SDK_PATH` | SDK no configurado o ruta incorrecta | Proporcionar `-DPICO_SDK_PATH="..."` y verificar `external/pico_sdk_import.cmake`. |
| `pico_stdio_usb` / TinyUSB no disponible | ZIP de SDK sin TinyUSB | Verificar `src/tusb.h` y pasar `-DPICO_TINYUSB_PATH="..."` al configurar USB. |
| `picotool` no encontrado | Descubrimiento CMake ausente | Proporcionar `-Dpicotool_DIR` apuntando a la carpeta con `picotoolConfig.cmake`. |
| Enlace: `linker script file ... appears multiple times` | **Error observado** con GNU ARM Binutils 2.47 | Se recomendó ARM Binutils `2.46.1-1` y después se obtuvieron artefactos; la versión del enlazador posterior no fue enviada. Aplicar el cambio solo ante ese error y confirmar versión con `arm-none-eabi-ld --version`. |
| `ninja` falla después de cambiar la configuración UART/USB | Caché CMake con opciones anteriores | Usar directorios diferentes, p. ej. `build/pico_uart` y `build/pico_usb`, configurando cada uno por separado. |
| `RPI-RP2` no aparece | No está en modo BOOTSEL, cable de carga sin datos, dispositivo no detectado | Comprobar BOOTSEL/cable/administrador de dispositivos; **no verificado aún en OLC1**. |
| No aparecen números por el cable USB | Se cargó el UF2 UART | Utilizar el UF2 con `USB stdin / stdout`; abrir el COM correcto y activar DTR. |
| LED queda fijo con el UF2 USB | Puede estar esperando `stdio_usb_connected()` | Abrir el monitor serial USB con DTR; la ejecución física sigue pendiente de confirmación. |
| `U _printf_float` en `nm -u` | Opción `-u _printf_float` en CMake | No tratarlo automáticamente como fallo si el enlace concluyó; validar funcionalmente la impresión decimal cuando exista la placa. |

**Pauta para diagnósticos:** distinguir si falló la etapa Flex/Bison/GCC, la emisión LLVM, `llc`, la configuración CMake, el enlace GNU `ld`, la generación UF2 o la observación física. Los artefactos `.o`, `.elf`, `.bin` y `.uf2` no son intercambiables.

## 19. Estado final y evidencias

| Componente | Estado | Evidencia disponible |
|---|---|---|
| Compilador base C/Flex/Bison/AST/semántica | **COMPLETADO Y VERIFICADO** | Código revisado y suites LX/SX/AS/ST/SM aprobadas |
| Generación LLVM IR normal | **COMPLETADO Y VERIFICADO** | Código revisado y suites IR/VL aprobadas |
| Modo `--target pico` | **COMPLETADO Y VERIFICADO** | Script aplicado; IR y ensamblador generados; `olc_program` presente en ELF UART |
| LLVM ARM para Cortex-M0+ | **COMPLETADO Y VERIFICADO** | Suite OB; ELF UART `ELF32`, ARM, `v6S-M`; desensamblado |
| Runtime y punto de entrada | **COMPLETADO SIN PRUEBA FÍSICA** | Archivos integrados y funciones presentes en ELF UART |
| Firmware UART (ELF/BIN/UF2) | **COMPLETADO SIN PRUEBA FÍSICA** | Artefactos y metadatos RP2040/UART de `picotool` |
| Firmware USB CDC (ELF/BIN/UF2) | **COMPLETADO SIN PRUEBA FÍSICA** | Artefactos y metadatos RP2040/USB de `picotool` |
| 117 pruebas después de integrar USB | **COMPLETADO Y VERIFICADO** | `117 aprobadas, 0 fallidas` |
| Reconstrucción firmware en clon limpio actualizado | **PENDIENTE DE MI INTERVENCIÓN** | No se presentó esa ejecución |
| Carga BOOTSEL y ejecución sobre la Pico | **PENDIENTE DE MI INTERVENCIÓN** | Sin placa disponible durante desarrollo |
| Observación del LED y consola USB/UART | **PENDIENTE DE MI INTERVENCIÓN** | Sin evidencia física |

### Resumen del resultado

El proyecto pasó de **generar únicamente LLVM IR y objetos ARM** a **enlazar firmware completo con Pico SDK y producir UF2 para RP2040**, tanto en modo UART como USB CDC. El compilador base conservó **117/117 pruebas aprobadas después de los cambios**. El firmware UART tiene inspección detallada de arquitectura y símbolos; el USB fue construido y identificado como USB CDC mediante `picotool`. **No puede afirmarse todavía que se ejecutó o imprimió correctamente en una placa física.**

### Verificaciones pendientes para cerrar la evidencia

1. Conservar copias independientes y localizables de los UF2 UART y USB; confirmar el respaldo USB si todavía no se hizo.
2. Ejecutar `readelf`/`nm` sobre el ELF **USB** y guardar la salida como evidencia adicional.
3. Si se exige reproducibilidad integral, repetir la construcción completa desde un árbol limpio **con** todas las dependencias externas configuradas; `verificar_clon.ps1` por sí solo no cubre el firmware nuevo.
4. En la evaluación presencial, cargar por BOOTSEL y observar enumeración USB CDC, impresiones y LED; registrar los resultados reales, sean correctos o no.

---

## Notas sobre la actualización de esta documentación

Se reescribieron las secciones de objetivo, arquitectura, lenguaje, frontend, AST, semántica, LLVM IR, uso de CLI, herramientas y pruebas; se añadieron la separación `main()`/`olc_program()`, runtime de impresión, LED, UART, USB CDC, Pico SDK, TinyUSB, CMake/Ninja, firmware ELF/BIN/UF2, BOOTSEL y solución del problema conocido con GNU ARM Binutils 2.47. Se eliminaron las afirmaciones antiguas según las cuales **no había enlace, firmware ni runtime**.

La documentación original del ZIP se llamaba `DOCUMENTACION.md` (sin tilde). Este archivo nuevo se entrega como **`DOCUMENTACIÓN.md`**, según el nombre solicitado; al aplicarlo manualmente, mantener **una única documentación vigente** y evitar dos versiones contradictorias.
