# verificar_entrega.ps1 - Comprobacion final de la entrega (CP8b, Fase 8).
# Solo LEE el estado de Git (no hace pull, push, fetch, reset ni commits) y ejecuta
# las verificaciones existentes. No lee ni evalua el contenido del ensayo.
# Uso (desde la raiz del repositorio):
#   powershell -ExecutionPolicy Bypass -File .\tests\verificar_entrega.ps1
# Parametros opcionales:
#   -SinPruebas : omite run_todo.ps1 y verificar_clon.ps1 (verificacion rapida, incompleta)
#   -Detalle    : muestra la salida completa de run_todo.ps1 y verificar_clon.ps1

param([switch]$SinPruebas, [switch]$Detalle)

$Raiz          = Split-Path -Parent $PSScriptRoot
$PowerShellExe = (Get-Process -Id $PID).Path

$Carne        = '202307764'
$NombreRepo   = 'OLC1_LLVM_2S2026_' + $Carne
$RamaEsperada = 'main'
$RutaEnsayo   = 'ensayo/ensayo.pdf'
$FechaLimite  = '2026-10-23'

$git = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $git) {
    Write-Host 'No se encontro git en el PATH.'
    exit 1
}
$GitExe = $git.Source

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

function InvocarGit([string]$Argumentos) {
    return Ejecutar $GitExe ('-C "' + $Raiz + '" ' + $Argumentos)
}

function EjecutarScript([string]$Script) {
    return Ejecutar $PowerShellExe ('-NoProfile -ExecutionPolicy Bypass -File "' + $Script + '"')
}

$resultados = @()

function Registrar([string]$Id, [string]$Desc, [string]$Estado, [string]$Nota) {
    Write-Host ('[{0}] {1} - {2}' -f $Estado, $Id, $Desc)
    if ($Nota -ne '') {
        foreach ($l in (LineasDe $Nota)) { Write-Host "         $l" }
    }
    $script:resultados += @{ Id = $Id; Desc = $Desc; Estado = $Estado }
}

function MostrarResumen {
    $aprobadas  = @($resultados | Where-Object { $_.Estado -eq 'APROBADO' }).Count
    $pendientes = @($resultados | Where-Object { $_.Estado -eq 'PENDIENTE' }).Count
    $fallidas   = @($resultados | Where-Object { $_.Estado -eq 'FALLIDO' }).Count
    $omitidas   = @($resultados | Where-Object { $_.Estado -eq 'OMITIDA' }).Count

    Write-Host ''
    Write-Host '=== Resumen ==='
    foreach ($r in $resultados) {
        Write-Host ('{0,-10} {1,-6} {2}' -f $r.Estado, $r.Id, $r.Desc)
    }
    Write-Host ''
    Write-Host "Resumen: $aprobadas aprobadas, $pendientes pendientes, $fallidas fallidas, $omitidas omitidas"
    if ($fallidas -gt 0) {
        Write-Host 'HAY COMPROBACIONES FALLIDAS: corrigelas antes de entregar.'
    } elseif ($omitidas -gt 0) {
        Write-Host 'Sin fallos, pero se omitieron pruebas: esta no es una verificacion completa.'
    } else {
        Write-Host 'Sin comprobaciones fallidas.'
    }
    if ($pendientes -gt 0) {
        Write-Host "Quedan $pendientes pendiente(s): dependen del docente, de una decision tuya o de tu valoracion. No se dan por aprobados."
    }
    Write-Host 'Nota: este script no verifica enlace, firmware, ejecucion en la placa ni salida serial.'
    if ($fallidas -gt 0) { exit 1 }
    exit 0
}

