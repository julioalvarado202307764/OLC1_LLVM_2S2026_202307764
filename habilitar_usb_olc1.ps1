# Habilita un segundo build de firmware OLC1 con USB CDC sin romper el modo UART.
# Ejecucion: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\habilitar_usb_olc1.ps1
# Ejecutar desde la raiz del proyecto LLVM. No realiza operaciones de Git.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$raiz = (Get-Location).Path
$archivoCmake = Join-Path $raiz 'targets\pico\CMakeLists.txt'
$archivoEntry = Join-Path $raiz 'targets\pico\olc_entry.c'
foreach ($archivo in @($archivoCmake, $archivoEntry)) {
    if (-not (Test-Path -LiteralPath $archivo)) {
        throw "No existe el archivo requerido: ${archivo}"
    }
}

function CambiarUna([string]$texto, [string]$actual, [string]$nuevo, [string]$nombre) {
    $coincidencias = [regex]::Matches($texto, [regex]::Escape($actual)).Count
    if ($coincidencias -ne 1) {
        throw "No se modifica ${nombre}: se esperaban 1 coincidencia, hay $coincidencias"
    }
    return $texto.Replace($actual, $nuevo)
}

$cmake = [System.IO.File]::ReadAllText($archivoCmake).Replace("`r`n", "`n")
$entry = [System.IO.File]::ReadAllText($archivoEntry).Replace("`r`n", "`n")
if ($cmake.Contains('OLC_USB_STDIO') -or $entry.Contains('stdio_usb_connected')) {
    throw 'La variante USB ya parece aplicada. No se modifico ningun archivo.'
}

$modoAnterior = "pico_enable_stdio_usb(olc_pico 0)`npico_enable_stdio_uart(olc_pico 1)"
$modoNuevo = @'
option(OLC_USB_STDIO "Habilitar consola serial USB CDC" OFF)
if(OLC_USB_STDIO)
    if(NOT TARGET pico_stdio_usb)
        message(FATAL_ERROR "TinyUSB no disponible: configura PICO_TINYUSB_PATH")
    endif()
    pico_enable_stdio_usb(olc_pico 1)
    pico_enable_stdio_uart(olc_pico 0)
    target_compile_definitions(olc_pico PRIVATE OLC_USB_STDIO=1)
else()
    pico_enable_stdio_usb(olc_pico 0)
    pico_enable_stdio_uart(olc_pico 1)
    target_compile_definitions(olc_pico PRIVATE OLC_USB_STDIO=0)
endif()
'@
$modoNuevo = $modoNuevo.TrimEnd()
$cmakeNuevo = CambiarUna $cmake $modoAnterior $modoNuevo 'targets/pico/CMakeLists.txt'

$includeViejo = '#include "pico/stdlib.h"'
$includeNuevo = @'
#include "pico/stdlib.h"
#if OLC_USB_STDIO
#include "pico/stdio_usb.h"
#endif
'@
$includeNuevo = $includeNuevo.TrimEnd()
$entryNuevo = CambiarUna $entry $includeViejo $includeNuevo 'targets/pico/olc_entry.c includes'
$entryNuevo = CambiarUna $entryNuevo '    stdio_init_all();  /* Se habilitara UART en CMake, no USB. */' '    stdio_init_all();  /* UART o USB CDC, segun el modo de CMake. */' 'targets/pico/olc_entry.c inicializacion'
$ejecucionAnterior = '    (void)olc_program();'
$ejecucionNueva = @'
#if OLC_USB_STDIO
    /* Esperar a que la terminal USB CDC se abra (DTR activo).
       Mientras tanto, el LED permanece encendido como indicador de arranque. */
    while (!stdio_usb_connected()) {
        sleep_ms(50);
    }
    sleep_ms(300); /* Reducir riesgo de perder el primer mensaje. */
#endif
    (void)olc_program();
'@
$ejecucionNueva = $ejecucionNueva.TrimEnd()
$entryNuevo = CambiarUna $entryNuevo $ejecucionAnterior $ejecucionNueva 'targets/pico/olc_entry.c ejecucion'

$backup = Join-Path $env:TEMP ('OLC1_usb_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Copy-Item -LiteralPath $archivoCmake -Destination (Join-Path $backup 'CMakeLists.txt')
Copy-Item -LiteralPath $archivoEntry -Destination (Join-Path $backup 'olc_entry.c')
$utf8SinBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($archivoCmake, $cmakeNuevo, $utf8SinBom)
[System.IO.File]::WriteAllText($archivoEntry, $entryNuevo, $utf8SinBom)
Write-Host "RESPALDO: $backup"
Write-Host 'MODIFICADO: targets/pico/CMakeLists.txt'
Write-Host 'MODIFICADO: targets/pico/olc_entry.c'
Write-Host 'USB CDC CONFIGURADO. Aun falta generar y verificar el firmware USB.'
