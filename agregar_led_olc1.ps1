# Extension minima para OLC1 / Raspberry Pi Pico original: instruccion "blink;".
# PowerShell, desde la raiz LLVM:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\agregar_led_olc1.ps1
# No ejecuta comandos Git, builds ni pruebas; no modifica DOCUMENTACION.md.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$raiz = (Get-Location).Path
$rutas = @('src\lexer.l', 'src\parser.y', 'src\ast.h', 'src\ast.c',
           'src\semantic.c', 'src\codegen.c', 'runtime\pico\olc_runtime.c')
foreach ($ruta in $rutas) {
    if (-not (Test-Path -LiteralPath (Join-Path $raiz $ruta))) {
        throw "Falta ${ruta}; ejecuta desde la raiz LLVM con integracion Pico aplicada."
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $raiz 'targets\pico\CMakeLists.txt'))) {
    throw 'Falta targets\pico\CMakeLists.txt.'
}
if (Test-Path -LiteralPath (Join-Path $raiz 'ejemplos\pico_led.olc')) {
    throw 'Ya existe ejemplos\pico_led.olc; se evita sobreescribirlo.'
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
$nuevos = @{}
foreach ($ruta in $rutas) {
    $texto = [System.IO.File]::ReadAllText((Join-Path $raiz $ruta))
    $nuevos[$ruta] = $texto.Replace("`r`n", "`n")
}
if ($nuevos['src\lexer.l'].Contains('return BLINK;') -or
    $nuevos['src\codegen.c'].Contains('@olc_led_blink')) {
    throw 'La extension blink parece aplicada. No se hicieron cambios.'
}
function SustituirUna([string]$texto, [string]$antes, [string]$despues, [string]$nombre) {
    $n = [regex]::Matches($texto, [regex]::Escape($antes)).Count
    if ($n -ne 1) {
        throw "No se modifica ${nombre}: el anclaje aparece $n veces (se esperaba 1): $antes"
    }
    return $texto.Replace($antes, $despues)
}

# Lexico: se reconoce antes de los identificadores.
$antes = '"print"                  { return PRINT; }'
$despues = "`"print`"                  { return PRINT; }`n`"blink`"                  { return BLINK; }"
$nuevos['src\lexer.l'] = SustituirUna $nuevos['src\lexer.l'] $antes $despues 'src/lexer.l'

# Sintaxis: blink; no es una instruccion MiniBot.
$nuevos['src\parser.y'] = SustituirUna $nuevos['src\parser.y'] '%token LET PRINT' '%token LET PRINT BLINK' 'src/parser.y tokens'
$antes = @'
    | PRINT expresion ';'
        { $$ = ast_print_nuevo($2, @1.first_line, @1.first_column); }
'@
$despues = @'
    | PRINT expresion ';'
        { $$ = ast_print_nuevo($2, @1.first_line, @1.first_column); }
    | BLINK ';'
        { $$ = ast_blink_nuevo(@1.first_line, @1.first_column); }
'@
$nuevos['src\parser.y'] = SustituirUna $nuevos['src\parser.y'] $antes $despues 'src/parser.y reglas'

# AST: instruccion nueva sin hijos.
$nuevos['src\ast.h'] = SustituirUna $nuevos['src\ast.h'] '    NODO_PRINT,' "    NODO_PRINT,`n    NODO_BLINK," 'src/ast.h enum'
$antes = 'Nodo *ast_print_nuevo(Nodo *expresion, int linea, int columna);'
$despues = "Nodo *ast_print_nuevo(Nodo *expresion, int linea, int columna);`nNodo *ast_blink_nuevo(int linea, int columna);"
$nuevos['src\ast.h'] = SustituirUna $nuevos['src\ast.h'] $antes $despues 'src/ast.h constructores'
$antes = 'Nodo *ast_binario_nuevo(Operador op, Nodo *izq, Nodo *der, int linea, int columna)'
$despues = @'
Nodo *ast_blink_nuevo(int linea, int columna)
{
    return nodo_nuevo(NODO_BLINK, linea, columna);
}

Nodo *ast_binario_nuevo(Operador op, Nodo *izq, Nodo *der, int linea, int columna)
'@
$nuevos['src\ast.c'] = SustituirUna $nuevos['src\ast.c'] $antes $despues 'src/ast.c constructor'
$antes = "    case NODO_ENTERO:`n    case NODO_DECIMAL:`n        break;"
$despues = "    case NODO_ENTERO:`n    case NODO_DECIMAL:`n    case NODO_BLINK:`n        break;"
$nuevos['src\ast.c'] = SustituirUna $nuevos['src\ast.c'] $antes $despues 'src/ast.c liberar'
$antes = @'
    case NODO_PRINT:
        fputs("Print", salida);
        break;
'@
$despues = @'
    case NODO_PRINT:
        fputs("Print", salida);
        break;
    case NODO_BLINK:
        fputs("Blink", salida);
        break;
'@
$nuevos['src\ast.c'] = SustituirUna $nuevos['src\ast.c'] $antes $despues 'src/ast.c imprimir'

# Semantica: instruccion sin argumentos, no altera la tabla de simbolos.
$antes = @'
        } else if (instruccion->tipo == NODO_PRINT) {
            analizar_print(instruccion, tabla);
        }
