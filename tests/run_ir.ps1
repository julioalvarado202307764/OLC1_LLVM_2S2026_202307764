# run_ir.ps1 - Pruebas de generacion de LLVM IR y de la interfaz de linea de
# comandos (CP5a, Fase 5). Usa build\compilador.exe con la opcion -o.
# Uso (desde la raiz del proyecto, despues de build.ps1):
#   powershell -ExecutionPolicy Bypass -File .\tests\run_ir.ps1

$Raiz = Split-Path -Parent $PSScriptRoot
$Exe  = Join-Path $Raiz 'build\compilador.exe'
$Tmp  = Join-Path $Raiz 'build\tests\ir'

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

# IR completo esperado a partir de las lineas del cuerpo de @main.
function ArmarIr([string[]]$Cuerpo) {
    $lineas = @("declare void @print_i32(i32)", "declare void @print_f64(double)", "", "define i32 @main() {", "entry:") + $Cuerpo + @("  ret i32 0", "}")
    return ($lineas -join "`n")
}

$aprobadas = 0
$fallidas = 0

# --- Casos con generacion exitosa -------------------------------------------
# Cada caso: Id, descripcion, fuente y, o bien el cuerpo exacto de @main (Cuerpo),
# o bien un texto que debe aparecer en el .ll (Contiene).
$exitosos = @(
    @{ Id = 'IR01'; Desc = 'ejemplo entero del enunciado (4.2)';
       Fuente = "let a = 10;`nlet b = 20;`nlet resultado = a + b * 2;`nprint resultado;";
       Cuerpo = @("  %t1 = mul i32 20, 2", "  %t2 = add i32 10, %t1", "  call void @print_i32(i32 %t2)") },

    @{ Id = 'IR02'; Desc = 'ejemplo decimal del enunciado (4.8)';
       Fuente = "let ancho = 10.5;`nlet alto = 20.0;`nlet area = ancho * alto;`nprint area;";
       Cuerpo = @("  %t1 = fmul double 10.5, 20.0", "  call void @print_f64(double %t1)") },

    @{ Id = 'IR03'; Desc = 'ejemplo de la Fig. 2: 10 + 20 * 3';
       Fuente = "print 10 + 20 * 3;";
       Cuerpo = @("  %t1 = mul i32 20, 3", "  %t2 = add i32 10, %t1", "  call void @print_i32(i32 %t2)") },

    @{ Id = 'IR04'; Desc = 'los cuatro operadores enteros, temporales sin reutilizar';
       Fuente = "print 8 + 2;`nprint 8 - 2;`nprint 8 * 2;`nprint 8 / 2;";
       Cuerpo = @("  %t1 = add i32 8, 2", "  call void @print_i32(i32 %t1)", "  %t2 = sub i32 8, 2", "  call void @print_i32(i32 %t2)", "  %t3 = mul i32 8, 2", "  call void @print_i32(i32 %t3)", "  %t4 = sdiv i32 8, 2", "  call void @print_i32(i32 %t4)") },

    @{ Id = 'IR05'; Desc = 'los cuatro operadores decimales';
       Fuente = "print 8.5 + 2.5;`nprint 8.5 - 2.5;`nprint 8.5 * 2.5;`nprint 8.5 / 2.5;";
       Cuerpo = @("  %t1 = fadd double 8.5, 2.5", "  call void @print_f64(double %t1)", "  %t2 = fsub double 8.5, 2.5", "  call void @print_f64(double %t2)", "  %t3 = fmul double 8.5, 2.5", "  call void @print_f64(double %t3)", "  %t4 = fdiv double 8.5, 2.5", "  call void @print_f64(double %t4)") },

    @{ Id = 'IR06'; Desc = 'let no emite instrucciones: las variables se propagan';
       Fuente = "let a = 5;`nlet b = a;`nlet c = 2.5;`nprint b;`nprint c;";
       Cuerpo = @("  call void @print_i32(i32 5)", "  call void @print_f64(double 2.5)") },

    @{ Id = 'IR07'; Desc = 'parentesis y variables: izquierda antes que derecha';
       Fuente = "let x = 4;`nlet y = (x + 2) * (x - 1);`nprint y;";
       Cuerpo = @("  %t1 = add i32 4, 2", "  %t2 = sub i32 4, 1", "  %t3 = mul i32 %t1, %t2", "  call void @print_i32(i32 %t3)") },

    @{ Id = 'IR08'; Desc = 'asociatividad izquierda en el IR: 10 - 3 - 2';
       Fuente = "print 10 - 3 - 2;";
       Cuerpo = @("  %t1 = sub i32 10, 3", "  %t2 = sub i32 %t1, 2", "  call void @print_i32(i32 %t2)") },

    @{ Id = 'IR09'; Desc = 'decimales con variables';
       Fuente = "let p = 25.5;`nlet c = 4.0;`nlet t = p * c;`nprint t;";
       Cuerpo = @("  %t1 = fmul double 25.5, 4.0", "  call void @print_f64(double %t1)") },

    @{ Id = 'IR10'; Desc = 'literales 0.1 y 0.2 en forma decimal corta';
       Fuente = "print 0.1 + 0.2;";
       Cuerpo = @("  %t1 = fadd double 0.1, 0.2", "  call void @print_f64(double %t1)") },

    @{ Id = 'IR11'; Desc = 'decimal muy grande en forma hexadecimal';
       Fuente = "print 100000000000000000000.0 + 1.0;";
       Contiene = "  %t1 = fadd double 0x" },

    @{ Id = 'IR15'; Desc = 'orden alterno de argumentos: -o antes de la entrada';
       Fuente = "print 1;"; Invertir = $true;
       Cuerpo = @("  call void @print_i32(i32 1)") }
)

