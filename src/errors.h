#ifndef ERRORS_H
#define ERRORS_H

typedef enum {
    ERR_LEXICO,
    ERR_SINTACTICO,
    ERR_SEMANTICO
} TipoError;

#if defined(__GNUC__)
#define ERRORS_FORMATO(a, b) __attribute__((format(printf, a, b)))
#else
#define ERRORS_FORMATO(a, b)
#endif

/* Imprime en stderr: ERROR <TIPO> (linea L, columna C): mensaje
   y cuenta el error. */
void error_reportar(TipoError tipo, int linea, int columna,
                    const char *formato, ...) ERRORS_FORMATO(4, 5);

/* Cantidad total de errores reportados hasta el momento. */
int error_total(void);

#endif