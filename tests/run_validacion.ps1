# run_validacion.ps1 - Validacion del LLVM IR generado con las herramientas LLVM
# (CP5b, Fase 5). Usa build\compilador.exe, llvm-as y opt.
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_validacion.ps1

$Raiz     = Split-Path -Parent $PSScriptRoot
$Exe      = Join-Path $Raiz 'build\compilador.exe'
$Tmp      = Join-Path $Raiz 'build\tests\validacion'
$Ejemplos = Join-Path $Raiz 'ejemplos'

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "No existe $Exe. Ejecuta primero build.ps1"
    exit 1
}
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

function Find-Tool([string[]]$Names) {
    foreach ($n in $Names) {
        $c = Get-Command $n -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return $c.Source }
    }
    throw "No se encontro ninguna de estas herramientas en el PATH: $($Names -join ', ')"
}

function Ejecutar([string]$Programa, [string]$Argumentos) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Programa
    $psi.Arguments = $Argumentos
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $salida = $p.StandardOutput.ReadToEnd()
    $error_ = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ Codigo = $p.ExitCode; Out = $salida; Err = $error_ }
}

function Normalizar([string]$Texto) {
    return ($Texto -replace "`r", '').TrimEnd("`n")
}

$LlvmAs = Find-Tool @('llvm-as')
$Opt    = Find-Tool @('opt')

Write-Host "llvm-as: $LlvmAs"
Write-Host "opt:     $Opt"
$version = Ejecutar $Opt '--version'
foreach ($l in (($version.Out -replace "`r", '') -split "`n")) {
    if ($l.Trim() -ne '') { Write-Host "         $($l.Trim())" }
}
Write-Host ''

$aprobadas = 0
$fallidas = 0

function Registrar([string]$Id, [string]$Desc, [bool]$Ok, [string]$Info, [string]$Detalle) {
    if ($Ok) {
        Write-Host "[PASS] $Id - $Desc"
        if ($Info -ne '') { Write-Host "       $Info" }
        $script:aprobadas++
    } else {
        Write-Host "[FAIL] $Id - $Desc"
        if ($Info -ne '') { Write-Host "       $Info" }
        if ($Detalle -ne '') { Write-Host $Detalle }
        $script:fallidas++
    }
}

# Compila una fuente con el compilador y devuelve la ruta del .ll y el resultado.
function Compilar([string]$Id, [string]$Fuente) {
    $olc = Join-Path $Tmp ($Id + '.olc')
    $ll  = Join-Path $Tmp ($Id + '.ll')
    if (Test-Path -LiteralPath $ll) { Remove-Item -LiteralPath $ll }
    [System.IO.File]::WriteAllText($olc, $Fuente)
    $r = Ejecutar $Exe ('"' + $olc + '" -o "' + $ll + '"')
    return @{ Ll = $ll; Codigo = $r.Codigo; Out = $r.Out; Err = $r.Err }
}

# Pasa un .ll por llvm-as (ensambla y verifica) y por opt -passes=verify.
function ValidarConLlvm([string]$Ll) {
    $bc = Join-Path $Tmp ([System.IO.Path]::GetFileNameWithoutExtension($Ll) + '.bc')
    $a = Ejecutar $LlvmAs ('"' + $Ll + '" -o "' + $bc + '"')
    $o = Ejecutar $Opt ('-passes=verify -disable-output "' + $Ll + '"')
    return @{ AsCodigo = $a.Codigo; AsErr = $a.Err; OptCodigo = $o.Codigo; OptErr = $o.Err }
}

function DetalleValidacion($v) {
    return "       llvm-as: codigo $($v.AsCodigo) $($v.AsErr)`n       opt:     codigo $($v.OptCodigo) $($v.OptErr)"
}

