# run_sintaxis.ps1 - Pruebas del analisis sintactico (CP2, Fases 2 y 3).
# Usa build\compilador.exe. Todavia no hay AST ni semantica: solo se comprueba
# que la gramatica acepte o rechace programas y reporte la posicion del error.
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_sintaxis.ps1

$Raiz   = Split-Path -Parent $PSScriptRoot
$Exe    = Join-Path $Raiz 'build\compilador.exe'
$Tmp    = Join-Path $Raiz 'build\tests\sintaxis'
$Parser = Join-Path $Raiz 'src\parser.y'

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

$aprobadas = 0
$fallidas = 0

function Registrar([string]$Id, [string]$Desc, [bool]$Ok, [string]$Detalle) {
    if ($Ok) {
        Write-Host "[PASS] $Id - $Desc"
        $script:aprobadas++
    } else {
        Write-Host "[FAIL] $Id - $Desc"
        if ($Detalle -ne '') { Write-Host $Detalle }
        $script:fallidas++
    }
}

$exito = "Analisis sintactico exitoso.`nAnalisis semantico exitoso."
$fallo = "Analisis fallido: 1 error(es)."

# Cada caso: Id, descripcion, fuente, codigo de salida esperado, stdout esperado
# exacto y lista de textos que deben aparecer en stderr (lista vacia = stderr
# debe quedar vacio).
$casos = @(
    @{ Id = 'SX01'; Desc = 'programa minimo';
       Fuente = "print 1;";
       Codigo = 0; Out = $exito; Err = @() },

    @{ Id = 'SX02'; Desc = 'ejemplo entero del enunciado (4.2)';
       Fuente = "let a = 10;`nlet b = 20;`nlet resultado = a + b * 2;`nprint resultado;";
       Codigo = 0; Out = $exito; Err = @() },

    @{ Id = 'SX03'; Desc = 'ejemplo decimal del enunciado (4.8)';
       Fuente = "let ancho = 10.5;`nlet alto = 20.0;`nlet area = ancho * alto;`nprint area;";
       Codigo = 0; Out = $exito; Err = @() },

    @{ Id = 'SX04'; Desc = 'parentesis anidados y los cuatro operadores';
       Fuente = "print ((1 + 2) * (3 - 4)) / 5 - 6 + 7;";
       Codigo = 0; Out = $exito; Err = @() },

    @{ Id = 'SX05'; Desc = 'falta el punto y coma final (error en fin de archivo)';
       Fuente = "print 5";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 8): syntax error", $fallo) },

    @{ Id = 'SX06'; Desc = 'let sin identificador';
       Fuente = "let = 5;";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 5): syntax error", "unexpected '='", $fallo) },

    @{ Id = 'SX07'; Desc = 'let sin signo igual';
       Fuente = "let a 5;";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 7): syntax error", "unexpected ENTERO", $fallo) },

    @{ Id = 'SX08'; Desc = 'parentesis sin cerrar';
       Fuente = "print (1 + 2;";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 13): syntax error", "unexpected ';'", $fallo) },

    @{ Id = 'SX09'; Desc = 'print sin expresion';
       Fuente = "print;";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 6): syntax error", "unexpected ';'", $fallo) },

    @{ Id = 'SX10'; Desc = 'archivo vacio (la gramatica exige al menos una instruccion)';
       Fuente = "";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 1): syntax error", $fallo) },

    @{ Id = 'SX11'; Desc = 'dos operadores seguidos';
       Fuente = "print 1 + * 2;";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 11): syntax error", "unexpected '*'", $fallo) },

    @{ Id = 'SX12'; Desc = 'menos unario no existe en la gramatica';
       Fuente = "print -5;";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 7): syntax error", "unexpected '-'", $fallo) },

    @{ Id = 'SX13'; Desc = 'asignacion sin let (reasignacion fuera de alcance)';
       Fuente = "a = 5;";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 1, columna 1): syntax error", "unexpected ID", $fallo) },

    @{ Id = 'SX14'; Desc = 'error en la segunda linea';
       Fuente = "let a = 1;`nlet b = ;";
       Codigo = 1; Out = '';
       Err = @("ERROR SINTACTICO (linea 2, columna 9): syntax error", "unexpected ';'", $fallo) },

    @{ Id = 'SX15'; Desc = 'error lexico con sintaxis correcta: el analisis debe fallar';
       Fuente = "let a = 1 @;";
       Codigo = 1; Out = '';
       Err = @("ERROR LEXICO (linea 1, columna 11): caracter no reconocido '@'", $fallo) }
)

foreach ($c in $casos) {
    $ruta = Join-Path $Tmp ($c.Id + '.olc')
    [System.IO.File]::WriteAllText($ruta, $c.Fuente)

    $r = Ejecutar $Exe ('"' + $ruta + '"')
    $out = Normalizar $r.Out

    $okCod = ($r.Codigo -eq $c.Codigo)
    $okOut = ($out -ceq $c.Out)
    $okErr = $true
    if ($c.Err.Count -eq 0) {
        $okErr = ($r.Err.Length -eq 0)
    } else {
        foreach ($s in $c.Err) {
            if (-not $r.Err.Contains($s)) { $okErr = $false }
        }
    }

    $detalle = "       codigo: $($r.Codigo) (esperado $($c.Codigo))`n" +
               "       stdout esperado: '$($c.Out)'`n" +
               "       stdout obtenido: '$out'`n" +
               "       stderr obtenido: $($r.Err)"
    Registrar $c.Id $c.Desc ($okCod -and $okOut -and $okErr) $detalle
}

# SX16: Bison no debe reportar conflictos ni avisos, ni parser.y debe usar
# directivas de precedencia (el enunciado las prohibe).
$bison = Find-Tool @('bison', 'win_bison')
$dirBison = Join-Path $Tmp 'bison'
New-Item -ItemType Directory -Force -Path $dirBison | Out-Null
$salidaC = Join-Path $dirBison 'parser_conflictos.tab.c'
$argsBison = '-Wall -Werror=conflicts-sr -Werror=conflicts-rr -o "' + $salidaC + '" "' + $Parser + '"'
$rb = Ejecutar $bison $argsBison
$patron = @('^\s*%(left|right|nonassoc|precedence)\b', '%prec\b')
$prohibidas = Select-String -Path $Parser -Pattern $patron
$okBison = (($rb.Codigo -eq 0) -and ($rb.Err.Length -eq 0) -and (-not $prohibidas))
Registrar 'SX16' 'Bison sin conflictos ni avisos y sin directivas de precedencia' $okBison `
    ("       codigo de Bison: $($rb.Codigo)`n       stderr: $($rb.Err)`n       directivas prohibidas: $prohibidas")

# SX17: control del detector. Un archivo con %left debe ser detectado.
$falso = Join-Path $Tmp 'falso_precedencia.y'
[System.IO.File]::WriteAllText($falso, "%left '+'`n%%`nx : 'a' ;`n")
$detectado = Select-String -Path $falso -Pattern $patron
Registrar 'SX17' 'el detector de directivas de precedencia funciona (control)' ([bool]$detectado) ''

Write-Host ''
Write-Host "Pruebas de sintaxis: $aprobadas aprobadas, $fallidas fallidas"
if ($fallidas -gt 0) { exit 1 }
exit 0