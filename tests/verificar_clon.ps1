# verificar_clon.ps1 - Reproducibilidad desde un clon limpio del repositorio local
# (CP7, Fase 7). Clona el ultimo commit en una carpeta temporal, compila y ejecuta
# todas las suites alli. Solo prueba lo que esta versionado.
# Uso (desde la raiz del proyecto):
#   powershell -ExecutionPolicy Bypass -File .\tests\verificar_clon.ps1
# Parametro opcional -Conservar: no borra la carpeta temporal al terminar.

param([switch]$Conservar)

$Raiz          = Split-Path -Parent $PSScriptRoot
$PowerShellExe = (Get-Process -Id $PID).Path

$git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $git) {
    Write-Host 'No se encontro git en el PATH.'
    exit 1
}
$GitExe = $git.Source

function LineasDe([string]$Texto) {
    return (($Texto -replace "`r", '') -split "`n")
}

function Ejecutar([string]$Programa, [string]$Argumentos, [string]$Directorio) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Programa
    $psi.Arguments = $Argumentos
    $psi.WorkingDirectory = $Directorio
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $tareaErr = $p.StandardError.ReadToEndAsync()
    $salida = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return @{ Codigo = $p.ExitCode; Out = $salida; Err = $tareaErr.Result }
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

# --- RC01: el proyecto es la raiz de un repositorio Git local --------------------
$top = Ejecutar $GitExe ('-C "' + $Raiz + '" rev-parse --show-toplevel') $Raiz
$topNorm = (($top.Out.Trim()) -replace '/', '\').TrimEnd('\')
$okRepo = (($top.Codigo -eq 0) -and ($topNorm -ieq $Raiz.TrimEnd('\')))
Registrar 'RC01' 'el proyecto es la raiz de un repositorio Git local' $okRepo "raiz segun git: $topNorm" "       raiz del proyecto: $Raiz`n       $($top.Err)"
if (-not $okRepo) {
    Write-Host ''
    Write-Host "Verificacion del clon: $aprobadas aprobadas, $fallidas fallidas"
    exit 1
}

$headOrigen = (Ejecutar $GitExe ('-C "' + $Raiz + '" rev-parse HEAD') $Raiz).Out.Trim()

# --- Aviso: cambios sin commit en el origen (el clon no los incluye) --------------
$estado = Ejecutar $GitExe ('-C "' + $Raiz + '" status --porcelain') $Raiz
$cambios = @((LineasDe $estado.Out) | Where-Object { $_.Trim() -ne '' })
if ($cambios.Count -gt 0) {
    Write-Host "[AVISO] hay $($cambios.Count) cambio(s) sin commit en el repositorio de origen. El clon NO los incluye:"
    foreach ($c in $cambios) { Write-Host "        $c" }
} else {
    Write-Host '[INFO] no hay cambios sin commit en el repositorio de origen.'
}

# --- RC02: clon local en una carpeta temporal propia -------------------------------
$tmpBase = [System.IO.Path]::GetTempPath()
$destino = Join-Path $tmpBase ('olc1_clon_' + [guid]::NewGuid().ToString('N'))
if (Test-Path -LiteralPath $destino) {
    Write-Host "La ruta temporal ya existe y no se tocara: $destino"
    exit 1
}

$clonar = Ejecutar $GitExe ('clone --quiet "' + $Raiz + '" "' + $destino + '"') $Raiz
$creado = (Test-Path -LiteralPath $destino)

try {
    $headClon = ''
    if ($creado) {
        $headClon = (Ejecutar $GitExe ('-C "' + $destino + '" rev-parse HEAD') $destino).Out.Trim()
    }
    $okClon = (($clonar.Codigo -eq 0) -and $creado -and ($headClon -ne '') -and ($headClon -eq $headOrigen))
    $corto = ''
    if ($headClon.Length -ge 7) { $corto = $headClon.Substring(0, 7) }
    Registrar 'RC02' 'clon local creado y con el mismo HEAD que el origen' $okClon "clon en: $destino (HEAD $corto)" "       git clone devolvio $($clonar.Codigo): $($clonar.Err)`n       HEAD origen: $headOrigen`n       HEAD clon:   $headClon"

    if ($okClon) {
        # --- RC03: archivos necesarios presentes en el clon -------------------------
        $requeridos = @(
            '.gitignore', 'build.ps1',
            'src\lexer.l', 'src\parser.y', 'src\main.c',
            'src\ast.h', 'src\ast.c', 'src\errors.h', 'src\errors.c',
            'src\symtab.h', 'src\symtab.c', 'src\semantic.h', 'src\semantic.c',
            'src\codegen.h', 'src\codegen.c', 'src\tipos.h',
            'tests\run_lexer.ps1', 'tests\run_sintaxis.ps1', 'tests\run_ast.ps1',
            'tests\run_symtab.ps1', 'tests\run_semantica.ps1', 'tests\run_ir.ps1',
            'tests\run_validacion.ps1', 'tests\run_objeto.ps1',
            'tests\run_todo.ps1', 'tests\verificar_clon.ps1',
            'tests\tools\lexer_driver.c', 'tests\tools\ast_driver.c',
            'tests\tools\symtab_driver.c', 'tests\tools\semantic_driver.c',
            'ejemplos\area.olc', 'ejemplos\area.ll',
            'ejemplos\resultado.olc', 'ejemplos\resultado.ll'
        )
        $faltan = @()
        foreach ($f in $requeridos) {
            if (-not (Test-Path -LiteralPath (Join-Path $destino $f))) { $faltan += $f }
        }
        Registrar 'RC03' 'el clon contiene todos los archivos necesarios' ($faltan.Count -eq 0) `
            "$($requeridos.Count) archivos requeridos comprobados" `
            ("       faltan en el clon (probablemente sin commitear):`n       " + ($faltan -join "`n       "))

        # --- RC04: nada generado esta versionado ----------------------------------------
        $ls = Ejecutar $GitExe ('-C "' + $destino + '" ls-files') $destino
        $archivos = @((LineasDe $ls.Out) | Where-Object { $_.Trim() -ne '' })
        $generados = @()
        foreach ($a in $archivos) {
            if (($a -match '\.(o|obj|exe|bc)$') -or ($a -match '^build/') -or
                ($a -match 'lex\.yy\.c$') -or ($a -match 'parser\.tab\.[ch]$') -or
                ($a -match '\.output$')) {
                $generados += $a
            } elseif (($a -match '\.ll$') -and ($a -notmatch '^ejemplos/')) {
                $generados += $a
            }
        }
        Registrar 'RC04' 'no hay archivos generados versionados (los unicos .ll versionados son los de ejemplos/)' ($generados.Count -eq 0) `
            "$($archivos.Count) archivos versionados" `
            ("       archivos generados que estan versionados:`n       " + ($generados -join "`n       "))

        # --- RC05: compilacion desde cero y todas las suites dentro del clon ------------
        $todo = Join-Path $destino 'tests\run_todo.ps1'
        if (-not (Test-Path -LiteralPath $todo)) {
            Registrar 'RC05' 'compilacion y suites dentro del clon (run_todo.ps1)' $false '' "       no existe tests\run_todo.ps1 en el clon"
        } else {
            $rt = Ejecutar $PowerShellExe ('-NoProfile -ExecutionPolicy Bypass -File "' + $todo + '"') $destino
            Write-Host ''
            Write-Host '--- salida de run_todo.ps1 dentro del clon ---'
            Write-Host $rt.Out
            if ($rt.Err.Length -gt 0) { Write-Host $rt.Err }
            Write-Host '--- fin de la salida del clon ---'
            Write-Host ''

            $m = [regex]::Match($rt.Out, 'TOTAL: (\d+) aprobadas, (\d+) fallidas \(esperadas (\d+)\)')
            $okTodo = (($rt.Codigo -eq 0) -and $m.Success -and ($m.Groups[2].Value -eq '0') -and
                       ($m.Groups[1].Value -eq $m.Groups[3].Value))
            $infoTodo = 'run_todo.ps1 sin resumen TOTAL'
            if ($m.Success) { $infoTodo = "TOTAL en el clon: $($m.Groups[1].Value) aprobadas, $($m.Groups[2].Value) fallidas (esperadas $($m.Groups[3].Value))" }
            Registrar 'RC05' 'compilacion desde cero y todas las suites dentro del clon (run_todo.ps1)' $okTodo $infoTodo "       codigo de salida de run_todo.ps1: $($rt.Codigo)"
        }

        # --- Informacion sobre entregables pendientes (no cuenta como fallo) ------------
        $hayDoc = Test-Path -LiteralPath (Join-Path $destino 'DOCUMENTACION.md')
        $pdfs = @($archivos | Where-Object { $_ -match '\.pdf$' })
        if ($hayDoc) { Write-Host '[INFO] DOCUMENTACION.md: presente en el clon' }
        else { Write-Host '[INFO] DOCUMENTACION.md: aun no esta versionado (Fase 8)' }
        if ($pdfs.Count -gt 0) { Write-Host "[INFO] PDF versionados: $($pdfs -join ', ')" }
        else { Write-Host '[INFO] ensayo en PDF: aun no esta versionado (lo redactas tu)' }
    }
}
finally {
    # Solo se borra la carpeta que este script creo, si pasa todas estas comprobaciones.
    if ($Conservar) {
        Write-Host ''
        Write-Host "Se conserva el clon temporal en: $destino"
    } elseif ($creado) {
        $nombre = Split-Path -Leaf $destino
        $padre = (Split-Path -Parent $destino).TrimEnd('\')
        $esSeguro = ($nombre -like 'olc1_clon_*') -and ($padre -ieq $tmpBase.TrimEnd('\')) -and
                    ($destino.TrimEnd('\') -ine $Raiz.TrimEnd('\'))
        if ($esSeguro) {
            try {
                Remove-Item -LiteralPath $destino -Recurse -Force -ErrorAction Stop
                Write-Host ''
                Write-Host "[INFO] carpeta temporal eliminada: $destino"
            } catch {
                Write-Host ''
                Write-Host "[AVISO] no se pudo eliminar la carpeta temporal. Borrala a mano: $destino"
            }
        } else {
            Write-Host ''
            Write-Host "[AVISO] la ruta no paso la verificacion de seguridad y NO se borra: $destino"
        }
    }
}

Write-Host ''
Write-Host "Verificacion del clon: $aprobadas aprobadas, $fallidas fallidas"
Write-Host 'Nota: reproduce la compilacion y las pruebas desde lo versionado. No incluye enlace, firmware ni ejecucion en la placa.'
if (($fallidas -gt 0) -or ($aprobadas -lt 5)) { exit 1 }
exit 0