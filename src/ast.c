#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ast.h"

static int nodos_vivos = 0;

static void *reservar(size_t bytes)
{
    void *bloque = malloc(bytes);
    if (bloque == NULL) {
        fprintf(stderr, "Error fatal: memoria insuficiente\n");
        exit(2);
    }
    return bloque;
}

static Nodo *nodo_nuevo(TipoNodo tipo, int linea, int columna)
{
    Nodo *nodo = reservar(sizeof(Nodo));

    memset(nodo, 0, sizeof(Nodo));
    nodo->tipo = tipo;
    nodo->linea = linea;
    nodo->columna = columna;
    nodos_vivos++;
    return nodo;
}

Nodo *ast_programa_nuevo(void)
{
    return nodo_nuevo(NODO_PROGRAMA, 1, 1);
}

void ast_programa_agregar(Nodo *programa, Nodo *instruccion)
{
    if (programa->u.programa.cantidad == programa->u.programa.capacidad) {
        int nueva = (programa->u.programa.capacidad == 0)
                        ? 4
                        : programa->u.programa.capacidad * 2;
        Nodo **bloque = realloc(programa->u.programa.instrucciones,
                                (size_t) nueva * sizeof(Nodo *));
        if (bloque == NULL) {
            fprintf(stderr, "Error fatal: memoria insuficiente\n");
            exit(2);
        }
        programa->u.programa.instrucciones = bloque;
        programa->u.programa.capacidad = nueva;
    }
    programa->u.programa.instrucciones[programa->u.programa.cantidad] = instruccion;
    programa->u.programa.cantidad++;
}

Nodo *ast_let_nuevo(char *nombre, Nodo *expresion, int linea, int columna)
{
    Nodo *nodo = nodo_nuevo(NODO_LET, linea, columna);

    nodo->u.let.nombre = nombre;
    nodo->u.let.expresion = expresion;
    return nodo;
}

Nodo *ast_print_nuevo(Nodo *expresion, int linea, int columna)
{
    Nodo *nodo = nodo_nuevo(NODO_PRINT, linea, columna);

    nodo->u.print.expresion = expresion;
    return nodo;
}

Nodo *ast_binario_nuevo(Operador op, Nodo *izq, Nodo *der, int linea, int columna)
{
    Nodo *nodo = nodo_nuevo(NODO_BINARIO, linea, columna);

    nodo->u.binario.op = op;
    nodo->u.binario.izq = izq;
    nodo->u.binario.der = der;
    return nodo;
}

Nodo *ast_entero_nuevo(int valor, int linea, int columna)
{
    Nodo *nodo = nodo_nuevo(NODO_ENTERO, linea, columna);

    nodo->u.entero.valor = valor;
    return nodo;
}

Nodo *ast_decimal_nuevo(double valor, int linea, int columna)
{
    Nodo *nodo = nodo_nuevo(NODO_DECIMAL, linea, columna);

    nodo->u.decimal.valor = valor;
    return nodo;
}

Nodo *ast_id_nuevo(char *nombre, int linea, int columna)
{
    Nodo *nodo = nodo_nuevo(NODO_ID, linea, columna);

    nodo->u.id.nombre = nombre;
    return nodo;
}

void ast_liberar(Nodo *nodo)
{
    int i;

    if (nodo == NULL) {
        return;
    }

    switch (nodo->tipo) {
    case NODO_PROGRAMA:
        for (i = 0; i < nodo->u.programa.cantidad; i++) {
            ast_liberar(nodo->u.programa.instrucciones[i]);
        }
        free(nodo->u.programa.instrucciones);
        break;
    case NODO_LET:
        free(nodo->u.let.nombre);
        ast_liberar(nodo->u.let.expresion);
        break;
    case NODO_PRINT:
        ast_liberar(nodo->u.print.expresion);
        break;
    case NODO_BINARIO:
        ast_liberar(nodo->u.binario.izq);
        ast_liberar(nodo->u.binario.der);
        break;
    case NODO_ID:
        free(nodo->u.id.nombre);
        break;
    case NODO_ENTERO:
    case NODO_DECIMAL:
        break;
    }

    free(nodo);
    nodos_vivos--;
}

const char *ast_operador_simbolo(Operador op)
{
    switch (op) {
    case OP_SUMA:  return "+";
    case OP_RESTA: return "-";
    case OP_MULT:  return "*";
    case OP_DIV:   return "/";
    }
    return "?";
}

int ast_nodos_vivos(void)
{
    return nodos_vivos;
}

static void indentar(FILE *salida, int nivel)
{
    int i;

    for (i = 0; i < nivel; i++) {
        fputs("  ", salida);
    }
}

/* Imprime un decimal agregando ".0" cuando no tiene parte fraccionaria,
   para distinguirlo visualmente de un entero. */
static void imprimir_decimal(FILE *salida, double valor)
{
    char texto[64];

    snprintf(texto, sizeof(texto), "%.15g", valor);
    fputs(texto, salida);
    if (strpbrk(texto, ".eEn") == NULL) {
        fputs(".0", salida);
    }
}

static void imprimir_nodo(const Nodo *nodo, FILE *salida, int nivel, int opciones)
{
    int i;

    indentar(salida, nivel);

    switch (nodo->tipo) {
    case NODO_PROGRAMA:
        fputs("Programa\n", salida);
        for (i = 0; i < nodo->u.programa.cantidad; i++) {
            imprimir_nodo(nodo->u.programa.instrucciones[i], salida, nivel + 1,
                          opciones);
        }
        return;
    case NODO_LET:
        fprintf(salida, "Let %s", nodo->u.let.nombre);
        break;
    case NODO_PRINT:
        fputs("Print", salida);
        break;
    case NODO_BINARIO:
        fprintf(salida, "Binario %s", ast_operador_simbolo(nodo->u.binario.op));
        break;
    case NODO_ENTERO:
        fprintf(salida, "Entero %d", nodo->u.entero.valor);
        break;
    case NODO_DECIMAL:
        fputs("Decimal ", salida);
        imprimir_decimal(salida, nodo->u.decimal.valor);
        break;
    case NODO_ID:
        fprintf(salida, "Id %s", nodo->u.id.nombre);
        break;
    }

    if ((opciones & AST_TIPOS) && nodo->tipo_dato != TIPO_DESCONOCIDO) {
        fprintf(salida, " : %s", tipo_nombre(nodo->tipo_dato));
    }
    if (opciones & AST_POSICIONES) {
        fprintf(salida, " @%d:%d", nodo->linea, nodo->columna);
    }
    fputc('\n', salida);

    switch (nodo->tipo) {
    case NODO_LET:
        imprimir_nodo(nodo->u.let.expresion, salida, nivel + 1, opciones);
        break;
    case NODO_PRINT:
        imprimir_nodo(nodo->u.print.expresion, salida, nivel + 1, opciones);
        break;
    case NODO_BINARIO:
        imprimir_nodo(nodo->u.binario.izq, salida, nivel + 1, opciones);
        imprimir_nodo(nodo->u.binario.der, salida, nivel + 1, opciones);
        break;
    default:
        break;
    }
}

void ast_imprimir(const Nodo *raiz, FILE *salida, int opciones)
{
    if (raiz != NULL) {
        imprimir_nodo(raiz, salida, 0, opciones);
    }
}