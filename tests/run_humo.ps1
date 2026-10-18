# run_humo.ps1 - Pruebas de humo de la infraestructura (Fase 1).
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_humo.ps1

$Raiz = Split-Path -Parent $PSScriptRoot
$Exe  = Join-Path $Raiz 'build\compilador.exe'

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "No existe $Exe. Ejecuta primero build.ps1"
    exit 1
}

function Ejecutar([string]$Archivo) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $psi.Arguments = '"' + $Archivo + '"'
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $salida = $p.StandardOutput.ReadToEnd()
    $error_ = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ Codigo = $p.ExitCode; Out = $salida; Err = $error_ }
}

$fallos = 0

function Verificar([string]$Id, [string]$Descripcion, [bool]$Condicion, $R) {
    if ($Condicion) {
        Write-Host "[PASS] $Id - $Descripcion"
    } else {
        Write-Host "[FAIL] $Id - $Descripcion"
        Write-Host "       codigo: $($R.Codigo)"
        Write-Host "       stdout: $($R.Out)"
        Write-Host "       stderr: $($R.Err)"
        $script:fallos++
    }
}

$r1 = Ejecutar (Join-Path $PSScriptRoot 'humo\valido.olc')
Verificar 'H01' 'entrada valida: codigo 0 y resultado 46' (
    ($r1.Codigo -eq 0) -and
    $r1.Out.Contains('Resultado de humo: 46') -and
    $r1.Out.Contains('Analisis sintactico exitoso.')
) $r1

$r2 = Ejecutar (Join-Path $PSScriptRoot 'humo\invalido.olc')
Verificar 'H02' 'entrada invalida: codigo 1 y error sintactico en linea 1' (
    ($r2.Codigo -eq 1) -and
    $r2.Err.Contains('Error sintactico en linea 1')
) $r2

Write-Host ''
if ($fallos -eq 0) { Write-Host 'Pruebas de humo: todas aprobadas'; exit 0 }
Write-Host "Pruebas de humo: $fallos fallida(s)"
exit 1