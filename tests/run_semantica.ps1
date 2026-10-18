# run_semantica.ps1 - Pruebas del analisis semantico (CP4b, Fase 4).
# Usa build\semantic_test.exe (AST con tipos y tabla) y build\compilador.exe.
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_semantica.ps1

$Raiz    = Split-Path -Parent $PSScriptRoot
$ExeSem  = Join-Path $Raiz 'build\semantic_test.exe'
$ExeComp = Join-Path $Raiz 'build\compilador.exe'
$Tmp     = Join-Path $Raiz 'build\tests\semantica'

foreach ($e in @($ExeSem, $ExeComp)) {
    if (-not (Test-Path -LiteralPath $e)) {
        Write-Host "No existe $e. Ejecuta primero build.ps1"
        exit 1
    }
}
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

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

$cola = @("NODOS_VIVOS=0", "SIMBOLOS_VIVOS=0")

# Cada caso: Id, descripcion, fuente, Exe ('sem' o 'comp'), si se usa --pos,
# codigo de salida esperado, stdout esperado (linea por linea), cantidad exacta
# de lineas "ERROR ..." en stderr y textos que deben aparecer en stderr.
$casos = @(
    @{ Id = 'SM01'; Desc = 'programa valido con enteros (ejemplo 4.2 del enunciado)';
       Exe = 'sem'; Pos = $false; Codigo = 0; NumErrores = 0; Err = @();
       Fuente = "let a = 10;`nlet b = 20;`nlet resultado = a + b * 2;`nprint resultado;";
       Salida = (@("Programa", "  Let a : i32", "    Entero 10 : i32", "  Let b : i32", "    Entero 20 : i32", "  Let resultado : i32", "    Binario + : i32", "      Id a : i32", "      Binario * : i32", "        Id b : i32", "        Entero 2 : i32", "  Print : i32", "    Id resultado : i32", "TABLA 3", "  a : i32 @1:5", "  b : i32 @2:5", "  resultado : i32 @3:5") + $cola) },

    @{ Id = 'SM02'; Desc = 'programa valido con decimales (ejemplo decimal del enunciado)';
       Exe = 'sem'; Pos = $false; Codigo = 0; NumErrores = 0; Err = @();
       Fuente = "let precio = 25.5;`nlet cantidad = 4.0;`nlet total = precio * cantidad;`nprint total;";
       Salida = (@("Programa", "  Let precio : double", "    Decimal 25.5 : double", "  Let cantidad : double", "    Decimal 4.0 : double", "  Let total : double", "    Binario * : double", "      Id precio : double", "      Id cantidad : double", "  Print : double", "    Id total : double", "TABLA 3", "  precio : double @1:5", "  cantidad : double @2:5", "  total : double @3:5") + $cola) },

    @{ Id = 'SM03'; Desc = 'variable no declarada';
       Exe = 'sem'; Pos = $false; Codigo = 1; NumErrores = 1;
       Err = @("ERROR SEMANTICO (linea 1, columna 7): variable no declarada: 'x'");
       Fuente = "print x;";
       Salida = (@("Programa", "  Print : error", "    Id x : error", "TABLA 0") + $cola) },

    @{ Id = 'SM04'; Desc = 'declaracion duplicada (escenario de la Fig. 7)';
       Exe = 'sem'; Pos = $false; Codigo = 1; NumErrores = 1;
       Err = @("ERROR SEMANTICO (linea 4, columna 5): declaracion duplicada de 'n' (ya declarada en linea 1, columna 5)");
       Fuente = "let n = 5;`nlet m = 2.5;`nlet t = m * 2.0;`nlet n = 9;";
       Salida = (@("Programa", "  Let n : i32", "    Entero 5 : i32", "  Let m : double", "    Decimal 2.5 : double", "  Let t : double", "    Binario * : double", "      Id m : double", "      Decimal 2.0 : double", "  Let n : i32", "    Entero 9 : i32", "TABLA 3", "  n : i32 @1:5", "  m : double @2:5", "  t : double @3:5") + $cola) },

    @{ Id = 'SM05'; Desc = 'tipos incompatibles i32 + double (Fig. 10), sin cascada en print';
       Exe = 'sem'; Pos = $false; Codigo = 1; NumErrores = 1;
       Err = @("ERROR SEMANTICO (linea 3, columna 9): tipos incompatibles en la operacion: i32 + double");
       Fuente = "let n = 10;`nlet f = 2.5;`nlet s = n + f;`nprint s;";
       Salida = (@("Programa", "  Let n : i32", "    Entero 10 : i32", "  Let f : double", "    Decimal 2.5 : double", "  Let s : error", "    Binario + : error", "      Id n : i32", "      Id f : double", "  Print : error", "    Id s : error", "TABLA 3", "  n : i32 @1:5", "  f : double @2:5", "  s : error @3:5") + $cola) },

    @{ Id = 'SM06'; Desc = 'los cuatro operadores con tipos mezclados';
       Exe = 'sem'; Pos = $false; Codigo = 1; NumErrores = 4;
       Err = @("ERROR SEMANTICO (linea 3, columna 7): tipos incompatibles en la operacion: i32 + double",
               "ERROR SEMANTICO (linea 4, columna 7): tipos incompatibles en la operacion: i32 - double",
               "ERROR SEMANTICO (linea 5, columna 7): tipos incompatibles en la operacion: i32 * double",
               "ERROR SEMANTICO (linea 6, columna 7): tipos incompatibles en la operacion: i32 / double");
       Fuente = "let a = 1;`nlet b = 2.0;`nprint a + b;`nprint a - b;`nprint a * b;`nprint a / b;";
       Salida = (@("Programa", "  Let a : i32", "    Entero 1 : i32", "  Let b : double", "    Decimal 2.0 : double", "  Print : error", "    Binario + : error", "      Id a : i32", "      Id b : double", "  Print : error", "    Binario - : error", "      Id a : i32", "      Id b : double", "  Print : error", "    Binario * : error", "      Id a : i32", "      Id b : double", "  Print : error", "    Binario / : error", "      Id a : i32", "      Id b : double", "TABLA 2", "  a : i32 @1:5", "  b : double @2:5") + $cola) },

    @{ Id = 'SM07'; Desc = 'autorreferencia: let a = a + 1;';
       Exe = 'sem'; Pos = $false; Codigo = 1; NumErrores = 1;
       Err = @("ERROR SEMANTICO (linea 1, columna 9): variable no declarada: 'a'");
       Fuente = "let a = a + 1;";
       Salida = (@("Programa", "  Let a : error", "    Binario + : error", "      Id a : error", "      Entero 1 : i32", "TABLA 1", "  a : error @1:5") + $cola) },

    @{ Id = 'SM08'; Desc = 'un let fallido no provoca errores en cascada';
       Exe = 'sem'; Pos = $false; Codigo = 1; NumErrores = 1;
       Err = @("ERROR SEMANTICO (linea 1, columna 9): variable no declarada: 'y'");
       Fuente = "let x = y + 1;`nlet z = x * 2;`nprint z;";
       Salida = (@("Programa", "  Let x : error", "    Binario + : error", "      Id y : error", "      Entero 1 : i32", "  Let z : error", "    Binario * : error", "      Id x : error", "      Entero 2 : i32", "  Print : error", "    Id z : error", "TABLA 2", "  x : error @1:5", "  z : error @2:5") + $cola) },

    @{ Id = 'SM09'; Desc = 'varios errores reportados en una sola pasada';
       Exe = 'sem'; Pos = $false; Codigo = 1; NumErrores = 4;
       Err = @("ERROR SEMANTICO (linea 1, columna 7): variable no declarada: 'a'",
               "ERROR SEMANTICO (linea 2, columna 7): variable no declarada: 'b'",
               "ERROR SEMANTICO (linea 3, columna 9): tipos incompatibles en la operacion: i32 + double",
               "ERROR SEMANTICO (linea 4, columna 5): declaracion duplicada de 'c' (ya declarada en linea 3, columna 5)");
       Fuente = "print a;`nprint b;`nlet c = 1 + 2.0;`nlet c = 3;";
       Salida = (@("Programa", "  Print : error", "    Id a : error", "  Print : error", "    Id b : error", "  Let c : error", "    Binario + : error", "      Entero 1 : i32", "      Decimal 2.0 : double", "  Let c : i32", "    Entero 3 : i32", "TABLA 1", "  c : error @3:5") + $cola) },

    @{ Id = 'SM10'; Desc = 'tipos propagados a traves de variables';
       Exe = 'sem'; Pos = $false; Codigo = 0; NumErrores = 0; Err = @();
       Fuente = "let a = 2;`nlet b = a * 3;`nlet c = 1.5;`nlet d = c / 0.5;`nprint b;`nprint d;";
       Salida = (@("Programa", "  Let a : i32", "    Entero 2 : i32", "  Let b : i32", "    Binario * : i32", "      Id a : i32", "      Entero 3 : i32", "  Let c : double", "    Decimal 1.5 : double", "  Let d : double", "    Binario / : double", "      Id c : double", "      Decimal 0.5 : double", "  Print : i32", "    Id b : i32", "  Print : double", "    Id d : double", "TABLA 4", "  a : i32 @1:5", "  b : i32 @2:5", "  c : double @3:5", "  d : double @4:5") + $cola) },

    @{ Id = 'SM11'; Desc = 'volcado con tipos y posiciones (--pos)';
       Exe = 'sem'; Pos = $true; Codigo = 0; NumErrores = 0; Err = @();
       Fuente = "let a = 10;`nprint a + 1;";
       Salida = (@("Programa", "  Let a : i32 @1:5", "    Entero 10 : i32 @1:9", "  Print : i32 @2:1", "    Binario + : i32 @2:9", "      Id a : i32 @2:7", "      Entero 1 : i32 @2:11", "TABLA 1", "  a : i32 @1:5") + $cola) },

    @{ Id = 'SM12'; Desc = 'uso de una variable antes de declararla';
       Exe = 'sem'; Pos = $false; Codigo = 1; NumErrores = 1;
       Err = @("ERROR SEMANTICO (linea 1, columna 7): variable no declarada: 'a'");
       Fuente = "print a;`nlet a = 1;";
       Salida = (@("Programa", "  Print : error", "    Id a : error", "  Let a : i32", "    Entero 1 : i32", "TABLA 1", "  a : i32 @2:5") + $cola) },

    @{ Id = 'SM13'; Desc = 'compilador.exe con error semantico: codigo 1 y sin exito semantico';
       Exe = 'comp'; Pos = $false; Codigo = 1; NumErrores = 1;
       Err = @("ERROR SEMANTICO (linea 3, columna 9): tipos incompatibles en la operacion: i32 + double",
               "Analisis semantico fallido: 1 error(es). No se genera LLVM IR.");
       Fuente = "let n = 10;`nlet f = 2.5;`nlet s = n + f;`nprint s;";
       Salida = @("Analisis sintactico exitoso.") },

    @{ Id = 'SM14'; Desc = 'compilador.exe con programa valido: ambos mensajes de exito';
       Exe = 'comp'; Pos = $false; Codigo = 0; NumErrores = 0; Err = @();
       Fuente = "let a = 10;`nlet b = 20;`nlet resultado = a + b * 2;`nprint resultado;";
       Salida = @("Analisis sintactico exitoso.", "Analisis semantico exitoso.") }
)

