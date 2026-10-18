#ifndef SEMANTIC_H
#define SEMANTIC_H

#include "ast.h"
#include "symtab.h"

/* Recorre el AST en orden, anota el tipo de cada expresion y llena la tabla
   de simbolos. Reporta los errores semanticos con error_reportar y devuelve
   cuantos encontro. Analiza todo el programa aunque haya errores. */
int semantico_analizar(Nodo *programa, TablaSimbolos *tabla);

#endif