# --- Grupo A: el IR generado es aceptado por llvm-as y por opt ---------------
$programas = @(
    @{ Id = 'VL01'; Desc = 'ejemplo entero del enunciado (4.2)';
       Fuente = "let a = 10;`nlet b = 20;`nlet resultado = a + b * 2;`nprint resultado;" },
    @{ Id = 'VL02'; Desc = 'ejemplo decimal del enunciado (4.8)';
       Fuente = "let ancho = 10.5;`nlet alto = 20.0;`nlet area = ancho * alto;`nprint area;" },
    @{ Id = 'VL03'; Desc = 'ejemplo de la Fig. 2: 10 + 20 * 3';
       Fuente = "print 10 + 20 * 3;" },
    @{ Id = 'VL04'; Desc = 'los cuatro operadores enteros';
       Fuente = "print 8 + 2;`nprint 8 - 2;`nprint 8 * 2;`nprint 8 / 2;" },
    @{ Id = 'VL05'; Desc = 'los cuatro operadores decimales';
       Fuente = "print 8.5 + 2.5;`nprint 8.5 - 2.5;`nprint 8.5 * 2.5;`nprint 8.5 / 2.5;" },
    @{ Id = 'VL06'; Desc = 'variables propagadas, enteras y decimales';
       Fuente = "let a = 5;`nlet b = a;`nlet c = 2.5;`nprint b;`nprint c;" },
    @{ Id = 'VL07'; Desc = 'parentesis y variables';
       Fuente = "let x = 4;`nlet y = (x + 2) * (x - 1);`nprint y;" },
    @{ Id = 'VL08'; Desc = 'asociatividad izquierda: 10 - 3 - 2';
       Fuente = "print 10 - 3 - 2;" },
    @{ Id = 'VL09'; Desc = 'decimales con variables (25.5 y 4.0)';
       Fuente = "let p = 25.5;`nlet c = 4.0;`nlet t = p * c;`nprint t;" },
    @{ Id = 'VL10'; Desc = 'literales 0.1, 10.5 y 20.0 en una misma expresion';
       Fuente = "print 0.1 + 10.5 * 20.0;" },
    @{ Id = 'VL11'; Desc = 'decimal muy grande y muy pequeno (forma hexadecimal)';
       Fuente = "print 100000000000000000000.0 + 0.000001;" },
    @{ Id = 'VL12'; Desc = 'ceros: print 0; y print 0.0;';
       Fuente = "print 0;`nprint 0.0;" }
)

foreach ($c in $programas) {
    $g = Compilar $c.Id $c.Fuente
    if (($g.Codigo -ne 0) -or (-not (Test-Path -LiteralPath $g.Ll))) {
        Registrar $c.Id $c.Desc $false '' "       el compilador fallo (codigo $($g.Codigo)): $($g.Err)"
        continue
    }
    $v = ValidarConLlvm $g.Ll
    $ok = (($v.AsCodigo -eq 0) -and ($v.OptCodigo -eq 0))
    Registrar $c.Id $c.Desc $ok '' (DetalleValidacion $v)
}

# --- Grupo B: los literales double tienen el valor correcto -------------------
# Se compara el literal que emite el compilador con una referencia independiente,
# tal como los interpreta LLVM (opt -S imprime ambos valores en forma canonica).
$literales = @(
    @{ Id = 'VL13'; Desc = 'literal 0.1';  Fuente = "print 0.1;";  Ref = '0x3FB999999999999A' },
    @{ Id = 'VL14'; Desc = 'literal 10.5'; Fuente = "print 10.5;"; Ref = '0x4025000000000000' },
    @{ Id = 'VL15'; Desc = 'literal 20.0'; Fuente = "print 20.0;"; Ref = '0x4034000000000000' },
    @{ Id = 'VL16'; Desc = 'literal 0.3';  Fuente = "print 0.3;";  Ref = '0x3FD3333333333333' },
    @{ Id = 'VL17'; Desc = 'literal muy grande (el compilador usa hexadecimal)';
       Fuente = "print 100000000000000000000.0;"; Ref = '100000000000000000000.0' },
    @{ Id = 'VL18'; Desc = 'literal muy pequeno (el compilador usa hexadecimal)';
       Fuente = "print 0.000001;"; Ref = '0.000001' }
)

