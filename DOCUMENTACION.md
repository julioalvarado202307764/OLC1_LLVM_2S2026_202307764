# Compilador de expresiones aritméticas con LLVM IR

**Universidad de San Carlos de Guatemala** · Facultad de Ingeniería · Ingeniería en Ciencias y Sistemas
**Organización de Lenguajes y Compiladores 1 — 2S2026**
**Tarea:** Análisis Semántico y Generación de Código Intermedio con LLVM IR
**Carné:** 202307764 · **Arquitectura asignada:** Raspberry Pi Pico (ARM Cortex-M0+ / RP2040)

---

## 1. Descripción general

Este proyecto es un compilador pequeño, escrito en **C** con **Flex** y **Bison**, para un lenguaje de expresiones aritméticas. Recibe un archivo fuente y realiza análisis léxico, análisis sintáctico, construcción de un **AST propio** y análisis semántico con una **tabla de símbolos**. Solo si no hay errores, genera un archivo **LLVM IR** (`.ll`). A partir del `.ll`, el backend de LLVM (`llc`) produce código objeto para la arquitectura asignada.

```
código fuente (.olc)
   │  Flex          análisis léxico: tokens con línea y columna
   ▼
tokens
   │  Bison         análisis sintáctico (gramática no ambigua)
   ▼
AST propio
   │  semántica     tabla de símbolos, tipos, errores
   ▼
AST con tipos ──► (si hay errores: no se genera salida)
   │  generador     temporales %t1, %t2, ...
   ▼
archivo .ll (LLVM IR)
   │  llc           -mtriple=thumbv6m-none-eabi -mcpu=cortex-m0plus
   ▼
objeto ARM (.o)
   │  enlace, carga y ejecución: los realiza el docente en la evaluación presencial
   ▼
salida por monitor serial (no verificada en este trabajo)
```

### Lenguaje fuente

| Construcción | Forma |
|---|---|
| Declaración | `let identificador = expresion;` (variable de una sola asignación) |
| Salida | `print expresion;` |
| Operadores | `+`, `-`, `*`, `/` |
| Agrupación | paréntesis |
| Literales | enteros (`10`) y decimales (`25.5`) |
| Identificadores | uso de variables declaradas previamente |

Hay un único entorno global y dos tipos: entero (`i32`) y decimal (`double`). **No** hay conversiones implícitas entre ellos.

**Fuera del alcance** (enunciado, sección 4.10): condicionales, ciclos, funciones definidas por el usuario, arreglos, cadenas, estructuras, reasignación de variables, múltiples ámbitos, optimizaciones, conversiones implícitas y generación manual de ensamblador.

### Estado por etapa

| Etapa | Estado |
|---|---|
| Análisis léxico (Flex) | Implementado y probado |
| Análisis sintáctico (Bison, sin conflictos) | Implementado y probado |
| AST propio | Implementado y probado |
| Tabla de símbolos y análisis semántico | Implementado y probado |
| Generación de LLVM IR | Implementado, probado y validado con `llvm-as` y `opt` |
| Código objeto para `thumbv6m-none-eabi` | Generado con `llc` e inspeccionado con `llvm-objdump` |
| Enlace y generación de firmware | **No realizado** (requiere el runtime del docente) |
| Carga en la placa, ejecución y salida serial | **No realizado ni verificado** |

---

## 2. Autor y arquitectura asignada

- **Carné:** 202307764.
- **Regla de asignación** (enunciado, 4.6): `carné mod 3`. La suma de los dígitos es 31 y 31 mod 3 = 1.

| Resultado | Plataforma | Arquitectura |
|---|---|---|
| 0 | Arduino Mega | AVR / ATmega2560 |
| **1** | **Raspberry Pi Pico** | **ARM Cortex-M0+ / RP2040** |
| 2 | ESP32-C3 | RISC-V / RV32 |

La arquitectura asignada solo afecta a la etapa posterior al LLVM IR: el front-end y el `.ll` son comunes a las tres plataformas.

---

## 3. Requisitos del entorno y dependencias

