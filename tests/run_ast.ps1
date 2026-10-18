# run_ast.ps1 - Pruebas del AST (CP3, Fases 2 y 3).
# Usa build\ast_test.exe, que imprime el arbol y los nodos vivos tras liberarlo.
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_ast.ps1

$Raiz = Split-Path -Parent $PSScriptRoot
$Exe  = Join-Path $Raiz 'build\ast_test.exe'
$Tmp  = Join-Path $Raiz 'build\tests\ast'

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

$aprobadas = 0
$fallidas = 0

# Cada caso: Id, descripcion, fuente, si se usa --pos, codigo de salida esperado,
# stdout esperado (linea por linea) y textos que deben aparecer en stderr
# (lista vacia = stderr debe quedar vacio).
$casos = @(
    @{ Id = 'AS01'; Desc = 'precedencia: 1 + 2 * 3';
       Fuente = "print 1 + 2 * 3;"; Pos = $false; Codigo = 0;
       Salida = @("Programa", "  Print", "    Binario +", "      Entero 1", "      Binario *", "        Entero 2", "        Entero 3", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS02'; Desc = 'asociatividad izquierda de la resta: 10 - 3 - 2';
       Fuente = "print 10 - 3 - 2;"; Pos = $false; Codigo = 0;
       Salida = @("Programa", "  Print", "    Binario -", "      Binario -", "        Entero 10", "        Entero 3", "      Entero 2", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS03'; Desc = 'asociatividad izquierda de la division: 100 / 10 / 2';
       Fuente = "print 100 / 10 / 2;"; Pos = $false; Codigo = 0;
       Salida = @("Programa", "  Print", "    Binario /", "      Binario /", "        Entero 100", "        Entero 10", "      Entero 2", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS04'; Desc = 'los parentesis cambian la estructura: (10 + 20) * 3';
       Fuente = "print (10 + 20) * 3;"; Pos = $false; Codigo = 0;
       Salida = @("Programa", "  Print", "    Binario *", "      Binario +", "        Entero 10", "        Entero 20", "      Entero 3", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS05'; Desc = 'nodos let, print e identificador';
       Fuente = "let x = 5;`nprint x;"; Pos = $false; Codigo = 0;
       Salida = @("Programa", "  Let x", "    Entero 5", "  Print", "    Id x", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS06'; Desc = 'varias instrucciones en orden (ejemplo 4.2 del enunciado)';
       Fuente = "let a = 10;`nlet b = 20;`nlet resultado = a + b * 2;`nprint resultado;"; Pos = $false; Codigo = 0;
       Salida = @("Programa", "  Let a", "    Entero 10", "  Let b", "    Entero 20", "  Let resultado", "    Binario +", "      Id a", "      Binario *", "        Id b", "        Entero 2", "  Print", "    Id resultado", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS07'; Desc = 'decimales e identificadores (ejemplo decimal del enunciado)';
       Fuente = "let precio = 25.5;`nlet cantidad = 4.0;`nlet total = precio * cantidad;`nprint total;"; Pos = $false; Codigo = 0;
       Salida = @("Programa", "  Let precio", "    Decimal 25.5", "  Let cantidad", "    Decimal 4.0", "  Let total", "    Binario *", "      Id precio", "      Id cantidad", "  Print", "    Id total", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS08'; Desc = 'mezcla de precedencias: 1 - 2 * 3 + 4 / 5';
       Fuente = "print 1 - 2 * 3 + 4 / 5;"; Pos = $false; Codigo = 0;
       Salida = @("Programa", "  Print", "    Binario +", "      Binario -", "        Entero 1", "        Binario *", "          Entero 2", "          Entero 3", "      Binario /", "        Entero 4", "        Entero 5", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS09'; Desc = 'posiciones de los nodos (--pos)';
       Fuente = "let resultado = a + b * 2;`nprint resultado;"; Pos = $true; Codigo = 0;
       Salida = @("Programa", "  Let resultado @1:5", "    Binario + @1:19", "      Id a @1:17", "      Binario * @1:23", "        Id b @1:21", "        Entero 2 @1:25", "  Print @2:1", "    Id resultado @2:7", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS10'; Desc = 'los parentesis no generan nodos';
       Fuente = "print ((7));"; Pos = $true; Codigo = 0;
       Salida = @("Programa", "  Print @1:1", "    Entero 7 @1:9", "NODOS_VIVOS=0");
       Err = @() },

    @{ Id = 'AS11'; Desc = 'liberacion total con error dentro de una expresion';
       Fuente = "let a = 1 + ;"; Pos = $false; Codigo = 1;
       Salida = @("NODOS_VIVOS=0");
       Err = @("ERROR SINTACTICO (linea 1, columna 13): syntax error", "unexpected ';'") },

    @{ Id = 'AS12'; Desc = 'liberacion total con error tras instrucciones completas';
       Fuente = "print 1;`nprint 2 +;"; Pos = $false; Codigo = 1;
       Salida = @("NODOS_VIVOS=0");
       Err = @("ERROR SINTACTICO (linea 2, columna 10): syntax error", "unexpected ';'") }
)

foreach ($c in $casos) {
    $ruta = Join-Path $Tmp ($c.Id + '.olc')
    [System.IO.File]::WriteAllText($ruta, $c.Fuente)

    $argumentos = '"' + $ruta + '"'
    if ($c.Pos) { $argumentos = $argumentos + ' --pos' }

    $r = Ejecutar $argumentos
    $esperado = $c.Salida -join "`n"
    $obtenido = Normalizar $r.Out

    $okCod = ($r.Codigo -eq $c.Codigo)
    $okOut = ($obtenido -ceq $esperado)
    $okErr = $true
    if ($c.Err.Count -eq 0) {
        $okErr = ($r.Err.Length -eq 0)
    } else {
        foreach ($s in $c.Err) {
            if (-not $r.Err.Contains($s)) { $okErr = $false }
        }
    }

    if ($okCod -and $okOut -and $okErr) {
        Write-Host "[PASS] $($c.Id) - $($c.Desc)"
        $aprobadas++
    } else {
        Write-Host "[FAIL] $($c.Id) - $($c.Desc)"
        Write-Host "       codigo: $($r.Codigo) (esperado $($c.Codigo))"
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
Write-Host "Pruebas del AST: $aprobadas aprobadas, $fallidas fallidas"
if ($fallidas -gt 0) { exit 1 }
exit 0