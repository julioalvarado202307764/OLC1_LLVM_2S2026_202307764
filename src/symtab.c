#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "symtab.h"

#define CAPACIDAD_INICIAL 8

static int simbolos_vivos = 0;

static void *reservar(size_t bytes)
{
    void *bloque = malloc(bytes);
    if (bloque == NULL) {
        fprintf(stderr, "Error fatal: memoria insuficiente\n");
        exit(2);
    }
    return bloque;
}

void tabla_iniciar(TablaSimbolos *tabla)
{
    tabla->simbolos = NULL;
    tabla->cantidad = 0;
    tabla->capacidad = 0;
}

void tabla_liberar(TablaSimbolos *tabla)
{
    int i;

    for (i = 0; i < tabla->cantidad; i++) {
        free(tabla->simbolos[i]->nombre);
        free(tabla->simbolos[i]->operando);
        free(tabla->simbolos[i]);
        simbolos_vivos--;
    }
    free(tabla->simbolos);
    tabla_iniciar(tabla);
}

const Simbolo *tabla_buscar(const TablaSimbolos *tabla, const char *nombre)
{
    int i;

    for (i = 0; i < tabla->cantidad; i++) {
        if (strcmp(tabla->simbolos[i]->nombre, nombre) == 0) {
            return tabla->simbolos[i];
        }
    }
    return NULL;
}

Simbolo *tabla_insertar(TablaSimbolos *tabla, const char *nombre, TipoDato tipo,
                        int linea, int columna, const Nodo *inicializador)
{
    Simbolo *simbolo;

    if (tabla_buscar(tabla, nombre) != NULL) {
        return NULL;
    }

    if (tabla->cantidad == tabla->capacidad) {
        int nueva = (tabla->capacidad == 0) ? CAPACIDAD_INICIAL : tabla->capacidad * 2;
        Simbolo **bloque = realloc(tabla->simbolos, (size_t) nueva * sizeof(Simbolo *));
        if (bloque == NULL) {
            fprintf(stderr, "Error fatal: memoria insuficiente\n");
            exit(2);
        }
        tabla->simbolos = bloque;
        tabla->capacidad = nueva;
    }

    simbolo = reservar(sizeof(Simbolo));
    simbolo->nombre = reservar(strlen(nombre) + 1);
    strcpy(simbolo->nombre, nombre);
    simbolo->tipo = tipo;
    simbolo->linea = linea;
    simbolo->columna = columna;
    simbolo->inicializador = inicializador;
    simbolo->operando = NULL;

    tabla->simbolos[tabla->cantidad] = simbolo;
    tabla->cantidad++;
    simbolos_vivos++;
    return simbolo;
}

int tabla_asignar_operando(TablaSimbolos *tabla, const char *nombre,
                           const char *operando)
{
    int i;

    for (i = 0; i < tabla->cantidad; i++) {
        Simbolo *simbolo = tabla->simbolos[i];

        if (strcmp(simbolo->nombre, nombre) == 0) {
            char *copia = reservar(strlen(operando) + 1);

            strcpy(copia, operando);
            free(simbolo->operando);
            simbolo->operando = copia;
            return 1;
        }
    }
    return 0;
}

int tabla_cantidad(const TablaSimbolos *tabla)
{
    return tabla->cantidad;
}

void tabla_imprimir(const TablaSimbolos *tabla, FILE *salida)
{
    int i;

    fprintf(salida, "TABLA %d\n", tabla->cantidad);
    for (i = 0; i < tabla->cantidad; i++) {
        const Simbolo *s = tabla->simbolos[i];
        fprintf(salida, "  %s : %s @%d:%d\n", s->nombre, tipo_nombre(s->tipo),
                s->linea, s->columna);
    }
}

int tabla_simbolos_vivos(void)
{
    return simbolos_vivos;
}