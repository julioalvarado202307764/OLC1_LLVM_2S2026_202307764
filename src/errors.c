#include <stdarg.h>
#include <stdio.h>

#include "errors.h"

static int total = 0;

static const char *nombre_tipo(TipoError tipo)
{
    switch (tipo) {
    case ERR_LEXICO:     return "LEXICO";
    case ERR_SINTACTICO: return "SINTACTICO";
    case ERR_SEMANTICO:  return "SEMANTICO";
    }
    return "DESCONOCIDO";
}

void error_reportar(TipoError tipo, int linea, int columna,
                    const char *formato, ...)
{
    va_list args;

    fprintf(stderr, "ERROR %s (linea %d, columna %d): ",
            nombre_tipo(tipo), linea, columna);

    va_start(args, formato);
    vfprintf(stderr, formato, args);
    va_end(args);

    fputc('\n', stderr);
    total++;
}

int error_total(void)
{
    return total;
}