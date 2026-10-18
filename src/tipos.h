#ifndef TIPOS_H
#define TIPOS_H

typedef enum {
    TIPO_DESCONOCIDO = 0,   /* todavia no analizado */
    TIPO_ENTERO,            /* i32 */
    TIPO_DECIMAL,           /* double */
    TIPO_ERROR              /* expresion o variable con un error semantico previo */
} TipoDato;

static inline const char *tipo_nombre(TipoDato tipo)
{
    switch (tipo) {
    case TIPO_ENTERO:      return "i32";
    case TIPO_DECIMAL:     return "double";
    case TIPO_ERROR:       return "error";
    case TIPO_DESCONOCIDO: return "desconocido";
    }
    return "desconocido";
}

#endif