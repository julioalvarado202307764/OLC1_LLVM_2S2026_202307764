# run_symtab.ps1 - Pruebas de la tabla de simbolos (CP4a, Fase 4).
# Usa build\symtab_test.exe, que ejecuta comandos sobre la tabla.
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_symtab.ps1

$Raiz = Split-Path -Parent $PSScriptRoot
$Exe  = Join-Path $Raiz 'build\symtab_test.exe'
$Tmp  = Join-Path $Raiz 'build\tests\symtab'

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "No existe $Exe. Ejecuta primero build.ps1"
    exit 1
}
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

function Ejecutar([string]$Argumentos) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
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

# Escenario grande: 50 simbolos para forzar el crecimiento del arreglo.
$cmds50 = @()
$esp50 = @()
for ($i = 1; $i -le 50; $i++) {
    $cmds50 += "insertar v$i i32 $i 1"
    $esp50 += "INSERTADO v$i"
}
$cmds50 += "contar"
$cmds50 += "buscar v1"
$cmds50 += "buscar v50"
$esp50 += "CANTIDAD 50"
$esp50 += "ENCONTRADO v1 i32 @1:1"
$esp50 += "ENCONTRADO v50 i32 @50:1"
$esp50 += "SIMBOLOS_VIVOS=0"

# Cada caso: Id, descripcion, comandos y salida esperada (stdout, linea por linea).
$casos = @(
    @{ Id = 'ST01'; Desc = 'insertar y buscar un simbolo';
       Fuente = "insertar n i32 1 5`nbuscar n";
       Salida = @("INSERTADO n", "ENCONTRADO n i32 @1:5", "SIMBOLOS_VIVOS=0") },

    @{ Id = 'ST02'; Desc = 'buscar un simbolo inexistente';
       Fuente = "buscar x";
       Salida = @("NO_ENCONTRADO x", "SIMBOLOS_VIVOS=0") },

    @{ Id = 'ST03'; Desc = 'duplicado: se rechaza y se conserva el original';
       Fuente = "insertar x i32 1 5`ninsertar x double 2 5`nbuscar x";
       Salida = @("INSERTADO x", "DUPLICADO x", "ENCONTRADO x i32 @1:5", "SIMBOLOS_VIVOS=0") },

    @{ Id = 'ST04'; Desc = 'orden de insercion (escenario de la Fig. 7)';
       Fuente = "insertar n i32 1 5`ninsertar m double 2 5`ninsertar t double 3 5`nvolcar";
       Salida = @("INSERTADO n", "INSERTADO m", "INSERTADO t", "TABLA 3", "  n : i32 @1:5", "  m : double @2:5", "  t : double @3:5", "SIMBOLOS_VIVOS=0") },

    @{ Id = 'ST05'; Desc = 'distingue mayusculas de minusculas';
       Fuente = "insertar a i32 1 1`ninsertar A double 2 1`nbuscar a`nbuscar A";
       Salida = @("INSERTADO a", "INSERTADO A", "ENCONTRADO a i32 @1:1", "ENCONTRADO A double @2:1", "SIMBOLOS_VIVOS=0") },

    @{ Id = 'ST06'; Desc = 'tabla vacia';
       Fuente = "volcar";
       Salida = @("TABLA 0", "SIMBOLOS_VIVOS=0") },

    @{ Id = 'ST07'; Desc = 'crecimiento con 50 simbolos';
       Fuente = ($cmds50 -join "`n");
       Salida = $esp50 },

    @{ Id = 'ST08'; Desc = 'simbolo con tipo error';
       Fuente = "insertar bad error 3 5`nbuscar bad";
       Salida = @("INSERTADO bad", "ENCONTRADO bad error @3:5", "SIMBOLOS_VIVOS=0") },

    @{ Id = 'ST09'; Desc = 'la busqueda no acepta prefijos';
       Fuente = "insertar ab i32 1 1`nbuscar a`nbuscar abc";
       Salida = @("INSERTADO ab", "NO_ENCONTRADO a", "NO_ENCONTRADO abc", "SIMBOLOS_VIVOS=0") }
)

$aprobadas = 0
$fallidas = 0

foreach ($c in $casos) {
    $ruta = Join-Path $Tmp ($c.Id + '.txt')
    [System.IO.File]::WriteAllText($ruta, $c.Fuente)

    $r = Ejecutar ('"' + $ruta + '"')
    $esperado = $c.Salida -join "`n"
    $obtenido = Normalizar $r.Out

    if (($r.Codigo -eq 0) -and ($obtenido -ceq $esperado) -and ($r.Err.Length -eq 0)) {
        Write-Host "[PASS] $($c.Id) - $($c.Desc)"
        $aprobadas++
    } else {
        Write-Host "[FAIL] $($c.Id) - $($c.Desc)"
        Write-Host "       codigo: $($r.Codigo)"
        Write-Host "       --- stdout esperado ---"
        Write-Host $esperado
        Write-Host "       --- stdout obtenido ---"
        Write-Host $obtenido
        Write-Host "       --- stderr obtenido ---"
        Write-Host $r.Err
        $fallidas++
    }
}

Write-Host ''
Write-Host "Pruebas de la tabla de simbolos: $aprobadas aprobadas, $fallidas fallidas"
if ($fallidas -gt 0) { exit 1 }
exit 0