| Componente | Versión utilizada |
|---|---|
| Sistema operativo | Windows, con PowerShell |
| Compilador de C | GCC 6.3.0 (MinGW), invocado con `-std=gnu11` |
| Flex | 2.6.4 (WinFlexBison) |
| Bison | 3.8.2 (WinFlexBison) |
| LLVM | 23.1.0 (`llc`, `llvm-as`, `opt`, `llvm-objdump`) |
| Git | 2.55.0 (Windows) |

- **No se requiere `make` ni MSYS2.** La compilación se hace con un script de PowerShell (`build.ps1`).
- `build.ps1` busca las herramientas en el `PATH`: `bison` (o `win_bison`), `flex` (o `win_flex`) y `gcc`.
- Las pruebas de validación y de objeto buscan además `llvm-as`, `opt`, `llc` y `llvm-objdump` en el `PATH`.
- No hace falta tener una placa. Durante el desarrollo solo se genera el código para la arquitectura asignada.

---

## 4. Compilar y ejecutar

### Compilar

Desde la raíz del repositorio, en PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

`build.ps1`:

1. Comprueba que `src\parser.y` **no** use `%left`, `%right`, `%nonassoc`, `%precedence` ni `%prec`.
2. Elimina y recrea la carpeta `build\` (solo contiene archivos generados).
3. Ejecuta Bison con `-d -Wall -Werror=conflicts-sr -Werror=conflicts-rr`. Si hubiera un conflicto, la compilación falla.
4. Ejecuta Flex.
5. Compila con GCC `build\compilador.exe` y las herramientas de prueba (`lexer_test.exe`, `ast_test.exe`, `symtab_test.exe`, `semantic_test.exe`).

La última línea de una compilación correcta es:

```
Compilacion exitosa: compilador.exe, lexer_test.exe, ast_test.exe, symtab_test.exe y semantic_test.exe (en build\)
```

### Usar el compilador

```
build\compilador.exe <entrada.olc> [-o <salida.ll>]
```

| Opción | Efecto |
|---|---|
| (solo entrada) | Analiza el archivo (léxico, sintáctico y semántico) sin escribir ningún `.ll` |
| `-o <salida.ll>` | Además, escribe el LLVM IR. **El archivo solo se crea si no hubo ningún error.** El orden de los argumentos es indistinto. |

La extensión `.olc` es una convención tomada de la Figura 10 del enunciado, no una exigencia.

**Mensajes de salida:**

| Salida | Mensaje |
|---|---|
| stdout | `Analisis sintactico exitoso.`, `Analisis semantico exitoso.` y, con `-o`, `LLVM IR generado en <ruta>` |
| stderr (errores léxicos o sintácticos) | `ERROR LEXICO` o `ERROR SINTACTICO (linea L, columna C): ...` y `Analisis fallido: N error(es).` |
| stderr (errores semánticos) | `ERROR SEMANTICO (linea L, columna C): ...` y `Analisis semantico fallido: N error(es). No se genera LLVM IR.` |

**Códigos de salida:** `0` correcto; `1` errores en el programa fuente o fallo al generar; `2` errores de uso o de entrada/salida (sin argumentos, `-o` sin valor, archivo inexistente).

Si el análisis falla, **no se crea** el archivo `.ll` y tampoco se borra uno que ya existiera.

### Ejemplo con su resultado esperado

Entrada, `ejemplos\area.olc` (ejemplo del enunciado, 4.8):

```
let ancho = 10.5;
let alto = 20.0;
let area = ancho * alto;
print area;
```

Comando:

```powershell
.\build\compilador.exe .\ejemplos\area.olc -o .\ejemplos\area.ll
```

Salida por pantalla:

```
Analisis sintactico exitoso.
Analisis semantico exitoso.
LLVM IR generado en .\ejemplos\area.ll
```

Contenido de `ejemplos\area.ll`:

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

**Salida esperada en el monitor serial según el enunciado:** `210.0`. Este valor es el que muestra la Figura 6 del enunciado y es el **resultado esperado**. **No se ha verificado en la placa**: eso depende del runtime y del hardware que proporciona el docente.

El repositorio incluye otro ejemplo con enteros (`ejemplos\resultado.olc`, `ejemplos\resultado.ll`).

### Ejemplos de diagnósticos reales

```
ERROR SINTACTICO (linea 2, columna 9): syntax error, unexpected ';', expecting ID or ENTERO or DECIMAL or '('
Analisis fallido: 1 error(es).
```

```
ERROR SEMANTICO (linea 3, columna 9): tipos incompatibles en la operacion: i32 + double (el lenguaje no hace conversion implicita entre entero y decimal)
Analisis semantico fallido: 1 error(es). No se genera LLVM IR.
```

---

## 5. Estructura del proyecto

```
.
├── .gitignore
├── build.ps1                    compila el proyecto (Bison → Flex → GCC)
├── DOCUMENTACION.md
├── ensayo/ensayo.pdf            ensayo individual
├── ejemplos/
│   ├── area.olc / area.ll       ejemplo decimal (enunciado 4.8) y su LLVM IR
│   └── resultado.olc / resultado.ll   ejemplo entero (enunciado 4.2) y su LLVM IR
├── src/
│   ├── lexer.l                  análisis léxico (Flex)
│   ├── parser.y                 gramática y construcción del AST (Bison)
│   ├── ast.h / ast.c            nodos del AST, creación, liberación y volcado
│   ├── tipos.h                  tipos del lenguaje (i32, double, error)
│   ├── symtab.h / symtab.c      tabla de símbolos (entorno global)
│   ├── semantic.h / semantic.c  análisis semántico
│   ├── codegen.h / codegen.c    generación de LLVM IR
│   ├── errors.h / errors.c      diagnósticos con línea y columna
│   └── main.c                   interfaz de línea de comandos
└── tests/
    ├── run_lexer.ps1  run_sintaxis.ps1  run_ast.ps1  run_symtab.ps1
    ├── run_semantica.ps1  run_ir.ps1  run_validacion.ps1  run_objeto.ps1
    ├── run_todo.ps1             reconstruye y ejecuta todas las suites
    ├── verificar_clon.ps1       reproducibilidad desde un clon limpio
    └── tools/                   programas de prueba (lexer, AST, tabla, semántica)
