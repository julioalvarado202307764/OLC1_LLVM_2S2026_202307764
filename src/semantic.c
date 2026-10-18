#include "ast.h"
#include "errors.h"
#include "semantic.h"
#include "symtab.h"
#include "tipos.h"

/* Posicion del token mas a la izquierda de una expresion. */
static void posicion_inicio(const Nodo *nodo, int *linea, int *columna)
{
    while (nodo->tipo == NODO_BINARIO) {
        nodo = nodo->u.binario.izq;
    }
    *linea = nodo->linea;
    *columna = nodo->columna;
}

/* Analiza una expresion, anota su tipo en el nodo y lo devuelve. */
static TipoDato analizar_expresion(Nodo *nodo, TablaSimbolos *tabla)
{
    TipoDato tipo = TIPO_DESCONOCIDO;

    switch (nodo->tipo) {
    case NODO_ENTERO:
        tipo = TIPO_ENTERO;
        break;

    case NODO_DECIMAL:
        tipo = TIPO_DECIMAL;
        break;

    case NODO_ID: {
        const Simbolo *simbolo = tabla_buscar(tabla, nodo->u.id.nombre);
        if (simbolo == NULL) {
            error_reportar(ERR_SEMANTICO, nodo->linea, nodo->columna,
                           "variable no declarada: '%s'", nodo->u.id.nombre);
            tipo = TIPO_ERROR;
        } else {
            tipo = simbolo->tipo;
        }
        break;
    }

    case NODO_BINARIO: {
        /* Se analizan siempre ambos lados para reportar los errores de los dos. */
        TipoDato izq = analizar_expresion(nodo->u.binario.izq, tabla);
        TipoDato der = analizar_expresion(nodo->u.binario.der, tabla);

        if (izq == TIPO_ERROR || der == TIPO_ERROR) {
            tipo = TIPO_ERROR;
        } else if (izq != der) {
            int linea;
            int columna;

            posicion_inicio(nodo, &linea, &columna);
            error_reportar(ERR_SEMANTICO, linea, columna,
                           "tipos incompatibles en la operacion: %s %s %s "
                           "(el lenguaje no hace conversion implicita entre "
                           "entero y decimal)",
                           tipo_nombre(izq),
                           ast_operador_simbolo(nodo->u.binario.op),
                           tipo_nombre(der));
            tipo = TIPO_ERROR;
        } else {
            tipo = izq;
        }
        break;
    }

    default:
        /* Los demas nodos no son expresiones. */
        break;
    }

    nodo->tipo_dato = tipo;
    return tipo;
}

static void analizar_let(Nodo *nodo, TablaSimbolos *tabla)
{
    const Simbolo *previo;
    TipoDato tipo = analizar_expresion(nodo->u.let.expresion, tabla);

    nodo->tipo_dato = tipo;

    previo = tabla_buscar(tabla, nodo->u.let.nombre);
    if (previo != NULL) {
        error_reportar(ERR_SEMANTICO, nodo->linea, nodo->columna,
                       "declaracion duplicada de '%s' "
                       "(ya declarada en linea %d, columna %d)",
                       nodo->u.let.nombre, previo->linea, previo->columna);
        return;
    }

    tabla_insertar(tabla, nodo->u.let.nombre, tipo, nodo->linea, nodo->columna,
                   nodo->u.let.expresion);
}

static void analizar_print(Nodo *nodo, TablaSimbolos *tabla)
{
    nodo->tipo_dato = analizar_expresion(nodo->u.print.expresion, tabla);
}

int semantico_analizar(Nodo *programa, TablaSimbolos *tabla)
{
    int antes = error_total();
    int i;

    if (programa == NULL) {
        return 0;
    }

    for (i = 0; i < programa->u.programa.cantidad; i++) {
        Nodo *instruccion = programa->u.programa.instrucciones[i];

        if (instruccion->tipo == NODO_LET) {
            analizar_let(instruccion, tabla);
        } else if (instruccion->tipo == NODO_PRINT) {
            analizar_print(instruccion, tabla);
        }
    }

    return error_total() - antes;
}