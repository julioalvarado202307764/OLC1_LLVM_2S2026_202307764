#ifndef SYMTAB_H
#define SYMTAB_H

#include <stdio.h>

#include "ast.h"
#include "tipos.h"

typedef struct {
    char *nombre;
    TipoDato tipo;
    int linea;                  /* posicion de la declaracion */
    int columna;
    const Nodo *inicializador;  /* expresion del AST con la que se declaro;
                                   la tabla no es duena de ese nodo */
} Simbolo;

/* Entorno unico global. Conserva el orden de insercion. */
typedef struct {
    Simbolo **simbolos;
    int cantidad;
    int capacidad;
} TablaSimbolos;

void tabla_iniciar(TablaSimbolos *tabla);

/* Libera todos los simbolos y deja la tabla vacia (reutilizable). */
void tabla_liberar(TablaSimbolos *tabla);

/* Devuelve el simbolo o NULL si no existe. Distingue mayusculas. */
const Simbolo *tabla_buscar(const TablaSimbolos *tabla, const char *nombre);

/* Inserta un simbolo copiando el nombre. Devuelve NULL, sin insertar nada,
   si ya existe uno con ese nombre. */
Simbolo *tabla_insertar(TablaSimbolos *tabla, const char *nombre, TipoDato tipo,
                        int linea, int columna, const Nodo *inicializador);

int tabla_cantidad(const TablaSimbolos *tabla);

/* Imprime "TABLA n" y una linea por simbolo: "  nombre : tipo @linea:columna". */
void tabla_imprimir(const TablaSimbolos *tabla, FILE *salida);

/* Simbolos creados y todavia no liberados (para pruebas). */
int tabla_simbolos_vivos(void);

#endif