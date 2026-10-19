#ifndef CODEGEN_H
#define CODEGEN_H

#include <stdio.h>

#include "ast.h"
#include "symtab.h"

/* Escribe en `salida` el LLVM IR del programa. Requiere un AST sin errores
   semanticos (todos los nodos con tipo anotado) y la tabla de simbolos llena
   por el analisis semantico; asigna en la tabla el operando de cada variable.
   Devuelve 0 si todo salio bien y distinto de 0 si hubo un fallo. */
int codegen_generar(const Nodo *programa, TablaSimbolos *tabla, FILE *salida);

#endif