foreach ($c in $literales) {
    $g = Compilar $c.Id $c.Fuente
    if (($g.Codigo -ne 0) -or (-not (Test-Path -LiteralPath $g.Ll))) {
        Registrar $c.Id $c.Desc $false '' "       el compilador fallo (codigo $($g.Codigo)): $($g.Err)"
        continue
    }

    $texto = [System.IO.File]::ReadAllText($g.Ll)
    $m = [regex]::Match($texto, '@print_f64\(double ([^\)]+)\)')
    if (-not $m.Success) {
        Registrar $c.Id $c.Desc $false '' "       no se encontro el literal en el IR:`n$texto"
        continue
    }
    $lit = $m.Groups[1].Value

    $modulo = "define double @decimal() {`nentry:`n  ret double $lit`n}`n`n" +
              "define double @referencia() {`nentry:`n  ret double $($c.Ref)`n}`n"
    $archivo = Join-Path $Tmp ($c.Id + '_literales.ll')
    [System.IO.File]::WriteAllText($archivo, $modulo)

    $o = Ejecutar $Opt ('-passes=verify -S "' + $archivo + '" -o -')
    $valores = [regex]::Matches($o.Out, 'ret double (\S+)')
    $ok = (($o.Codigo -eq 0) -and ($valores.Count -eq 2) -and
           ($valores[0].Groups[1].Value -ceq $valores[1].Groups[1].Value))

    $info = "compilador emitio: $lit | referencia: $($c.Ref)"
    if ($valores.Count -eq 2) {
        $info = $info + " | LLVM lee: $($valores[0].Groups[1].Value) y $($valores[1].Groups[1].Value)"
    }
    Registrar $c.Id $c.Desc $ok $info "       opt codigo $($o.Codigo): $($o.Err)`n$($o.Out)"
}

# --- Grupo C: control negativo (un IR invalido debe ser rechazado) ------------
$invalido = Join-Path $Tmp 'invalido.ll'
[System.IO.File]::WriteAllText($invalido, "define i32 @main() {`nentry:`n  %t1 = add i32 1, 2.5`n  ret i32 0`n}`n")

$bcInvalido = Join-Path $Tmp 'invalido.bc'
$a = Ejecutar $LlvmAs ('"' + $invalido + '" -o "' + $bcInvalido + '"')
Registrar 'VL19' 'control negativo: llvm-as rechaza un IR invalido' ($a.Codigo -ne 0) `
    "llvm-as codigo $($a.Codigo)" "       llvm-as acepto un IR invalido"

$o = Ejecutar $Opt ('-passes=verify -disable-output "' + $invalido + '"')
Registrar 'VL20' 'control negativo: opt rechaza un IR invalido' ($o.Codigo -ne 0) `
    "opt codigo $($o.Codigo)" "       opt acepto un IR invalido"

# --- Grupo D: ejemplos versionados en ejemplos\ --------------------------------
$ejemplosCasos = @(
    @{ Nombre = 'area';      IdCoincide = 'VL21'; IdValida = 'VL22' },
    @{ Nombre = 'resultado'; IdCoincide = 'VL23'; IdValida = 'VL24' }
)

foreach ($e in $ejemplosCasos) {
    $olc = Join-Path $Ejemplos ($e.Nombre + '.olc')
    $llv = Join-Path $Ejemplos ($e.Nombre + '.ll')
    $descC = "ejemplos\$($e.Nombre).ll coincide con lo que genera el compilador"
    $descV = "ejemplos\$($e.Nombre).ll es aceptado por llvm-as y opt"

    if ((-not (Test-Path -LiteralPath $olc)) -or (-not (Test-Path -LiteralPath $llv))) {
        Registrar $e.IdCoincide $descC $false '' "       falta ejemplos\$($e.Nombre).olc o ejemplos\$($e.Nombre).ll"
        Registrar $e.IdValida $descV $false '' "       falta ejemplos\$($e.Nombre).olc o ejemplos\$($e.Nombre).ll"
        continue
    }

    $regenerado = Join-Path $Tmp ('ejemplo_' + $e.Nombre + '.ll')
    if (Test-Path -LiteralPath $regenerado) { Remove-Item -LiteralPath $regenerado }
    $r = Ejecutar $Exe ('"' + $olc + '" -o "' + $regenerado + '"')

    $versionado = Normalizar ([System.IO.File]::ReadAllText($llv))
    $actual = ''
    if (Test-Path -LiteralPath $regenerado) { $actual = Normalizar ([System.IO.File]::ReadAllText($regenerado)) }
    $okC = (($r.Codigo -eq 0) -and ($versionado -ceq $actual))
    Registrar $e.IdCoincide $descC $okC '' "       --- versionado ---`n$versionado`n       --- regenerado ---`n$actual"

    $v = ValidarConLlvm $llv
    $okV = (($v.AsCodigo -eq 0) -and ($v.OptCodigo -eq 0))
    Registrar $e.IdValida $descV $okV '' (DetalleValidacion $v)
}

Write-Host ''
Write-Host "Pruebas de validacion con LLVM: $aprobadas aprobadas, $fallidas fallidas"
if ($fallidas -gt 0) { exit 1 }
exit 0