foreach ($c in $exitosos) {
    $ruta = Join-Path $Tmp ($c.Id + '.olc')
    $ll = Join-Path $Tmp ($c.Id + '.ll')
    if (Test-Path -LiteralPath $ll) { Remove-Item -LiteralPath $ll }
    [System.IO.File]::WriteAllText($ruta, $c.Fuente)

    if ($c.Invertir) {
        $linea = '-o "' + $ll + '" "' + $ruta + '"'
    } else {
        $linea = '"' + $ruta + '" -o "' + $ll + '"'
    }
    $r = Ejecutar $linea

    $esperadoOut = "Analisis sintactico exitoso.`nAnalisis semantico exitoso.`nLLVM IR generado en $ll"
    $okOut = ((Normalizar $r.Out) -ceq $esperadoOut)

    $existe = Test-Path -LiteralPath $ll
    $contenido = ''
    if ($existe) { $contenido = Normalizar ([System.IO.File]::ReadAllText($ll)) }

    if ($c.Cuerpo) {
        $esperadoIr = ArmarIr $c.Cuerpo
        $okIr = ($contenido -ceq $esperadoIr)
    } else {
        $esperadoIr = "(debe contener) " + $c.Contiene
        $okIr = $contenido.Contains($c.Contiene)
    }

    $ok = ($r.Codigo -eq 0) -and $okOut -and $existe -and $okIr -and ($r.Err.Length -eq 0)
    if ($ok) {
        Write-Host "[PASS] $($c.Id) - $($c.Desc)"
        $aprobadas++
    } else {
        Write-Host "[FAIL] $($c.Id) - $($c.Desc)"
        Write-Host "       codigo: $($r.Codigo) (esperado 0), archivo creado: $existe"
        Write-Host "       --- stdout obtenido ---"
        Write-Host $r.Out
        Write-Host "       --- stderr obtenido ---"
        Write-Host $r.Err
        Write-Host "       --- IR esperado ---"
        Write-Host $esperadoIr
        Write-Host "       --- IR obtenido ---"
        Write-Host $contenido
        $fallidas++
    }
}

