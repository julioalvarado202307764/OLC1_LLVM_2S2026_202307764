cmake_minimum_required(VERSION 3.13)

if(DEFINED PICO_SDK_PATH)
    include("${PICO_SDK_PATH}/external/pico_sdk_import.cmake")
elseif(DEFINED ENV{PICO_SDK_PATH})
    include("$ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake")
else()
    message(FATAL_ERROR "Configura PICO_SDK_PATH antes de CMake")
endif()

project(olc_pico C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
pico_sdk_init()

set(OLC_PROGRAM_S "${CMAKE_CURRENT_LIST_DIR}/../../build/pico_program.S"
    CACHE FILEPATH "Ensamblador Thumb generado por el compilador OLC1")
if(NOT EXISTS "${OLC_PROGRAM_S}")
    message(FATAL_ERROR "No existe ${OLC_PROGRAM_S}; genera el ensamblador antes de configurar CMake")
endif()

add_executable(olc_pico
    olc_entry.c
    "${OLC_PROGRAM_S}"
    "${CMAKE_CURRENT_LIST_DIR}/../../runtime/pico/olc_runtime.c"
)
target_link_libraries(olc_pico pico_stdlib)
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
# newlib-nano requiere incluir expresamente soporte printf para double.
target_link_options(olc_pico PRIVATE "-u" "_printf_float")
pico_add_extra_outputs(olc_pico)