$aprobadas = 0
$fallidas = 0

foreach ($c in $casos) {
    $ruta = Join-Path $Tmp ($c.Id + '.olc')
    [System.IO.File]::WriteAllText($ruta, $c.Fuente)

    $argumentos = '"' + $ruta + '"'
    if ($c.Exe -eq 'comp') {
        $exe = $ExeComp
    } else {
        $exe = $ExeSem
        if ($c.Pos) { $argumentos = $argumentos + ' --pos' }
    }

    $r = Ejecutar $exe $argumentos
    $esperado = $c.Salida -join "`n"
    $obtenido = Normalizar $r.Out

    $okCod = ($r.Codigo -eq $c.Codigo)
    $okOut = ($obtenido -ceq $esperado)

    $okErr = $true
    foreach ($s in $c.Err) {
        if (-not $r.Err.Contains($s)) { $okErr = $false }
    }
    $reales = ([regex]::Matches($r.Err, 'ERROR ')).Count
    $okNum = ($reales -eq $c.NumErrores)
    if (($c.NumErrores -eq 0) -and ($c.Err.Count -eq 0)) {
        if ($r.Err.Length -ne 0) { $okErr = $false }
    }

    if ($okCod -and $okOut -and $okErr -and $okNum) {
        Write-Host "[PASS] $($c.Id) - $($c.Desc)"
        $aprobadas++
    } else {
        Write-Host "[FAIL] $($c.Id) - $($c.Desc)"
        Write-Host "       codigo: $($r.Codigo) (esperado $($c.Codigo))"
        Write-Host "       lineas ERROR en stderr: $reales (esperadas $($c.NumErrores))"
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
Write-Host "Pruebas de semantica: $aprobadas aprobadas, $fallidas fallidas"
if ($fallidas -gt 0) { exit 1 }
exit 0