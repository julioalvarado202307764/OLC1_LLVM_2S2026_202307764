#ifndef AST_H
#define AST_H

#include <stdio.h>

#include "tipos.h"

typedef enum {
    NODO_PROGRAMA,
    NODO_LET,
    NODO_PRINT,
    NODO_BINARIO,
    NODO_ENTERO,
    NODO_DECIMAL,
    NODO_ID
} TipoNodo;

typedef enum {
    OP_SUMA,
    OP_RESTA,
    OP_MULT,
    OP_DIV
} Operador;

/* Opciones de ast_imprimir (se combinan con |). */
#define AST_POSICIONES 1   /* agrega " @linea:columna" a cada nodo */
#define AST_TIPOS      2   /* agrega " : tipo" a los nodos con tipo asignado */

typedef struct Nodo Nodo;

/* Posicion principal (linea, columna base 1) de cada nodo:
   - literal e identificador: su token
   - operacion binaria: el token del operador
   - let: el identificador declarado
   - print: la palabra print
   - programa: 1,1 (sin posicion propia)

   tipo_dato lo asigna el analisis semantico (TIPO_DESCONOCIDO antes):
   - expresiones: su tipo
   - let: el tipo de la variable declarada
   - print: el tipo de la expresion impresa */
struct Nodo {
    TipoNodo tipo;
    TipoDato tipo_dato;
    int linea;
    int columna;
    union {
        struct { Nodo **instrucciones; int cantidad; int capacidad; } programa;
        struct { char *nombre; Nodo *expresion; } let;
        struct { Nodo *expresion; } print;
        struct { Operador op; Nodo *izq; Nodo *der; } binario;
        struct { int valor; } entero;
        struct { double valor; } decimal;
        struct { char *nombre; } id;
    } u;
};

/* Los constructores toman posesion de los nodos hijos y de las cadenas
   (nombre) que reciben. */
Nodo *ast_programa_nuevo(void);
void  ast_programa_agregar(Nodo *programa, Nodo *instruccion);
Nodo *ast_let_nuevo(char *nombre, Nodo *expresion, int linea, int columna);
Nodo *ast_print_nuevo(Nodo *expresion, int linea, int columna);
Nodo *ast_binario_nuevo(Operador op, Nodo *izq, Nodo *der, int linea, int columna);
Nodo *ast_entero_nuevo(int valor, int linea, int columna);
Nodo *ast_decimal_nuevo(double valor, int linea, int columna);
Nodo *ast_id_nuevo(char *nombre, int linea, int columna);

/* Libera el arbol completo (acepta NULL). */
void ast_liberar(Nodo *nodo);

/* Imprime el arbol con sangria de dos espacios por nivel.
   opciones: 0 o una combinacion de AST_POSICIONES y AST_TIPOS. */
void ast_imprimir(const Nodo *raiz, FILE *salida, int opciones);

const char *ast_operador_simbolo(Operador op);

/* Cantidad de nodos creados y todavia no liberados (para pruebas). */
int ast_nodos_vivos(void);

#endif