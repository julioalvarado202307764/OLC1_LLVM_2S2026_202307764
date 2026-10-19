#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "codegen.h"
#include "tipos.h"

typedef struct {
    FILE *salida;
    TablaSimbolos *tabla;
    int ultimo_temporal;   /* ultimo %tN emitido; los temporales no se reutilizan */
    int fallo;
} Generador;

/* Texto de un operando LLVM: literal, temporal (%tN) o el operando de una variable. */
typedef struct {
    char texto[64];
} Operando;

static void error_interno(Generador *g, const char *mensaje)
{
    fprintf(stderr, "Error interno del generador: %s\n", mensaje);
    g->fallo = 1;
}

static const char *tipo_ir(TipoDato tipo)
{
    switch (tipo) {
    case TIPO_ENTERO:  return "i32";
    case TIPO_DECIMAL: return "double";
    default:           return NULL;
    }
}

static const char *instruccion_ir(Operador op, TipoDato tipo)
{
    int decimal = (tipo == TIPO_DECIMAL);

    switch (op) {
    case OP_SUMA:  return decimal ? "fadd" : "add";
    case OP_RESTA: return decimal ? "fsub" : "sub";
    case OP_MULT:  return decimal ? "fmul" : "mul";
    case OP_DIV:   return decimal ? "fdiv" : "sdiv";
    }
    return NULL;
}

/* Literal decimal para LLVM: la forma decimal mas corta que recupere exactamente
   el mismo double (con ".0" si no tiene parte fraccionaria). Si hace falta
   notacion cientifica, o es infinito o NaN, usa la forma hexadecimal de LLVM. */
static void formatear_decimal(double valor, char *destino, size_t tam)
{
    uint64_t bits;
    int precision;

    for (precision = 15; precision <= 17; precision++) {
        snprintf(destino, tam, "%.*g", precision, valor);
        if (strtod(destino, NULL) == valor) {
            break;
        }
    }

    if (strpbrk(destino, "eEn") != NULL) {
        memcpy(&bits, &valor, sizeof(bits));
        snprintf(destino, tam, "0x%08lX%08lX",
                 (unsigned long) (bits >> 32),
                 (unsigned long) (bits & 0xFFFFFFFFu));
    } else if (strchr(destino, '.') == NULL) {
        strncat(destino, ".0", tam - strlen(destino) - 1);
    }
}

/* Genera el codigo de una expresion (hijo izquierdo y luego derecho) y devuelve
   el operando que contiene su valor. */
static Operando generar_expresion(const Nodo *nodo, Generador *g)
{
    Operando resultado;

    resultado.texto[0] = '\0';

    switch (nodo->tipo) {
    case NODO_ENTERO:
        snprintf(resultado.texto, sizeof(resultado.texto), "%d", nodo->u.entero.valor);
        break;

    case NODO_DECIMAL:
        formatear_decimal(nodo->u.decimal.valor, resultado.texto, sizeof(resultado.texto));
        break;

    case NODO_ID: {
        const Simbolo *simbolo = tabla_buscar(g->tabla, nodo->u.id.nombre);

        if (simbolo == NULL || simbolo->operando == NULL) {
            error_interno(g, "variable sin operando asignado");
        } else {
            snprintf(resultado.texto, sizeof(resultado.texto), "%s", simbolo->operando);
        }
        break;
    }

    case NODO_BINARIO: {
        Operando izq = generar_expresion(nodo->u.binario.izq, g);
        Operando der = generar_expresion(nodo->u.binario.der, g);
        const char *tipo = tipo_ir(nodo->tipo_dato);
        const char *instruccion = instruccion_ir(nodo->u.binario.op, nodo->tipo_dato);

        if (tipo == NULL || instruccion == NULL) {
            error_interno(g, "operacion sin tipo valido");
            break;
        }

        g->ultimo_temporal++;
        snprintf(resultado.texto, sizeof(resultado.texto), "%%t%d", g->ultimo_temporal);
        fprintf(g->salida, "  %s = %s %s %s, %s\n", resultado.texto, instruccion, tipo,
                izq.texto, der.texto);
        break;
    }

    default:
        error_interno(g, "nodo que no es una expresion");
        break;
    }

    return resultado;
}

static void generar_instruccion(const Nodo *nodo, Generador *g)
{
    Operando valor;

    switch (nodo->tipo) {
    case NODO_LET:
        /* No emite instrucciones: la variable pasa a representarse por el
           operando de su expresion. */
        valor = generar_expresion(nodo->u.let.expresion, g);
        if (!tabla_asignar_operando(g->tabla, nodo->u.let.nombre, valor.texto)) {
            error_interno(g, "variable declarada que no esta en la tabla");
        }
        break;

    case NODO_PRINT: {
        const char *tipo = tipo_ir(nodo->tipo_dato);

        valor = generar_expresion(nodo->u.print.expresion, g);
        if (tipo == NULL) {
            error_interno(g, "print sin tipo valido");
            break;
        }
        fprintf(g->salida, "  call void @%s(%s %s)\n",
                (nodo->tipo_dato == TIPO_ENTERO) ? "print_i32" : "print_f64",
                tipo, valor.texto);
        break;
    }

    default:
        error_interno(g, "nodo que no es una instruccion");
        break;
    }
}

int codegen_generar(const Nodo *programa, TablaSimbolos *tabla, FILE *salida)
{
    Generador g;
    int i;

    if (programa == NULL || programa->tipo != NODO_PROGRAMA) {
        return 1;
    }

    g.salida = salida;
    g.tabla = tabla;
    g.ultimo_temporal = 0;
    g.fallo = 0;

    fputs("declare void @print_i32(i32)\n", salida);
    fputs("declare void @print_f64(double)\n", salida);
    fputs("\n", salida);
    fputs("define i32 @main() {\n", salida);
    fputs("entry:\n", salida);

    for (i = 0; i < programa->u.programa.cantidad; i++) {
        generar_instruccion(programa->u.programa.instrucciones[i], &g);
    }

    fputs("  ret i32 0\n", salida);
    fputs("}\n", salida);

    if (g.fallo || ferror(salida)) {
        return 1;
    }
    return 0;
}