```

`build\` se genera al compilar y está excluida de Git, igual que los `.o`, `.exe` y `.bc`. Los archivos generados por Flex y Bison no se versionan.

---

## 6. Uso de Flex y Bison

### Flex (`src/lexer.l`)

| Token | Patrón |
|---|---|
| `LET`, `PRINT` | las palabras reservadas `let` y `print` |
| `ID` | `[A-Za-z_][A-Za-z0-9_]*` (solo ASCII) |
| `ENTERO` | `[0-9]+` |
| `DECIMAL` | `[0-9]+\.[0-9]+` |
| operadores y puntuación | `+ - * / ( ) = ;` |
| espacios | espacio, tabulador, retorno de carro y salto de línea (se ignoran) |

- Se aplica la coincidencia más larga: `letra` es un identificador y no `let` seguido de `ra`. `5.` se reconoce como el entero `5` y un `.` inválido, porque no se admiten decimales sin parte fraccionaria.
- Cada token guarda su línea y su columna (base 1, contadas en bytes; el tabulador cuenta como 1).
- **Errores léxicos:** un carácter no reconocido se reporta y se ignora, y el análisis continúa. Un entero mayor que 2147483647 (fuera de `i32`) se reporta como error, y el token sigue como `ENTERO` con valor 0 para no provocar errores en cascada.
- No se admiten comentarios.

### Bison (`src/parser.y`)

- Usa `%locations` para las posiciones y `%define parse.error verbose` para los mensajes.
- Los valores semánticos (`%union`) son un entero, un decimal, una cadena (identificadores) y un nodo del AST.
- Cada regla construye nodos del AST. El nodo raíz queda en la variable global `ast_programa` solo si el análisis termina bien.
- Un `%destructor` libera los nodos y las cadenas pendientes cuando hay un error sintáctico.
- El análisis se detiene en el **primer** error sintáctico (no hay recuperación de errores).
- Los textos que genera Bison (`syntax error, unexpected ...`) están en inglés.

---

## 7. Gramática y cómo se evitó la ambigüedad

La gramática es la de referencia del enunciado (4.2):

```
programa      : instrucciones ;
instrucciones : instrucciones instruccion | instruccion ;
instruccion   : LET ID '=' expresion ';'
              | PRINT expresion ';' ;
