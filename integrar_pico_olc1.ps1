# Integracion aditiva OLC1 -> Raspberry Pi Pico RP2040.
# Ejecutar DESDE PowerShell: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\integrar_pico_olc1.ps1
# No ejecuta comandos de Git; no modifica build.ps1, parser, lexer ni pruebas.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$raiz = (Get-Location).Path
foreach ($ruta in @('build.ps1', 'src\main.c', 'src\codegen.c', 'src\codegen.h', 'tests\run_todo.ps1')) {
    if (-not (Test-Path -LiteralPath (Join-Path $raiz $ruta))) {
        throw "Ejecuta el script desde la raiz del proyecto LLVM. Falta: $ruta"
    }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
function Leer([string]$ruta) { return [System.IO.File]::ReadAllText((Join-Path $raiz $ruta)) }
function SustituirUna([string]$contenido, [string]$antes, [string]$despues, [string]$ruta) {
    $n = ([regex]::Matches($contenido, [regex]::Escape($antes))).Count
    if ($n -ne 1) { throw "No se aplica ${ruta}: anclaje no encontrado una sola vez ($n): $antes" }
    return $contenido.Replace($antes, $despues)
}
function Guardar([string]$ruta, [string]$contenido) {
    $absoluta = Join-Path $raiz $ruta
    $directorio = Split-Path -Parent $absoluta
    if (-not (Test-Path $directorio)) { New-Item -ItemType Directory -Force -Path $directorio | Out-Null }
    [System.IO.File]::WriteAllText($absoluta, $contenido, $utf8)
    Write-Host "ESCRITO: $ruta"
}

$main = Leer 'src\main.c'
$codegen = Leer 'src\codegen.c'
$header = Leer 'src\codegen.h'
# Normalizamos nuevas lineas para que los anclajes sean independientes de CRLF.
$main = $main -replace "`r`n", "`n"
$codegen = $codegen -replace "`r`n", "`n"
$header = $header -replace "`r`n", "`n"

# Evitar aplicar dos veces; no sobrescribir archivos existentes del target.
if ($main.Contains('--target') -or $codegen.Contains('codegen_generar_pico')) {
    throw 'La integracion ya parece aplicada. No se hicieron cambios.'
}
foreach ($ruta in @('runtime\pico\olc_runtime.c', 'targets\pico\olc_entry.c', 'targets\pico\CMakeLists.txt', 'ejemplos\pico_demo.olc')) {
    if (Test-Path -LiteralPath (Join-Path $raiz $ruta)) {
        throw "Ya existe $ruta. Revisa antes de ejecutar: no se sobrescribira."
    }
}

$main = SustituirUna $main 'Uso: %s <entrada.olc> [-o <salida.ll>]\n' 'Uso: %s <entrada.olc> [-o <salida.ll>] [--target pico]\n' 'src/main.c'
$main = SustituirUna $main 'static int escribir_ir(const char *ruta, const Nodo *programa, TablaSimbolos *tabla)' 'static int escribir_ir(const char *ruta, const Nodo *programa, TablaSimbolos *tabla, int para_pico)' 'src/main.c'
$main = SustituirUna $main 'fallo = codegen_generar(programa, tabla, archivo);' 'fallo = para_pico ? codegen_generar_pico(programa, tabla, archivo) : codegen_generar(programa, tabla, archivo);' 'src/main.c'
$main = SustituirUna $main '    const char *salida = NULL;' "    const char *salida = NULL;`n    int para_pico = 0;" 'src/main.c'
$ramaTarget = @'
        } else if (strcmp(argv[i], "--target") == 0) {
            if (para_pico || i + 1 >= argc || strcmp(argv[i + 1], "pico") != 0) {
                return uso(argv[0]);
            }
            para_pico = 1;
            i++;
        } else if (entrada == NULL) {
'@
$main = SustituirUna $main "        } else if (entrada == NULL) {" $ramaTarget.TrimEnd() 'src/main.c'
$main = SustituirUna $main 'resultado = escribir_ir(salida, ast_programa, &tabla);' 'resultado = escribir_ir(salida, ast_programa, &tabla, para_pico);' 'src/main.c'

$codegen = SustituirUna $codegen 'int codegen_generar(const Nodo *programa, TablaSimbolos *tabla, FILE *salida)' 'static int codegen_generar_interno(const Nodo *programa, TablaSimbolos *tabla, FILE *salida, int para_pico)' 'src/codegen.c'
$definicionPico = @'
    fputs(para_pico ? "define i32 @olc_program() {\n" : "define i32 @main() {\n", salida);
'@
$codegen = SustituirUna $codegen '    fputs("define i32 @main() {\n", salida);' $definicionPico.TrimEnd() 'src/codegen.c'
$codegen += @'

/* Modo original intacto para las suites IR/OB y uso fuera de Pico. */
int codegen_generar(const Nodo *programa, TablaSimbolos *tabla, FILE *salida)
{
    return codegen_generar_interno(programa, tabla, salida, 0);
}

/* Firmware: el punto de entrada main() pertenece al runtime de Pico. */
int codegen_generar_pico(const Nodo *programa, TablaSimbolos *tabla, FILE *salida)
{
    return codegen_generar_interno(programa, tabla, salida, 1);
}
'@
$headerNuevo = @'
/* Produce el mismo lenguaje e IR, pero define i32 @olc_program() para Pico. */
int codegen_generar_pico(const Nodo *programa, TablaSimbolos *tabla, FILE *salida);

#endif
'@
$header = SustituirUna $header "#endif" $headerNuevo.TrimEnd() 'src/codegen.h'

$runtime = @'
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

/* ARM Cortex-M0+: ABI entero i32, compatible con la declaracion LLVM. */
void print_i32(int32_t valor)
{
    printf("%" PRId32 "\r\n", valor);
    fflush(stdout);
}

/* La firma es double (64 bits); no hay conversion implicita a float. */
void print_f64(double valor)
{
    printf("%.17g\r\n", valor);
    fflush(stdout);
}
'@
$entry = @'
#include "pico/stdlib.h"

extern int olc_program(void);

int main(void)
{
    stdio_init_all();  /* Se habilitara UART en CMake, no USB. */

#if defined(PICO_DEFAULT_LED_PIN)
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
    gpio_put(PICO_DEFAULT_LED_PIN, 1);
#endif

    (void)olc_program();

    /* Parpadea una vez por segundo al regresar del programa compilado. */
    while (true) {
#if defined(PICO_DEFAULT_LED_PIN)
        gpio_put(PICO_DEFAULT_LED_PIN, 1);
#endif
        sleep_ms(250);
#if defined(PICO_DEFAULT_LED_PIN)
        gpio_put(PICO_DEFAULT_LED_PIN, 0);
#endif
        sleep_ms(750);
    }
}
'@
$cmake = @'
cmake_minimum_required(VERSION 3.13)

if(DEFINED PICO_SDK_PATH)
    include("${PICO_SDK_PATH}/external/pico_sdk_import.cmake")
elseif(DEFINED ENV{PICO_SDK_PATH})
    include("$ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake")
else()
    message(FATAL_ERROR "Configura PICO_SDK_PATH antes de CMake")
endif()

project(olc_pico C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
pico_sdk_init()

set(OLC_PROGRAM_S "${CMAKE_CURRENT_LIST_DIR}/../../build/pico_program.S"
    CACHE FILEPATH "Ensamblador Thumb generado por el compilador OLC1")
if(NOT EXISTS "${OLC_PROGRAM_S}")
    message(FATAL_ERROR "No existe ${OLC_PROGRAM_S}; genera el ensamblador antes de configurar CMake")
endif()

add_executable(olc_pico
    olc_entry.c
    "${OLC_PROGRAM_S}"
    "${CMAKE_CURRENT_LIST_DIR}/../../runtime/pico/olc_runtime.c"
)
target_link_libraries(olc_pico pico_stdlib)
pico_enable_stdio_usb(olc_pico 0)
pico_enable_stdio_uart(olc_pico 1)
# newlib-nano requiere incluir expresamente soporte printf para double.
target_link_options(olc_pico PRIVATE "-u" "_printf_float")
pico_add_extra_outputs(olc_pico)
'@
$demo = @'
let a = 10;
let b = 20;
print a + b * 2;
let ancho = 10.5;
let alto = 20.0;
print ancho * alto;
'@

$backup = Join-Path $env:TEMP ('OLC1_pico_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
foreach ($ruta in @('src\main.c', 'src\codegen.c', 'src\codegen.h')) {
    Copy-Item -LiteralPath (Join-Path $raiz $ruta) -Destination (Join-Path $backup (Split-Path $ruta -Leaf))
}
Write-Host "COPIAS DE SEGURIDAD: $backup"
Guardar 'src\main.c' $main
Guardar 'src\codegen.c' $codegen
Guardar 'src\codegen.h' $header
Guardar 'runtime\pico\olc_runtime.c' $runtime
Guardar 'targets\pico\olc_entry.c' $entry
Guardar 'targets\pico\CMakeLists.txt' $cmake
Guardar 'ejemplos\pico_demo.olc' $demo
Write-Host 'INTEGRACION APLICADA. No se ejecuto compilacion ni pruebas.'