# --- Casos con fallo: no debe crearse el archivo de salida ------------------
# Cada caso: Id, descripcion, fuente, Modo de invocacion, codigo esperado,
# stdout esperado (lineas) y textos que deben aparecer en stderr.
$fallidos = @(
    @{ Id = 'IR12'; Desc = 'error semantico con -o: codigo 1 y sin archivo'; Modo = 'normal';
       Fuente = "let n = 10;`nlet f = 2.5;`nlet s = n + f;`nprint s;";
       Codigo = 1; Out = @("Analisis sintactico exitoso.");
       Err = @("ERROR SEMANTICO (linea 3, columna 9)", "No se genera LLVM IR") },

    @{ Id = 'IR13'; Desc = 'error sintactico con -o: codigo 1 y sin archivo'; Modo = 'normal';
       Fuente = "print 5";
       Codigo = 1; Out = @();
       Err = @("ERROR SINTACTICO (linea 1, columna 8)") },

    @{ Id = 'IR14'; Desc = 'error lexico con -o: codigo 1 y sin archivo'; Modo = 'normal';
       Fuente = "let a = 1 @;";
       Codigo = 1; Out = @();
       Err = @("ERROR LEXICO (linea 1, columna 11)") },

    @{ Id = 'IR16'; Desc = 'sin argumentos: uso y codigo 2'; Modo = 'sinargs';
       Fuente = "print 1;";
       Codigo = 2; Out = @();
       Err = @("Uso:") },

    @{ Id = 'IR17'; Desc = '-o sin valor: uso y codigo 2'; Modo = 'osinvalor';
       Fuente = "print 1;";
       Codigo = 2; Out = @();
       Err = @("Uso:") },

    @{ Id = 'IR18'; Desc = 'archivo de entrada inexistente: codigo 2 y sin archivo'; Modo = 'inexistente';
       Fuente = "print 1;";
       Codigo = 2; Out = @();
       Err = @("No such file or directory") }
)

foreach ($c in $fallidos) {
    $ruta = Join-Path $Tmp ($c.Id + '.olc')
    $ll = Join-Path $Tmp ($c.Id + '.ll')
    $inexistente = Join-Path $Tmp 'no_existe.olc'
    if (Test-Path -LiteralPath $ll) { Remove-Item -LiteralPath $ll }
    if (Test-Path -LiteralPath $inexistente) { Remove-Item -LiteralPath $inexistente }
    [System.IO.File]::WriteAllText($ruta, $c.Fuente)

    $linea = ''
    switch ($c.Modo) {
        'normal'      { $linea = '"' + $ruta + '" -o "' + $ll + '"' }
        'sinargs'     { $linea = '' }
        'osinvalor'   { $linea = '"' + $ruta + '" -o' }
        'inexistente' { $linea = '"' + $inexistente + '" -o "' + $ll + '"' }
    }
    $r = Ejecutar $linea

    $esperadoOut = $c.Out -join "`n"
    $okCod = ($r.Codigo -eq $c.Codigo)
    $okOut = ((Normalizar $r.Out) -ceq $esperadoOut)
    $okErr = $true
    foreach ($s in $c.Err) {
        if (-not $r.Err.Contains($s)) { $okErr = $false }
    }
    $sinArchivo = -not (Test-Path -LiteralPath $ll)

    if ($okCod -and $okOut -and $okErr -and $sinArchivo) {
        Write-Host "[PASS] $($c.Id) - $($c.Desc)"
        $aprobadas++
    } else {
        Write-Host "[FAIL] $($c.Id) - $($c.Desc)"
        Write-Host "       codigo: $($r.Codigo) (esperado $($c.Codigo)), sin archivo de salida: $sinArchivo"
        Write-Host "       --- stdout esperado ---"
        Write-Host $esperadoOut
        Write-Host "       --- stdout obtenido ---"
        Write-Host $r.Out
        Write-Host "       --- stderr obtenido ---"
        Write-Host $r.Err
        $fallidas++
    }
}

Write-Host ''
Write-Host "Pruebas de generacion de IR: $aprobadas aprobadas, $fallidas fallidas"
if ($fallidas -gt 0) { exit 1 }
exit 0