expresion     : expresion '+' termino
              | expresion '-' termino
              | termino ;
termino       : termino '*' factor
              | termino '/' factor
              | factor ;
factor        : ENTERO | DECIMAL | ID | '(' expresion ')' ;
```

**Precedencia por niveles.** `factor` es el nivel más cercano a los operandos. `termino` agrupa factores con `*` y `/`, y `expresion` agrupa términos con `+` y `-`. Por eso una multiplicación o división siempre queda más abajo en el árbol que una suma o resta: en `10 + 20 * 3` el producto se calcula primero. Los paréntesis vuelven a empezar el nivel más alto mediante `'(' expresion ')'`.

**Asociatividad por recursión izquierda.** `expresion` y `termino` son recursivas por la izquierda, de modo que `10 - 3 - 2` se interpreta como `(10 - 3) - 2` y `100 / 10 / 2` como `(100 / 10) / 2`.

**Sin directivas de precedencia.** El enunciado prohíbe `%left`, `%right`, `%nonassoc`, `%precedence` y `%prec`, y el proyecto no las usa. La gramática por sí sola no es ambigua: Bison la procesa sin conflictos shift/reduce ni reduce/reduce. Esto se garantiza de tres formas:

1. `build.ps1` falla si `parser.y` contiene alguna de esas directivas.
2. `build.ps1` invoca Bison con los conflictos tratados como errores.
3. Las pruebas SX16 y SX17 lo comprueban de forma explícita (SX17 es un control que verifica que el detector sí reconoce una directiva).

**Consecuencias de la gramática de referencia:** un archivo vacío es un error sintáctico (se exige al menos una instrucción), no existe el menos unario (`-5` es un error) y no hay reasignación (`a = 5;` es un error). Están cubiertos por SX10, SX12 y SX13.

La evidencia de la forma del árbol está en las pruebas AS01–AS04 y AS08 y, en el IR, en IR03, IR07 e IR08.

---

## 8. Representación del AST

El AST es una estructura propia en C (`src/ast.h`, `src/ast.c`). Se construye desde las reducciones del parser y es la única entrada del análisis semántico y del generador de LLVM IR.

| Tipo de nodo | Contenido |
|---|---|
| `NODO_PROGRAMA` | lista ordenada de instrucciones |
| `NODO_LET` | nombre de la variable y expresión |
| `NODO_PRINT` | expresión |
| `NODO_BINARIO` | operador (`+ - * /`) e hijos izquierdo y derecho |
| `NODO_ENTERO`, `NODO_DECIMAL` | valor del literal |
| `NODO_ID` | nombre |

- Cada nodo tiene su **posición principal** (línea y columna): el token del literal o identificador, el token del operador en una operación, el identificador declarado en un `let` y la palabra `print` en un `print`.
- Cada nodo tiene un campo `tipo_dato` que **asigna el análisis semántico** (`i32`, `double` o `error`).
- Los paréntesis **no** generan nodos: solo determinan la forma del árbol.
- Los constructores se quedan con los hijos y las cadenas que reciben, y `ast_liberar` libera el árbol completo. Un contador de nodos vivos permite comprobar en las pruebas que no quedan nodos sin liberar, incluso cuando hay un error sintáctico (AS11 y AS12).

Volcado real del árbol de `let resultado = a + b * 2;` y `print resultado;`, con posiciones (prueba AS09):

```
Programa
  Let resultado @1:5
    Binario + @1:19
      Id a @1:17
      Binario * @1:23
        Id b @1:21
        Entero 2 @1:25
  Print @2:1
    Id resultado @2:7
