# build.ps1 - Compila el proyecto sin make: Bison -> Flex -> GCC.
# Uso (desde la raiz del proyecto):
#   powershell -ExecutionPolicy Bypass -File .\build.ps1

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

function Find-Tool([string[]]$Names) {
    foreach ($n in $Names) {
        $c = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return $c.Source }
    }
    throw "No se encontro ninguna de estas herramientas en el PATH: $($Names -join ', ')"
}

function Invoke-Step([string]$Titulo, [string]$Herramienta, [string[]]$Argumentos) {
    Write-Host "==> $Titulo"
    Write-Host "    $Herramienta $($Argumentos -join ' ')"
    & $Herramienta @Argumentos
    if ($LASTEXITCODE -ne 0) {
        throw "Fallo en el paso '$Titulo' (codigo de salida $LASTEXITCODE)"
    }
}

$bison = Find-Tool @('bison', 'win_bison')
$flex  = Find-Tool @('flex', 'win_flex')
$gcc   = Find-Tool @('gcc')

# Requisito del enunciado: nada de directivas de precedencia en la gramatica.
$prohibidas = Select-String -Path 'src\parser.y' -Pattern '^\s*%(left|right|nonassoc|precedence)\b', '%prec\b'
if ($prohibidas) {
    $prohibidas | ForEach-Object { Write-Host $_.ToString() }
    throw "parser.y contiene directivas de precedencia prohibidas por el enunciado"
}

# Solo se borra la carpeta build (contiene unicamente archivos generados).
if (Test-Path -LiteralPath 'build') {
    Remove-Item -LiteralPath 'build' -Recurse -Force
}
New-Item -ItemType Directory -Path 'build' | Out-Null

# -Werror=conflicts-*: Bison falla si hay conflictos shift/reduce o reduce/reduce.
Invoke-Step 'Bison (parser)' $bison @(
    '-d', '-Wall', '-Werror=conflicts-sr', '-Werror=conflicts-rr',
    '-o', 'build/parser.tab.c', 'src/parser.y'
)

Invoke-Step 'Flex (lexer)' $flex @(
    '-o', 'build/lex.yy.c', 'src/lexer.l'
)

Invoke-Step 'GCC (compilador.exe)' $gcc @(
    '-std=gnu11', '-Wall', '-Wextra', '-Isrc', '-Ibuild',
    '-o', 'build/compilador.exe',
    'src/main.c', 'src/ast.c', 'src/errors.c', 'build/parser.tab.c', 'build/lex.yy.c'
)

Invoke-Step 'GCC (lexer_test.exe, herramienta de prueba del lexer)' $gcc @(
    '-std=gnu11', '-Wall', '-Wextra', '-Isrc', '-Ibuild',
    '-o', 'build/lexer_test.exe',
    'tests/tools/lexer_driver.c', 'src/errors.c', 'build/lex.yy.c'
)

Invoke-Step 'GCC (ast_test.exe, herramienta de prueba del AST)' $gcc @(
    '-std=gnu11', '-Wall', '-Wextra', '-Isrc', '-Ibuild',
    '-o', 'build/ast_test.exe',
    'tests/tools/ast_driver.c', 'src/ast.c', 'src/errors.c', 'build/parser.tab.c', 'build/lex.yy.c'
)

Invoke-Step 'GCC (symtab_test.exe, herramienta de prueba de la tabla de simbolos)' $gcc @(
    '-std=gnu11', '-Wall', '-Wextra', '-Isrc',
    '-o', 'build/symtab_test.exe',
    'tests/tools/symtab_driver.c', 'src/symtab.c'
)

Write-Host ''
Write-Host 'Compilacion exitosa: build\compilador.exe, lexer_test.exe, ast_test.exe y symtab_test.exe'