'@
$despues = @'
        } else if (instruccion->tipo == NODO_PRINT) {
            analizar_print(instruccion, tabla);
        } else if (instruccion->tipo == NODO_BLINK) {
            /* Sin operandos: no cambia la tabla ni requiere inferencia. */
        }
'@
$nuevos['src\semantic.c'] = SustituirUna $nuevos['src\semantic.c'] $antes $despues 'src/semantic.c'

# Generacion LLVM: simbolo del runtime presente solo en programas blink para Pico.
$antes = @'
    default:
        error_interno(g, "nodo que no es una instruccion");
'@
$despues = @'
    case NODO_BLINK:
        fputs("  call void @olc_led_blink()\n", g->salida);
        break;

    default:
        error_interno(g, "nodo que no es una instruccion");
'@
$nuevos['src\codegen.c'] = SustituirUna $nuevos['src\codegen.c'] $antes $despues 'src/codegen.c instrucciones'
$antes = '    fputs("declare void @print_i32(i32)\n", salida);'
$despues = @'
    for (i = 0; i < programa->u.programa.cantidad; i++) {
        if (programa->u.programa.instrucciones[i]->tipo == NODO_BLINK) {
            if (!para_pico) {
                fprintf(stderr, "Error: blink requiere --target pico.\n");
                return 1;
            }
            fputs("declare void @olc_led_blink()\n", salida);
            break;
        }
    }

    fputs("declare void @print_i32(i32)\n", salida);
'@
$nuevos['src\codegen.c'] = SustituirUna $nuevos['src\codegen.c'] $antes $despues 'src/codegen.c declaraciones'

# Runtime C con Pico SDK. El bucle de parpadeo es intencionalmente infinito.
$antes = '#include <inttypes.h>'
$despues = "#include `"pico/stdlib.h`"`n#include <inttypes.h>"
$nuevos['runtime\pico\olc_runtime.c'] = SustituirUna $nuevos['runtime\pico\olc_runtime.c'] $antes $despues 'runtime/pico/olc_runtime.c includes'
$nuevos['runtime\pico\olc_runtime.c'] += @'

/* Implementa la instruccion fuente "blink;" para la Pico original.
   ABI: void olc_led_blink(void), sin argumentos ni conversiones. */
#ifndef PICO_DEFAULT_LED_PIN
#error "Se requiere una placa con PICO_DEFAULT_LED_PIN"
#endif
void olc_led_blink(void)
{
    const uint pin = PICO_DEFAULT_LED_PIN;
    gpio_init(pin);
    gpio_set_dir(pin, GPIO_OUT);
    for (;;) {
        gpio_put(pin, true);
        sleep_ms(250);
        gpio_put(pin, false);
        sleep_ms(750);
    }
}
'@

# A partir de aqui escribe; todos los anclajes ya se verificaron.
$backup = Join-Path $env:TEMP ('OLC1_led_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
foreach ($ruta in $rutas) {
    $archivoRespaldo = Join-Path $backup $ruta
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $archivoRespaldo) | Out-Null
    Copy-Item -LiteralPath (Join-Path $raiz $ruta) -Destination $archivoRespaldo -ErrorAction Stop
}
Write-Host "RESPALDO: $backup"
foreach ($ruta in $rutas) {
    [System.IO.File]::WriteAllText((Join-Path $raiz $ruta), $nuevos[$ruta], $utf8)
    Write-Host "MODIFICADO: $ruta"
}
$demo = Join-Path $raiz 'ejemplos\pico_led.olc'
[System.IO.File]::WriteAllText($demo, "blink;`n", $utf8)
Write-Host 'CREADO: ejemplos\pico_led.olc'
Write-Host 'EXTENSION LED APLICADA. Pendientes: build, pruebas, LLVM y firmware.'