```

---

## 9. Tabla de símbolos y análisis semántico

### Tabla de símbolos (`src/symtab.h`, `src/symtab.c`)

Hay un único entorno global. Es un arreglo dinámico que conserva el orden de inserción, con búsqueda lineal y distinción entre mayúsculas y minúsculas. Cada entrada guarda:

| Campo | Contenido |
|---|---|
| `nombre` | nombre de la variable |
| `tipo` | `i32`, `double` o `error` |
| `linea`, `columna` | posición de la declaración |
| `inicializador` | referencia a la expresión del AST con la que se declaró (no es propietaria) |
| `operando` | operando LLVM (por ejemplo `10` o `%t2`) que el generador asigna a cada variable; empieza en `NULL` |

### Reglas del análisis semántico (`src/semantic.c`)

| Situación | Resultado |
|---|---|
| Literal entero o decimal | tipo `i32` o `double` |
| Identificador declarado | el tipo de su símbolo |
| Identificador no declarado | error en la posición del identificador; tipo `error` |
| Operación entre tipos distintos | error con los tipos y el operador; tipo `error` |
| Operación con un operando de tipo `error` | tipo `error`, **sin** nuevo mensaje |
| `let` | primero se analiza la expresión y después se declara el nombre con su tipo (también `error`) |
| `let` duplicado | error en el identificador; se conserva la declaración original |
| `print` | el nodo toma el tipo de su expresión |

- Una variable adquiere el tipo de la expresión con la que se declara. **No hay conversiones implícitas** entre `i32` y `double`: sumar un entero con un decimal es un error semántico.
- Como la expresión se analiza antes de declarar el nombre, `let a = a + 1;` es un uso de una variable no declarada.
- Un `let` fallido declara la variable con tipo `error`: los usos posteriores no producen errores en cascada, y una declaración duplicada se sigue detectando.
- Se analiza **todo** el archivo y se reportan todos los errores en una sola pasada. Si hay alguno, no se genera ninguna salida.

Mensajes reales:

```
ERROR SEMANTICO (linea 1, columna 7): variable no declarada: 'x'
ERROR SEMANTICO (linea 4, columna 5): declaracion duplicada de 'n' (ya declarada en linea 1, columna 5)
ERROR SEMANTICO (linea 3, columna 9): tipos incompatibles en la operacion: i32 + double (el lenguaje no hace conversion implicita entre entero y decimal)
```

**Decisión de diseño sobre la posición del error de tipos:** el enunciado no la define y la Figura 10 no es concluyente. Se reporta en el token más a la izquierda de la expresión binaria. Con paréntesis, es el primer operando y no el paréntesis.

Las pruebas SM01–SM14 cubren estas reglas, y ST01–ST13 cubren la tabla de símbolos.

---

## 10. Generación de LLVM IR

El generador (`src/codegen.c`) recorre el AST ya validado y escribe el `.ll`.

**Estructura del archivo:**

```llvm
declare void @print_i32(i32)
declare void @print_f64(double)

define i32 @main() {
entry:
  ...instrucciones...
  ret i32 0
}
```

- `@main` es **provisional**: el enunciado no define cómo el runtime del docente invoca el programa (ver la sección 14).
- El `.ll` **no** incluye `target triple` ni `datalayout`: es común a las tres arquitecturas y el triple se pasa a `llc`.
- Las funciones `print_i32` y `print_f64` las implementa el runtime que proporciona el docente.

**Reglas de generación:**

| Elemento | Traducción |
|---|---|
| Literal | operando directo (`20`, `10.5`) |
| Variable | su operando guardado en la tabla de símbolos (constante o `%tN`); **no** se usan `alloca` |
| `let` | no emite instrucciones |
| Operación binaria | primero el hijo izquierdo y luego el derecho; después `%tN = <instrucción> <tipo> <izq>, <der>` |
| Temporales | `%t1`, `%t2`, ... con un contador global; son únicos y no se reutilizan |
| `print` | `call void @print_i32(i32 <op>)` o `call void @print_f64(double <op>)` según el tipo anotado |

| Tipo | LLVM | Instrucciones |
|---|---|---|
| Entero | `i32` | `add`, `sub`, `mul`, `sdiv` |
| Decimal | `double` | `fadd`, `fsub`, `fmul`, `fdiv` |

**Literales decimales:** se escribe la forma decimal más corta que recupere exactamente el mismo `double` (con `.0` si no tiene parte fraccionaria): `0.1`, `10.5`, `20.0`. Si el valor requeriría notación científica, o es infinito o NaN, se escribe en la forma hexadecimal de LLVM. Por ejemplo, `100000000000000000000.0` se emite como `0x4415AF1D78B58C40` y `0.000001` como `0x3EB0C6F7A0B5ED8D` (pruebas VL17 y VL18).

### Ejemplo: precedencia y temporales

Entrada: `print 10 + 20 * 3;`. Salida (cuerpo de `@main`, prueba IR03):

```llvm
  %t1 = mul i32 20, 3
  %t2 = add i32 10, %t1
  call void @print_i32(i32 %t2)
