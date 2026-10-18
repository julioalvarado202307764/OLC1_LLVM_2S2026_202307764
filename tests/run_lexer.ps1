# run_lexer.ps1 - Pruebas del analizador lexico (CP1, Fases 2 y 3).
# Usa build\lexer_test.exe, que imprime el flujo de tokens sin invocar al parser.
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_lexer.ps1

$Raiz = Split-Path -Parent $PSScriptRoot
$Exe  = Join-Path $Raiz 'build\lexer_test.exe'
$Tmp  = Join-Path $Raiz 'build\tests'

if (-not (Test-Path -LiteralPath $Exe)) {
    Write-Host "No existe $Exe. Ejecuta primero build.ps1"
    exit 1
}
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

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

function Normalizar([string]$Texto) {
    return ($Texto -replace "`r", '').TrimEnd("`n")
}

# Cada caso: Id, descripcion, fuente, salida esperada (stdout, linea por linea)
# y un texto que debe aparecer en stderr (vacio = stderr debe quedar vacio).
$casos = @(
    @{ Id = 'LX01'; Desc = 'declaracion entera';
       Fuente = "let a = 10;";
       Salida = @("1:1 LET", "1:5 ID a", "1:7 '='", "1:9 ENTERO 10 (valor=10)", "1:11 ';'", "FIN errores=0");
       Err = '' },

    @{ Id = 'LX02'; Desc = 'declaracion decimal';
       Fuente = "let precio = 25.5;";
       Salida = @("1:1 LET", "1:5 ID precio", "1:12 '='", "1:14 DECIMAL 25.5 (valor=25.5)", "1:18 ';'", "FIN errores=0");
       Err = '' },

    @{ Id = 'LX03'; Desc = 'print con operadores y parentesis';
       Fuente = "print (a + b) * 2 - c / 4.0;";
       Salida = @("1:1 PRINT", "1:7 '('", "1:8 ID a", "1:10 '+'", "1:12 ID b", "1:13 ')'", "1:15 '*'", "1:17 ENTERO 2 (valor=2)", "1:19 '-'", "1:21 ID c", "1:23 '/'", "1:25 DECIMAL 4.0 (valor=4)", "1:28 ';'", "FIN errores=0");
       Err = '' },

    @{ Id = 'LX04'; Desc = 'dos lineas (salto LF)';
       Fuente = "let a = 1;`nprint a;";
       Salida = @("1:1 LET", "1:5 ID a", "1:7 '='", "1:9 ENTERO 1 (valor=1)", "1:10 ';'", "2:1 PRINT", "2:7 ID a", "2:8 ';'", "FIN errores=0");
       Err = '' },

    @{ Id = 'LX05'; Desc = 'dos lineas (salto CRLF)';
       Fuente = "let a = 1;`r`nprint a;";
       Salida = @("1:1 LET", "1:5 ID a", "1:7 '='", "1:9 ENTERO 1 (valor=1)", "1:10 ';'", "2:1 PRINT", "2:7 ID a", "2:8 ';'", "FIN errores=0");
       Err = '' },

    @{ Id = 'LX06'; Desc = 'reservadas frente a identificadores que las contienen';
       Fuente = "let letra = printx;";
       Salida = @("1:1 LET", "1:5 ID letra", "1:11 '='", "1:13 ID printx", "1:19 ';'", "FIN errores=0");
       Err = '' },

    @{ Id = 'LX07'; Desc = 'identificadores con guion bajo y digitos';
       Fuente = "let _x1 = y_2;";
       Salida = @("1:1 LET", "1:5 ID _x1", "1:9 '='", "1:11 ID y_2", "1:14 ';'", "FIN errores=0");
       Err = '' },

    @{ Id = 'LX08'; Desc = '5. es entero y un punto invalido';
       Fuente = "let a = 5.;";
       Salida = @("1:1 LET", "1:5 ID a", "1:7 '='", "1:9 ENTERO 5 (valor=5)", "1:11 ';'", "FIN errores=1");
       Err = "ERROR LEXICO (linea 1, columna 10): caracter no reconocido '.'" },

    @{ Id = 'LX09'; Desc = 'caracter invalido en medio de la linea';
       Fuente = "let a = 10 @ 2;";
       Salida = @("1:1 LET", "1:5 ID a", "1:7 '='", "1:9 ENTERO 10 (valor=10)", "1:14 ENTERO 2 (valor=2)", "1:15 ';'", "FIN errores=1");
       Err = "ERROR LEXICO (linea 1, columna 12): caracter no reconocido '@'" },

    @{ Id = 'LX10'; Desc = 'entero fuera de rango de i32';
       Fuente = "print 2147483648;";
       Salida = @("1:1 PRINT", "1:7 ENTERO 2147483648 (valor=0)", "1:17 ';'", "FIN errores=1");
       Err = "ERROR LEXICO (linea 1, columna 7): entero fuera de rango de i32: 2147483648" },

    @{ Id = 'LX11'; Desc = 'limite valido de i32';
       Fuente = "print 2147483647;";
       Salida = @("1:1 PRINT", "1:7 ENTERO 2147483647 (valor=2147483647)", "1:17 ';'", "FIN errores=0");
       Err = '' },

    @{ Id = 'LX12'; Desc = 'archivo vacio';
       Fuente = "";
       Salida = @("FIN errores=0");
       Err = '' }
)

$aprobadas = 0
$fallidas = 0

foreach ($c in $casos) {
    $ruta = Join-Path $Tmp ($c.Id + '.olc')
    [System.IO.File]::WriteAllText($ruta, $c.Fuente)

    $r = Ejecutar $ruta
    $esperado = $c.Salida -join "`n"
    $obtenido = Normalizar $r.Out

    $okOut = ($obtenido -ceq $esperado)
    if ($c.Err -eq '') {
        $okErr = ($r.Err.Length -eq 0)
    } else {
        $okErr = $r.Err.Contains($c.Err)
    }
    $okCod = ($r.Codigo -eq 0)

    if ($okOut -and $okErr -and $okCod) {
        Write-Host "[PASS] $($c.Id) - $($c.Desc)"
        $aprobadas++
    } else {
        Write-Host "[FAIL] $($c.Id) - $($c.Desc)"
        Write-Host "       codigo de salida: $($r.Codigo)"
        Write-Host "       --- stdout esperado ---"
        Write-Host $esperado
        Write-Host "       --- stdout obtenido ---"
        Write-Host $obtenido
        Write-Host "       --- stderr (debe contener: '$($c.Err)') ---"
        Write-Host $r.Err
        $fallidas++
    }
}

Write-Host ''
Write-Host "Pruebas del lexer: $aprobadas aprobadas, $fallidas fallidas"
if ($fallidas -gt 0) { exit 1 }
exit 0