# --- EN01: raiz del repositorio y remoto origin -----------------------------------
$top = InvocarGit 'rev-parse --show-toplevel'
$topNorm = (($top.Out.Trim()) -replace '/', '\').TrimEnd('\')
$okRaiz = (($top.Codigo -eq 0) -and ($topNorm -ieq $Raiz.TrimEnd('\')))
$urlFetch = (InvocarGit 'remote get-url origin').Out.Trim()
$urlPush  = (InvocarGit 'remote get-url --push origin').Out.Trim()
$patronUrl = '/' + [regex]::Escape($NombreRepo) + '(\.git)?/?$'
$okUrl = (($urlFetch -cmatch $patronUrl) -and ($urlPush -cmatch $patronUrl))
$notaEn01 = "raiz segun git: $topNorm`nfetch: $urlFetch`npush:  $urlPush`nrepositorio esperado: $NombreRepo"
if ($okRaiz -and $okUrl) {
    Registrar 'EN01' 'raiz del repositorio y remoto origin correctos' 'APROBADO' $notaEn01
} else {
    Registrar 'EN01' 'raiz del repositorio y remoto origin correctos' 'FALLIDO' $notaEn01
}
if (-not $okRaiz) {
    Write-Host 'No se puede continuar: este script debe estar dentro de la raiz del repositorio.'
    MostrarResumen
}

# --- EN02: rama de trabajo -----------------------------------------------------------
$rama = (InvocarGit 'rev-parse --abbrev-ref HEAD').Out.Trim()
if ($rama -ceq $RamaEsperada) {
    Registrar 'EN02' "la rama actual es $RamaEsperada" 'APROBADO' "rama actual: $rama"
} else {
    Registrar 'EN02' "la rama actual es $RamaEsperada" 'FALLIDO' "rama actual: $rama"
}

# --- EN03: sincronizacion con origin/main (sin fetch) -----------------------------
$headLocal = (InvocarGit 'rev-parse HEAD').Out.Trim()
$refOrigen = InvocarGit 'rev-parse --verify --quiet refs/remotes/origin/main'
$notaSync = 'Compara con la ultima referencia de origin/main que conoce tu equipo; este script no hace fetch. Para comprobarlo contra GitHub ahora, ejecuta git fetch tu mismo y repite.'
if ($refOrigen.Codigo -ne 0) {
    Registrar 'EN03' 'HEAD coincide con origin/main' 'FALLIDO' "no existe la referencia local origin/main`n$notaSync"
} else {
    $cuenta = InvocarGit 'rev-list --left-right --count origin/main...HEAD'
    $partes = $cuenta.Out.Trim() -split '\s+'
    $detras = [int]$partes[0]
    $delante = [int]$partes[1]
    $cortoHead = $headLocal.Substring(0, [Math]::Min(7, $headLocal.Length))
    $nota = "HEAD: $cortoHead | commits por delante de origin/main: $delante | por detras: $detras`n$notaSync"
    if (($detras -eq 0) -and ($delante -eq 0)) {
        Registrar 'EN03' 'HEAD coincide con origin/main' 'APROBADO' $nota
    } else {
        Registrar 'EN03' 'HEAD coincide con origin/main' 'FALLIDO' $nota
    }
}

# --- EN04: arbol de trabajo limpio ----------------------------------------------------
$estado = InvocarGit 'status --porcelain'
$cambios = @((LineasDe $estado.Out) | Where-Object { $_.Trim() -ne '' })
if ($cambios.Count -eq 0) {
    Registrar 'EN04' 'el arbol de trabajo esta limpio (sin cambios sin commit)' 'APROBADO' ''
} else {
    Registrar 'EN04' 'el arbol de trabajo esta limpio (sin cambios sin commit)' 'FALLIDO' ("hay $($cambios.Count) cambio(s) sin commit:`n" + ($cambios -join "`n"))
}

# --- Archivos versionados -----------------------------------------------------------------
$ls = InvocarGit 'ls-files'
$versionados = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($a in (LineasDe $ls.Out)) {
    if ($a.Trim() -ne '') { [void]$versionados.Add($a.Trim()) }
}

# --- EN05: archivos esenciales presentes y versionados ----------------------------------
$requeridos = @(
    '.gitignore', 'build.ps1', 'DOCUMENTACION.md',
    'src/lexer.l', 'src/parser.y', 'src/main.c',
    'src/ast.h', 'src/ast.c', 'src/errors.h', 'src/errors.c',
    'src/symtab.h', 'src/symtab.c', 'src/semantic.h', 'src/semantic.c',
    'src/codegen.h', 'src/codegen.c', 'src/tipos.h',
    'tests/run_lexer.ps1', 'tests/run_sintaxis.ps1', 'tests/run_ast.ps1',
    'tests/run_symtab.ps1', 'tests/run_semantica.ps1', 'tests/run_ir.ps1',
    'tests/run_validacion.ps1', 'tests/run_objeto.ps1',
    'tests/run_todo.ps1', 'tests/verificar_clon.ps1', 'tests/verificar_entrega.ps1',
    'tests/tools/lexer_driver.c', 'tests/tools/ast_driver.c',
    'tests/tools/symtab_driver.c', 'tests/tools/semantic_driver.c',
    'ejemplos/area.olc', 'ejemplos/area.ll',
    'ejemplos/resultado.olc', 'ejemplos/resultado.ll'
)
$sinVersionar = @()
$sinDisco = @()
foreach ($f in $requeridos) {
    if (-not $versionados.Contains($f)) { $sinVersionar += $f }
    if (-not (Test-Path -LiteralPath (Join-Path $Raiz $f))) { $sinDisco += $f }
}
if (($sinVersionar.Count -eq 0) -and ($sinDisco.Count -eq 0)) {
    Registrar 'EN05' 'archivos esenciales presentes y versionados' 'APROBADO' "$($requeridos.Count) archivos comprobados"
} else {
    $nota = ''
    if ($sinVersionar.Count -gt 0) { $nota = $nota + "sin versionar:`n  " + ($sinVersionar -join "`n  ") + "`n" }
    if ($sinDisco.Count -gt 0) { $nota = $nota + "faltan en disco:`n  " + ($sinDisco -join "`n  ") }
    Registrar 'EN05' 'archivos esenciales presentes y versionados' 'FALLIDO' $nota.TrimEnd()
}

# --- EN06: ensayo (presencia, versionado, formato PDF y paginas; sin leer contenido) --
$rutaEnsayoDisco = Join-Path $Raiz $RutaEnsayo
$existeEnsayo = Test-Path -LiteralPath $rutaEnsayoDisco
$versionadoEnsayo = $versionados.Contains($RutaEnsayo)
$descEn06 = "ensayo en $RutaEnsayo (presencia, versionado, formato PDF y paginas)"

if ((-not $existeEnsayo) -and (-not $versionadoEnsayo)) {
    Registrar 'EN06' $descEn06 'PENDIENTE' 'Aun no existe. Lo redactas tu: aqui no se genera ni se evalua.'
} elseif ($existeEnsayo -and (-not $versionadoEnsayo)) {
    Registrar 'EN06' $descEn06 'FALLIDO' "existe pero no esta versionado (falta git add y commit de $RutaEnsayo)"
} elseif ((-not $existeEnsayo) -and $versionadoEnsayo) {
    Registrar 'EN06' $descEn06 'FALLIDO' 'esta versionado pero falta en disco'
} else {
    $bytes = [System.IO.File]::ReadAllBytes($rutaEnsayoDisco)
    $esPdf = (($bytes.Length -ge 5) -and ($bytes[0] -eq 0x25) -and ($bytes[1] -eq 0x50) -and
              ($bytes[2] -eq 0x44) -and ($bytes[3] -eq 0x46) -and ($bytes[4] -eq 0x2D))
    if (-not $esPdf) {
        Registrar 'EN06' $descEn06 'FALLIDO' 'el archivo no empieza con la cabecera %PDF-: no parece un PDF'
    } else {
        # Solo se cuentan marcadores estructurales del archivo; no se extrae ni se evalua texto.
        $estructura = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
        $conObjStm = ($estructura -match '/ObjStm')
        $paginas = [regex]::Matches($estructura, '/Type\s*/Page(?![A-Za-z])').Count
        $avisoManual = 'Verifica a mano en tu visor de PDF que tenga como maximo 2 paginas.'
        if ($conObjStm -or ($paginas -eq 0)) {
            Registrar 'EN06' $descEn06 'PENDIENTE' ("es un PDF versionado, pero el numero de paginas no se puede determinar de forma fiable desde el archivo.`n" + $avisoManual)
        } elseif ($paginas -le 2) {
            Registrar 'EN06' $descEn06 'APROBADO' ("PDF versionado, $paginas pagina(s) segun la estructura del archivo (estimacion; manda tu visor de PDF).`nEl contenido no se lee ni se evalua.")
        } else {
            Registrar 'EN06' $descEn06 'FALLIDO' ("la estructura del archivo indica $paginas paginas y el maximo es 2.`nSi tu visor de PDF muestra otra cantidad, manda el visor.")
        }
    }
}

# --- EN07: nada generado esta versionado ----------------------------------------------
$generados = @()
foreach ($a in $versionados) {
    if (($a -match '\.(o|obj|exe|bc)$') -or ($a -match '^build/') -or
        ($a -match 'lex\.yy\.c$') -or ($a -match 'parser\.tab\.[ch]$') -or
        ($a -match '\.output$')) {
        $generados += $a
    } elseif (($a -match '\.ll$') -and ($a -notmatch '^ejemplos/')) {
        $generados += $a
    }
}
if ($generados.Count -eq 0) {
    Registrar 'EN07' 'no hay archivos generados versionados' 'APROBADO' "$($versionados.Count) archivos versionados"
} else {
    Registrar 'EN07' 'no hay archivos generados versionados' 'FALLIDO' ("versionados que parecen generados:`n" + ($generados -join "`n"))
}

# --- EN08: DOCUMENTACION.md con los encabezados exigidos ------------------------------------
$rutaDoc = Join-Path $Raiz 'DOCUMENTACION.md'
if (-not (Test-Path -LiteralPath $rutaDoc)) {
    Registrar 'EN08' 'DOCUMENTACION.md contiene los encabezados, el carne y la arquitectura asignada' 'FALLIDO' 'no existe DOCUMENTACION.md'
} else {
    $doc = [System.IO.File]::ReadAllText($rutaDoc)
    $faltan = @()
    for ($n = 1; $n -le 14; $n++) {
        if ($doc -notmatch ('(?m)^## ' + $n + '\. ')) { $faltan += "encabezado '## $n.'" }
    }
    if ($doc -notmatch [regex]::Escape($Carne)) { $faltan += "el carne $Carne" }
    if ($doc -notmatch 'Raspberry Pi Pico') { $faltan += 'la mencion de Raspberry Pi Pico' }
    if ($faltan.Count -eq 0) {
        Registrar 'EN08' 'DOCUMENTACION.md contiene los encabezados, el carne y la arquitectura asignada' 'APROBADO' '14 encabezados numerados encontrados'
    } else {
        Registrar 'EN08' 'DOCUMENTACION.md contiene los encabezados, el carne y la arquitectura asignada' 'FALLIDO' ("falta:`n" + ($faltan -join "`n"))
    }
}

# --- EN09: run_todo.ps1 ----------------------------------------------------------------------------
$descEn09 = 'run_todo.ps1: compilacion desde cero y todas las suites'
if ($SinPruebas) {
    Registrar 'EN09' $descEn09 'OMITIDA' 'omitida por -SinPruebas'
} else {
    Write-Host ''
    Write-Host '... ejecutando run_todo.ps1 (compila desde cero y corre las 8 suites) ...'
    $rt = EjecutarScript (Join-Path $Raiz 'tests\run_todo.ps1')
    $m = [regex]::Match($rt.Out, 'TOTAL: (\d+) aprobadas, (\d+) fallidas \(esperadas (\d+)\)')
    $okTodo = (($rt.Codigo -eq 0) -and $m.Success -and ($m.Groups[2].Value -eq '0') -and
               ($m.Groups[1].Value -eq $m.Groups[3].Value))
    $lineas = LineasDe $rt.Out
    $inicio = [array]::IndexOf($lineas, '=== Resumen por suite ===')
    if ($Detalle -or (-not $okTodo) -or ($inicio -lt 0)) {
        Write-Host $rt.Out
    } else {
        $ultimaLinea = $lineas.Count - 1
        foreach ($l in $lineas[$inicio..$ultimaLinea]) { Write-Host $l }
    }
    if ($rt.Err.Length -gt 0) { Write-Host $rt.Err }
    if ($okTodo) {
        Registrar 'EN09' $descEn09 'APROBADO' "TOTAL: $($m.Groups[1].Value) aprobadas, $($m.Groups[2].Value) fallidas (esperadas $($m.Groups[3].Value))"
    } else {
        Registrar 'EN09' $descEn09 'FALLIDO' "codigo de salida de run_todo.ps1: $($rt.Codigo)"
    }
}

# --- EN10: verificar_clon.ps1 ---------------------------------------------------------------------
$descEn10 = 'verificar_clon.ps1: reproducibilidad desde un clon limpio del ultimo commit'
if ($SinPruebas) {
    Registrar 'EN10' $descEn10 'OMITIDA' 'omitida por -SinPruebas'
} else {
    Write-Host ''
    Write-Host '... ejecutando verificar_clon.ps1 (clona el ultimo commit en una carpeta temporal) ...'
    $rc = EjecutarScript (Join-Path $Raiz 'tests\verificar_clon.ps1')
    $mc = [regex]::Match($rc.Out, 'Verificacion del clon: (\d+) aprobadas, (\d+) fallidas')
    $okClon = (($rc.Codigo -eq 0) -and $mc.Success -and ($mc.Groups[2].Value -eq '0') -and
               ([int]$mc.Groups[1].Value -ge 5))
    if ($Detalle -or (-not $okClon)) {
        Write-Host $rc.Out
    } else {
        foreach ($l in (LineasDe $rc.Out)) {
            if (($l -match '^\[(PASS|FAIL)\] RC\d\d') -or ($l -match '^\[(AVISO|INFO)\]') -or
                ($l -match '^Verificacion del clon') -or ($l -match 'TOTAL en el clon')) {
                Write-Host $l
            }
        }
    }
    if ($rc.Err.Length -gt 0) { Write-Host $rc.Err }
    if ($okClon) {
        Registrar 'EN10' $descEn10 'APROBADO' "Verificacion del clon: $($mc.Groups[1].Value) aprobadas, $($mc.Groups[2].Value) fallidas"
    } else {
        Registrar 'EN10' $descEn10 'FALLIDO' "codigo de salida de verificar_clon.ps1: $($rc.Codigo)"
    }
}

# --- EN11: historial de commits (informativo; requiere tu valoracion) -------------------
$todos = InvocarGit 'log --date=short --format=%ad'
$fechas = @((LineasDe $todos.Out) | Where-Object { $_.Trim() -ne '' })
$descEn11 = 'historial de commits progresivo (requiere tu valoracion)'
if ($fechas.Count -eq 0) {
    Registrar 'EN11' $descEn11 'FALLIDO' 'no se pudo leer el historial de commits'
} else {
    $grupos = @($fechas | Group-Object | Sort-Object Name)
    $recientes = (InvocarGit 'log -n 8 --date=short "--format=%h %ad %s"').Out
    $posteriores = @($fechas | Where-Object { [string]::CompareOrdinal($_, $FechaLimite) -gt 0 }).Count
    $lineasNota = @()
    $lineasNota += "commits: $($fechas.Count) en $($grupos.Count) dia(s) distinto(s)"
    $lineasNota += "primer commit: $($fechas[$fechas.Count - 1]) | ultimo commit: $($fechas[0])"
    $lineasNota += 'commits por dia:'
    foreach ($g in $grupos) { $lineasNota += ('  {0}: {1}' -f $g.Name, $g.Count) }
    $lineasNota += 'ultimos commits:'
    foreach ($l in (LineasDe $recientes)) { if ($l.Trim() -ne '') { $lineasNota += "  $l" } }
    $lineasNota += "fecha limite indicada en el enunciado: $FechaLimite | commits con fecha posterior: $posteriores"
    if ($grupos.Count -eq 1) {
        $lineasNota += 'AVISO: todos los commits caen el mismo dia; el enunciado pide trabajo progresivo.'
    }
    $lineasNota += 'Valoracion manual: el enunciado pide commits reales y progresivos; este script no puede juzgarlo.'
    Registrar 'EN11' $descEn11 'PENDIENTE' ($lineasNota -join "`n")
}

# --- PD01-PD06: pendientes que dependen del docente --------------------------------------------
$pendientesDocente = @(
    @{ Id = 'PD01'; Desc = 'punto de entrada: el runtime invoca main (hoy provisional)' },
    @{ Id = 'PD02'; Desc = 'firmas de print_i32 y print_f64 coinciden con las del runtime' },
    @{ Id = 'PD03'; Desc = 'simbolo __aeabi_unwind_cpp_pr0 sin resolver en los objetos' },
    @{ Id = 'PD04'; Desc = 'ABI de print_f64 (el double se pasa en r0:r1)' },
    @{ Id = 'PD05'; Desc = 'enlace, carga y salida por monitor serial en la placa (no realizados)' },
    @{ Id = 'PD06'; Desc = 'visibilidad (publico o privado) y procedimiento de entrega del repositorio' }
)
Write-Host ''
foreach ($p in $pendientesDocente) {
    Registrar $p.Id $p.Desc 'PENDIENTE' 'Depende del docente. Sin confirmar.'
}

MostrarResumen