```

### Ejemplo: enteros

`ejemplos\resultado.olc`:

```
let a = 10;
let b = 20;
let resultado = a + b * 2;
print resultado;
```

`ejemplos\resultado.ll`:

```llvm
declare void @print_i32(i32)
declare void @print_f64(double)

define i32 @main() {
entry:
  %t1 = mul i32 20, 2
  %t2 = add i32 10, %t1
  call void @print_i32(i32 %t2)
  ret i32 0
}
```

### Validación

Los `.ll` generados se validan con `llvm-as` (que ensambla y verifica) y con `opt -passes=verify` (pruebas VL01–VL12 y VL21–VL24). Dos controles negativos (VL19 y VL20) confirman que ambos validadores **rechazan** un IR inválido. Los valores de los literales `0.1`, `10.5`, `20.0` y `0.3`, y de los literales grandes y pequeños, se comparan con una referencia independiente tal como los interpreta LLVM (VL13–VL18).

**Nota:** `sdiv` por cero es comportamiento indefinido en LLVM. El compilador no comprueba la división entre cero.

---

## 11. Arquitectura asignada y generación de su código

El backend de LLVM produce el código para el **ARM Cortex-M0+ del RP2040**, con el triple `thumbv6m-none-eabi` y la CPU `cortex-m0plus`.

| Etapa | Estado |
|---|---|
| 1. Generar LLVM IR | Realizada |
| 2. Generar código objeto ARM con `llc` | Realizada |
| 3. Enlazar un firmware | **No realizada** |
| 4. Cargar y ejecutar en la placa | **No realizada** |
| 5. Observar la salida por monitor serial | **No realizada ni verificada** |

Que `llc` genere un objeto no demuestra que haya un firmware ni que el programa se ejecute en la placa.

### Comandos

```powershell
llc -mtriple=thumbv6m-none-eabi -mcpu=cortex-m0plus -filetype=obj  entrada.ll -o salida.o
llc -mtriple=thumbv6m-none-eabi -mcpu=cortex-m0plus -filetype=asm  entrada.ll -o salida.s
llvm-objdump -f salida.o                          # cabecera del archivo
llvm-objdump -t salida.o                          # tabla de símbolos
llvm-objdump -d salida.o                          # desensamblado
llvm-objdump -s -j .ARM.attributes salida.o       # atributos ARM
```

### Evidencia real (prueba OB, sobre los ejemplos del enunciado)

**Arquitectura.** `llvm-objdump -f` informa `file format elf32-littlearm` y `architecture: arm`. La sección `.ARM.attributes` contiene `aeabi` y el nombre de CPU `cortex-m0plus`. El ensamblador generado indica `.cpu cortex-m0plus`, `.code 16` y `.thumb_func`, y todo el `.text` es código Thumb. Además, la prueba comprueba los bytes de la cabecera ELF (32 bits, little-endian, máquina ARM, EABI versión 5) y no depende solo de `llc`. Un control confirma que un objeto generado **sin** el triple ARM no pasa esa comprobación (OB07).

**Programa entero** (`resultado.olc`), `main` generado por `llc`:

```
        push    {r7, lr}
        movs    r0, #50
        bl      print_i32
        movs    r0, #0
        pop     {r7, pc}
```

**Programa decimal** (`area.olc`), `main` generado por `llc`:

```
        push    {r4, lr}
        movs    r4, #0
        ldr     r1, .LCPI0_0
        mov     r0, r4
        bl      print_f64
        mov     r0, r4
        pop     {r4, pc}
        ...
