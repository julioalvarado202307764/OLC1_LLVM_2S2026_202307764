# run_todo.ps1 - Reconstruye el proyecto y ejecuta todas las suites (CP7, Fase 7).
# Uso (desde la raiz del proyecto):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_todo.ps1
# Parametro opcional -Detalle: muestra la salida completa de cada suite.

param([switch]$Detalle)

$Raiz          = Split-Path -Parent $PSScriptRoot
$PowerShellExe = (Get-Process -Id $PID).Path

function LineasDe([string]$Texto) {
    return (($Texto -replace "`r", '') -split "`n")
}

function Ejecutar([string]$Programa, [string]$Argumentos) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Programa
    $psi.Arguments = $Argumentos
    $psi.WorkingDirectory = $Raiz
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $tareaErr = $p.StandardError.ReadToEndAsync()
    $salida = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return @{ Codigo = $p.ExitCode; Out = $salida; Err = $tareaErr.Result }
}

function EjecutarScript([string]$Script) {
    return Ejecutar $PowerShellExe ('-NoProfile -ExecutionPolicy Bypass -File "' + $Script + '"')
}

# --- Estado del repositorio (informativo) ---------------------------------------
Write-Host '=== Estado del repositorio ==='
$git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
if ($git) {
    $h = Ejecutar $git.Source ('-C "' + $Raiz + '" log -1 --oneline')
    Write-Host ("Ultimo commit: " + $h.Out.Trim())
    $s = Ejecutar $git.Source ('-C "' + $Raiz + '" status --porcelain')
    $cambios = @((LineasDe $s.Out) | Where-Object { $_.Trim() -ne '' })
    Write-Host ("Cambios sin commit: " + $cambios.Count)
} else {
    Write-Host 'git no esta en el PATH (se omite esta informacion)'
}

# --- Compilacion desde cero ------------------------------------------------------
Write-Host ''
Write-Host '=== Compilacion desde cero (build.ps1) ==='
$b = EjecutarScript (Join-Path $Raiz 'build.ps1')
if ($b.Codigo -ne 0) {
    Write-Host "[FAIL] build.ps1 devolvio el codigo $($b.Codigo). Se detiene todo."
    Write-Host $b.Out
    if ($b.Err.Length -gt 0) { Write-Host $b.Err }
    exit 1
}
$ultima = (LineasDe $b.Out) | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1
Write-Host "[OK] $ultima"
if ($b.Err.Length -gt 0) {
    Write-Host '[AVISO] la compilacion escribio en stderr (avisos de las herramientas):'
    Write-Host $b.Err
}

# --- Suites -----------------------------------------------------------------------
$suites = @(
    @{ Nombre = 'LX lexer';       Script = 'tests\run_lexer.ps1';      Esperadas = 12 },
    @{ Nombre = 'SX sintaxis';    Script = 'tests\run_sintaxis.ps1';   Esperadas = 17 },
    @{ Nombre = 'AS AST';         Script = 'tests\run_ast.ps1';        Esperadas = 12 },
    @{ Nombre = 'ST simbolos';    Script = 'tests\run_symtab.ps1';     Esperadas = 13 },
    @{ Nombre = 'SM semantica';   Script = 'tests\run_semantica.ps1';  Esperadas = 14 },
    @{ Nombre = 'IR generacion';  Script = 'tests\run_ir.ps1';         Esperadas = 18 },
    @{ Nombre = 'VL validacion';  Script = 'tests\run_validacion.ps1'; Esperadas = 24 },
    @{ Nombre = 'OB objetos ARM'; Script = 'tests\run_objeto.ps1';     Esperadas = 7 }
)

$resultados = @()
$totalEsperadas = 0
foreach ($suite in $suites) { $totalEsperadas += $suite.Esperadas }

foreach ($suite in $suites) {
    $ruta = Join-Path $Raiz $suite.Script
    Write-Host ''
    Write-Host "=== $($suite.Nombre) ($($suite.Script)) ==="

    if (-not (Test-Path -LiteralPath $ruta)) {
        Write-Host '[FAIL] no existe el script de la suite'
        $resultados += @{ Nombre = $suite.Nombre; Esperadas = $suite.Esperadas; Aprobadas = 0; Fallidas = 0; Estado = 'FALTA EL SCRIPT' }
        continue
    }

    $r = EjecutarScript $ruta
    $aprobadas = 0
    $fallidas = 0
    $coincidencias = [regex]::Matches($r.Out, '(\d+) aprobadas, (\d+) fallidas')
    $hayResumen = ($coincidencias.Count -gt 0)
    if ($hayResumen) {
        $ultimaCoincidencia = $coincidencias[$coincidencias.Count - 1]
        $aprobadas = [int]$ultimaCoincidencia.Groups[1].Value
        $fallidas = [int]$ultimaCoincidencia.Groups[2].Value
    }

    if (-not $hayResumen) {
        $estado = 'SIN RESUMEN'
    } elseif (($r.Codigo -ne 0) -or ($fallidas -gt 0)) {
        $estado = 'FALLA'
    } elseif ($aprobadas -ne $suite.Esperadas) {
        $estado = 'RECUENTO DISTINTO'
    } else {
        $estado = 'OK'
    }

    if (($estado -ne 'OK') -or $Detalle) {
        Write-Host $r.Out
    } else {
        foreach ($l in (LineasDe $r.Out)) {
            if (($l -match '^\[(PASS|FAIL)\]') -or ($l -match '\d+ aprobadas, \d+ fallidas')) {
                Write-Host $l
            }
        }
    }
    if ($r.Err.Length -gt 0) {
        Write-Host "[AVISO] la suite escribio en stderr:"
        Write-Host $r.Err
    }

    $resultados += @{ Nombre = $suite.Nombre; Esperadas = $suite.Esperadas; Aprobadas = $aprobadas; Fallidas = $fallidas; Estado = $estado }
}

# --- Resumen ------------------------------------------------------------------------
Write-Host ''
Write-Host '=== Resumen por suite ==='
Write-Host ('{0,-16} {1,9} {2,9} {3,9}  {4}' -f 'Suite', 'Esperadas', 'Aprobadas', 'Fallidas', 'Estado')
$totalAprobadas = 0
$totalFallidas = 0
$todoOk = $true
foreach ($x in $resultados) {
    Write-Host ('{0,-16} {1,9} {2,9} {3,9}  {4}' -f $x.Nombre, $x.Esperadas, $x.Aprobadas, $x.Fallidas, $x.Estado)
    $totalAprobadas += $x.Aprobadas
    $totalFallidas += $x.Fallidas
    if ($x.Estado -ne 'OK') { $todoOk = $false }
}

Write-Host ''
Write-Host "TOTAL: $totalAprobadas aprobadas, $totalFallidas fallidas (esperadas $totalEsperadas)"
if ($todoOk -and ($totalAprobadas -eq $totalEsperadas) -and ($totalFallidas -eq 0)) {
    Write-Host 'RESULTADO: todas las suites coinciden con lo esperado.'
} else {
    Write-Host 'RESULTADO: hay suites con fallos o con un recuento distinto del esperado. No se da por aprobado.'
}
Write-Host 'Nota: las pruebas OB solo generan objetos ARM. No hay enlace, firmware ni ejecucion en la placa.'

if ($todoOk -and ($totalAprobadas -eq $totalEsperadas) -and ($totalFallidas -eq 0)) { exit 0 }
exit 1