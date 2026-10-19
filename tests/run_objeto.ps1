# run_objeto.ps1 - Generacion de codigo objeto para la Raspberry Pi Pico (CP6, Fase 6).
# Usa build\compilador.exe, llc y llvm-objdump sobre el IR real del compilador.
# No enlaza ni genera firmware: eso depende del runtime del docente.
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_objeto.ps1

$Raiz     = Split-Path -Parent $PSScriptRoot
$Exe      = Join-Path $Raiz 'build\compilador.exe'
$Tmp      = Join-Path $Raiz 'build\tests\objeto'
$Ejemplos = Join-Path $Raiz 'ejemplos'
$Triple   = 'thumbv6m-none-eabi'
$Cpu      = 'cortex-m0plus'

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

function LineasDe([string]$Texto) {
    return (($Texto -replace "`r", '') -split "`n")
}

$LlcExe     = Find-Tool @('llc')
$ObjDumpExe = Find-Tool @('llvm-objdump')

Write-Host "llc:          $LlcExe"
Write-Host "llvm-objdump: $ObjDumpExe"
$v = Ejecutar $LlcExe '--version'
foreach ($l in (LineasDe $v.Out)) {
    if (($l -match 'LLVM version') -or ($l -match '^\s+(arm|thumb)\s')) {
        Write-Host "              $($l.Trim())"
    }
}
Write-Host "Objetivo:     $Triple, CPU $Cpu"
Write-Host ''

function InvocarLlc([string]$Ll, [string]$Salida, [string]$Tipo, [string]$Nivel) {
    $a = "-mtriple=$Triple -mcpu=$Cpu -filetype=$Tipo"
    if ($Nivel -ne '') { $a = $a + ' ' + $Nivel }
    $a = $a + ' "' + $Ll + '" -o "' + $Salida + '"'
    return Ejecutar $LlcExe $a
}

# Cabecera ELF32 (52 bytes): bytes 0-3 magia, 4 clase (1 = 32 bits), 5 orden
# (1 = little-endian), 18-19 maquina (40 = ARM), 36-39 e_flags (byte 39 = version EABI).
function EsObjetoArm([string]$Ruta) {
    if (-not (Test-Path -LiteralPath $Ruta)) { return $false }
    $b = [System.IO.File]::ReadAllBytes($Ruta)
    if ($b.Length -lt 52) { return $false }
    return (($b[0] -eq 0x7F) -and ($b[1] -eq 0x45) -and ($b[2] -eq 0x4C) -and ($b[3] -eq 0x46) -and
            ($b[4] -eq 1) -and ($b[5] -eq 1) -and ($b[18] -eq 0x28) -and ($b[19] -eq 0) -and
            ($b[39] -eq 5))
}

function CabeceraHex([string]$Ruta) {
    if (-not (Test-Path -LiteralPath $Ruta)) { return '(no existe)' }
    $b = [System.IO.File]::ReadAllBytes($Ruta)
    $n = [Math]::Min(40, $b.Length)
    $partes = @()
    for ($i = 0; $i -lt $n; $i++) { $partes += ('{0:X2}' -f $b[$i]) }
    return ($partes -join ' ')
}

# Nombres de simbolos sin resolver (lineas con *UND* de llvm-objdump -t).
function SimbolosSinResolver([string]$Texto) {
    $nombres = @()
    foreach ($l in (LineasDe $Texto)) {
        if ($l -match '\*UND\*') {
            $partes = $l.Trim() -split '\s+'
            $ultimo = $partes[$partes.Count - 1]
            if ($ultimo -match '^[A-Za-z_]') { $nombres += $ultimo }
        }
    }
    return $nombres
}

# Un simbolo esta definido si hay una linea que termina en su nombre y no es *UND*.
function SimboloDefinido([string]$Texto, [string]$Nombre) {
    foreach ($l in (LineasDe $Texto)) {
        if (($l -notmatch '\*UND\*') -and ($l -match ('\s' + $Nombre + '\s*$'))) { return $true }
    }
    return $false
}

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