.LCPI0_0:
        .long   1080705024                      @ 0x406a4000
```

**Tabla de símbolos del objeto entero** (`llvm-objdump -t`; el objeto se generó desde un archivo de prueba llamado `OB01.ll`, que aparece como símbolo local):

```
SYMBOL TABLE:
00000000 l    df *ABS*  00000000 OB01.ll
00000000 l    d  .text  00000000 .text
00000000 l       .text  00000000 $t
00000000 g     F .text  0000000c main
00000000         *UND*  00000000 print_i32
00000000         *UND*  00000000 __aeabi_unwind_cpp_pr0
```

### Qué muestran estos resultados

- `main` queda **definido** y `print_i32` o `print_f64` quedan **sin resolver**: los implementa el runtime del docente. El programa entero no referencia `print_f64` y viceversa.
- **No aparecen rutinas auxiliares de aritmética** (ni de `double` ni de división entera), ni con el nivel de optimización por defecto de `llc` ni con `-O0`. Todos los valores del lenguaje son constantes conocidas en compilación y `llc` las calcula él mismo: `10 + 20 * 2` se convierte en `movs r0, #50`, y `10.5 * 20.0` en la constante `0x406a4000` (la palabra alta de `210.0`).
- En el programa decimal, el `double` se pasa a `print_f64` en el par de registros `r0:r1`. Es consistente con un procesador sin unidad de coma flotante. El lado del runtime no se ha comprobado.
- **El símbolo `__aeabi_unwind_cpp_pr0` queda sin resolver en todos los objetos.** Aparece junto a las directivas de desenrollado de pila que emite `llc`. No se ha investigado más, y no se sabe si el enlace del docente lo resuelve (ver la sección 14).
- El objeto no está enlazado: en el desensamblado, la instrucción `bl` apunta a sí misma porque falta la relocalización que aplicaría el enlazador.

---

## 12. Pruebas y reproducibilidad

### Suites de pruebas

| Suite | Script | Pruebas | Qué cubre |
|---|---|---|---|
| LX | `tests\run_lexer.ps1` | 12 | tokens, posiciones, errores léxicos |
| SX | `tests\run_sintaxis.ps1` | 17 | programas válidos e inválidos, Bison sin conflictos |
| AS | `tests\run_ast.ps1` | 12 | forma del AST, posiciones, liberación de memoria |
| ST | `tests\run_symtab.ps1` | 13 | tabla de símbolos |
| SM | `tests\run_semantica.ps1` | 14 | análisis semántico y mensajes de error |
| IR | `tests\run_ir.ps1` | 18 | LLVM IR generado e interfaz de línea de comandos |
| VL | `tests\run_validacion.ps1` | 24 | validación con `llvm-as` y `opt`, literales y ejemplos versionados |
| OB | `tests\run_objeto.ps1` | 7 | objetos para `thumbv6m-none-eabi` |
| | **Total** | **117** | |

Las pruebas usan programas auxiliares (`lexer_test.exe`, `ast_test.exe`, `symtab_test.exe`, `semantic_test.exe`) que se generan en `build\` y permiten probar cada etapa por separado.

### Ejecutar todo

Reconstruye el proyecto desde cero y ejecuta las ocho suites:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\run_todo.ps1
```

Termina con `TOTAL: 117 aprobadas, 0 fallidas (esperadas 117)` y código de salida 0 solo si todas las suites coinciden con el recuento esperado.