# --- OB01-OB05: objetos generados desde el IR real del compilador --------------
$programas = @(
    @{ Id = 'OB01'; Desc = 'ejemplo entero del enunciado (ejemplos\resultado.olc)';
       Archivo = 'resultado.olc'; I32 = $true; F64 = $false },
    @{ Id = 'OB02'; Desc = 'ejemplo decimal del enunciado (ejemplos\area.olc)';
       Archivo = 'area.olc'; I32 = $false; F64 = $true },
    @{ Id = 'OB03'; Desc = 'enteros con los cuatro operadores (add, sub, mul, sdiv)';
       Fuente = "print 8 + 2;`nprint 8 - 2;`nprint 8 * 2;`nprint 8 / 2;"; I32 = $true; F64 = $false },
    @{ Id = 'OB04'; Desc = 'decimales con los cuatro operadores (fadd, fsub, fmul, fdiv)';
       Fuente = "print 8.5 + 2.5;`nprint 8.5 - 2.5;`nprint 8.5 * 2.5;`nprint 8.5 / 2.5;"; I32 = $false; F64 = $true },
    @{ Id = 'OB05'; Desc = 'programa mixto, entero y decimal';
       Fuente = "let a = 7;`nlet b = 2.5;`nprint a * 3;`nprint b / 0.5;"; I32 = $true; F64 = $true }
)

foreach ($c in $programas) {
    if ($c.Archivo) {
        $olc = Join-Path $Ejemplos $c.Archivo
    } else {
        $olc = Join-Path $Tmp ($c.Id + '.olc')
        [System.IO.File]::WriteAllText($olc, $c.Fuente)
    }
    $ll   = Join-Path $Tmp ($c.Id + '.ll')
    $obj  = Join-Path $Tmp ($c.Id + '.o')
    $asm  = Join-Path $Tmp ($c.Id + '.s')
    $obj0 = Join-Path $Tmp ($c.Id + '_O0.o')
    foreach ($f in @($ll, $obj, $asm, $obj0)) {
        if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f }
    }

    $rc = Ejecutar $Exe ('"' + $olc + '" -o "' + $ll + '"')
    if (($rc.Codigo -ne 0) -or (-not (Test-Path -LiteralPath $ll))) {
        Registrar $c.Id $c.Desc $false '' "       el compilador fallo (codigo $($rc.Codigo)): $($rc.Err)"
        continue
    }

    $fallos = @()
    $und = @()
    $tablaTexto = ''

    # Objeto
    $ro = InvocarLlc $ll $obj 'obj' ''
    if ($ro.Codigo -ne 0) {
        $fallos += "llc (objeto) devolvio el codigo $($ro.Codigo): $($ro.Err)"
    } elseif ((-not (Test-Path -LiteralPath $obj)) -or ((Get-Item -LiteralPath $obj).Length -eq 0)) {
        $fallos += "llc no genero el objeto, o esta vacio"
    } else {
        if (-not (EsObjetoArm $obj)) {
            $fallos += "la cabecera ELF no es ARM EABI5 de 32 bits little-endian: $(CabeceraHex $obj)"
        }
        $t = Ejecutar $ObjDumpExe ('-t "' + $obj + '"')
        $tablaTexto = $t.Out
        if ($t.Codigo -ne 0) {
            $fallos += "llvm-objdump -t devolvio el codigo $($t.Codigo): $($t.Err)"
        }
        if (-not (SimboloDefinido $t.Out 'main')) {
            $fallos += "main no aparece definido en el objeto"
        }
        $und = SimbolosSinResolver $t.Out
        $tieneI32 = ($und -contains 'print_i32')
        $tieneF64 = ($und -contains 'print_f64')
        if ($c.I32 -and (-not $tieneI32)) { $fallos += "print_i32 deberia aparecer sin resolver" }
        if ((-not $c.I32) -and $tieneI32) { $fallos += "print_i32 no deberia aparecer" }
        if ($c.F64 -and (-not $tieneF64)) { $fallos += "print_f64 deberia aparecer sin resolver" }
        if ((-not $c.F64) -and $tieneF64) { $fallos += "print_f64 no deberia aparecer" }
    }

    # Ensamblador
    $ra = InvocarLlc $ll $asm 'asm' ''
    if (($ra.Codigo -ne 0) -or (-not (Test-Path -LiteralPath $asm))) {
        $fallos += "llc (ensamblador) devolvio el codigo $($ra.Codigo): $($ra.Err)"
    } else {
        $textoAsm = [System.IO.File]::ReadAllText($asm)
        if ($c.I32 -and ($textoAsm -notmatch '\bbl\s+print_i32\b')) {
            $fallos += "el ensamblador no contiene una llamada bl a print_i32"
        }
        if ($c.F64 -and ($textoAsm -notmatch '\bbl\s+print_f64\b')) {
            $fallos += "el ensamblador no contiene una llamada bl a print_f64"
        }
    }

    # Informacion (sin aserciones): simbolos sin resolver con -O0
    $info0 = ''
    $r0 = InvocarLlc $ll $obj0 'obj' '-O0'
    if (($r0.Codigo -eq 0) -and (Test-Path -LiteralPath $obj0)) {
        $t0 = Ejecutar $ObjDumpExe ('-t "' + $obj0 + '"')
        $und0 = SimbolosSinResolver $t0.Out
        $info0 = '-O0: sin resolver: ' + ($und0 -join ', ')
    } else {
        $info0 = "-O0: llc devolvio el codigo $($r0.Codigo)"
    }
    $info = 'sin resolver (nivel por defecto de llc): ' + ($und -join ', ') + "`n       " + $info0

    $detalle = "       " + ($fallos -join "`n       ") + "`n       --- llvm-objdump -t ---`n" + $tablaTexto
    Registrar $c.Id $c.Desc ($fallos.Count -eq 0) $info $detalle
}