### Reproducir desde un estado limpio

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\verificar_clon.ps1
```

El script clona el último commit del repositorio local en una carpeta temporal, comprueba que estén todos los archivos necesarios y que no haya archivos generados versionados, y ejecuta `run_todo.ps1` dentro del clon. Como un clon solo contiene lo versionado, no puede depender de archivos ignorados ni sin versionar. Solo borra la carpeta temporal que él mismo creó.

**Resultados obtenidos** sobre el commit `9a37068`: 117 aprobadas y 0 fallidas, tanto en la carpeta de trabajo como dentro del clon limpio (RC01–RC05, 5 de 5).

### Matriz de pruebas de aceptación

| ID | Requisito | Evidencia | Estado |
|---|---|---|---|
| T01 | Declaración entera y `print` | IR01, IR06, VL01 | Demostrada |
| T02 | Declaración decimal y `print` | IR02, IR06, IR09 | Demostrada |
| T03 | Precedencia | AS01, AS08, IR03, VL03 | Demostrada |
| T04 | Asociatividad izquierda de la resta | AS02, IR08, VL08 | Demostrada |
| T05 | Asociatividad izquierda de la división | AS03 (forma del árbol) | **Parcial**: no hay una prueba de IR con divisiones encadenadas |
| T06 | Paréntesis | AS04, AS10, IR07 | Demostrada |
| T07 | Los cuatro operadores en `i32` | IR04, VL04, OB03 | Demostrada |
| T08 | Los cuatro operadores en `double` | IR05, VL05, OB04 | Demostrada |
| T09 | Ejemplo del enunciado (ancho, alto, área) | SM02, IR02, VL02, VL21–VL22, OB02 | Demostrada |
| T10 | Temporales únicos y sin reutilizar | IR04, IR05, IR07 | Demostrada |
| T11 | Variable no declarada | SM03, SM07, SM12, IR12 | Demostrada |
| T12 | Declaración duplicada | SM04, SM09 | Demostrada |
| T13 | Tipos incompatibles | SM05, SM06, SM13 | Demostrada |
| T14 | Sin conversión implícita | SM05, SM09 | Demostrada |
| T15 | Error léxico | LX08–LX10, SX15, IR14 | Demostrada |
| T16 | Error sintáctico | SX05–SX14, AS11–AS12, IR13 | Demostrada |
| T17 | Bison sin conflictos ni directivas de precedencia | SX16, SX17 y cada `build.ps1` | Demostrada |
| T18 | LLVM IR válido | VL01–VL12, VL21–VL24, controles VL19–VL20 | Demostrada |
| T19 | Objeto para ARM (`thumbv6m-none-eabi`, `cortex-m0plus`) | OB01–OB05, controles OB06–OB07 | Demostrada **como objeto**, no como firmware |
| T20 | Reproducibilidad desde un estado limpio | RC01–RC05 (clon de `9a37068`) | Demostrada |

---

## 13. Limitaciones conocidas

- `define i32 @main()` es **provisional** hasta conocer el runtime del docente.
- No se comprueba la división entre cero ni el desbordamiento de la aritmética entera. `sdiv` por cero es comportamiento indefinido en LLVM.
- Si el análisis falla, no se crea el `.ll`, pero **no se borra** uno que ya existiera.
- Los mensajes de Bison tras `syntax error` están en inglés, y el análisis sintáctico se detiene en el primer error.
- Los identificadores son solo ASCII. Las columnas se cuentan en bytes.
- No hay menos unario ni literales decimales sin parte entera o fraccionaria (`.5`, `5.`), ni notación científica, ni comentarios.
- La posición de un error de tipos es el primer operando de la expresión, no el paréntesis.
- Un literal decimal con tantos dígitos que exceda lo representable se convierte en infinito y se escribe en hexadecimal sin reportarse como error. Ese caso no está cubierto por las pruebas.
- La liberación del AST es recursiva, así que un árbol extremadamente profundo podría agotar la pila.
- Los contadores de memoria de las pruebas cuentan nodos y símbolos, no cadenas sueltas. No se usó AddressSanitizer porque no está disponible con GCC 6.3 en MinGW.
- Los objetos generados **no están enlazados**, no hay firmware y nada se ejecutó en la placa.
- **T05** está demostrada solo a nivel del árbol (ver la matriz).

---

### Plan para la evaluación presencial

Para regenerar el IR y el objeto en el momento, desde la raíz del repositorio:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
.\build\compilador.exe .\ejemplos\area.olc -o .\salida.ll
llc -mtriple=thumbv6m-none-eabi -mcpu=cortex-m0plus -filetype=obj .\salida.ll -o .\salida.o
```

El enlace, la carga y la observación de la salida serial se realizan con los archivos de soporte y el mecanismo que proporcione el docente.