# --- OB06: control, llc debe rechazar un IR invalido ---------------------------
$invalido = Join-Path $Tmp 'invalido.ll'
[System.IO.File]::WriteAllText($invalido, "define i32 @main() {`nentry:`n  %t1 = add i32 1, 2.5`n  ret i32 0`n}`n")
$rInv = InvocarLlc $invalido (Join-Path $Tmp 'invalido.o') 'obj' ''
Registrar 'OB06' 'control negativo: llc rechaza un IR invalido' ($rInv.Codigo -ne 0) `
    "llc codigo $($rInv.Codigo)" "       llc acepto un IR invalido"

# --- OB07: control, un objeto sin el triple ARM no debe pasar la comprobacion --
$llControl = Join-Path $Tmp 'OB01.ll'
$objHost = Join-Path $Tmp 'control_sin_triple.obj'
if (Test-Path -LiteralPath $objHost) { Remove-Item -LiteralPath $objHost }
$rHost = Ejecutar $LlcExe ('-filetype=obj "' + $llControl + '" -o "' + $objHost + '"')
$okHost = (($rHost.Codigo -eq 0) -and (Test-Path -LiteralPath $objHost) -and (-not (EsObjetoArm $objHost)))
Registrar 'OB07' 'control de arquitectura: un objeto generado sin el triple ARM no pasa la comprobacion' $okHost `
    ("primeros bytes del objeto sin triple: " + (CabeceraHex $objHost)) `
    "       llc codigo $($rHost.Codigo): $($rHost.Err)"

# --- Inspeccion informativa de los dos ejemplos (sin aserciones) ---------------
function MostrarInspeccion([string]$Id, [string]$Titulo) {
    $obj = Join-Path $Tmp ($Id + '.o')
    $asm = Join-Path $Tmp ($Id + '.s')
    Write-Host ''
    Write-Host "=================== Inspeccion: $Titulo ==================="
    if (Test-Path -LiteralPath $asm) {
        Write-Host '--- ensamblador (llc -filetype=asm) ---'
        Write-Host ([System.IO.File]::ReadAllText($asm))
    }
    if (Test-Path -LiteralPath $obj) {
        $operaciones = @(
            @('-f', 'cabecera del archivo (llvm-objdump -f)'),
            @('-t', 'tabla de simbolos (llvm-objdump -t)'),
            @('-s -j .ARM.attributes', 'atributos ARM (llvm-objdump -s -j .ARM.attributes)'),
            @('-d', 'desensamblado (llvm-objdump -d)')
        )
        foreach ($op in $operaciones) {
            $r = Ejecutar $ObjDumpExe ($op[0] + ' "' + $obj + '"')
            Write-Host "--- $($op[1]) ---"
            Write-Host $r.Out
            if ($r.Err.Length -gt 0) { Write-Host $r.Err }
        }
    }
}

MostrarInspeccion 'OB01' 'ejemplo entero (resultado.olc)'
MostrarInspeccion 'OB02' 'ejemplo decimal (area.olc)'

Write-Host ''
Write-Host "Pruebas de objeto: $aprobadas aprobadas, $fallidas fallidas"
Write-Host 'Nota: esto solo genera objetos. No se enlazo ni se genero firmware; el runtime, el enlace y la carga los provee el docente.'
if ($fallidas -gt 0) { exit 1 }
exit 0