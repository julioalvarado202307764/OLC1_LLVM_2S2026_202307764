/* Herramienta de prueba de la tabla de simbolos: ejecuta comandos de un
   archivo y termina imprimiendo SIMBOLOS_VIVOS=<n> tras liberar la tabla. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "symtab.h"

static int tipo_desde_texto(const char *texto, TipoDato *tipo)
{
    if (strcmp(texto, "i32") == 0) {
        *tipo = TIPO_ENTERO;
        return 1;
    }
    if (strcmp(texto, "double") == 0) {
        *tipo = TIPO_DECIMAL;
        return 1;
    }
    if (strcmp(texto, "error") == 0) {
        *tipo = TIPO_ERROR;
        return 1;
    }
    return 0;
}

static int comando_invalido(int numero, TablaSimbolos *tabla, FILE *archivo)
{
    fprintf(stderr, "COMANDO_INVALIDO linea %d\n", numero);
    tabla_liberar(tabla);
    fclose(archivo);
    return 2;
}

int main(int argc, char **argv)
{
    FILE *archivo;
    TablaSimbolos tabla;
    char linea[256];
    int numero = 0;

    if (argc != 2) {
        fprintf(stderr, "Uso: %s <archivo de comandos>\n", argv[0]);
        return 2;
    }

    archivo = fopen(argv[1], "r");
    if (archivo == NULL) {
        perror(argv[1]);
        return 2;
    }

    tabla_iniciar(&tabla);

    while (fgets(linea, sizeof(linea), archivo) != NULL) {
        char comando[32];
        char nombre[128];
        char tipo_texto[32];
        int fila;
        int col;
        TipoDato tipo;
        const Simbolo *encontrado;

        numero++;
        if (sscanf(linea, "%31s", comando) != 1) {
            continue;
        }

        if (strcmp(comando, "insertar") == 0) {
            if (sscanf(linea, "%*s %127s %31s %d %d", nombre, tipo_texto, &fila, &col) != 4
                || !tipo_desde_texto(tipo_texto, &tipo)) {
                return comando_invalido(numero, &tabla, archivo);
            }
            if (tabla_insertar(&tabla, nombre, tipo, fila, col, NULL) != NULL) {
                printf("INSERTADO %s\n", nombre);
            } else {
                printf("DUPLICADO %s\n", nombre);
            }
        } else if (strcmp(comando, "buscar") == 0) {
            if (sscanf(linea, "%*s %127s", nombre) != 1) {
                return comando_invalido(numero, &tabla, archivo);
            }
            encontrado = tabla_buscar(&tabla, nombre);
            if (encontrado != NULL) {
                printf("ENCONTRADO %s %s @%d:%d\n", encontrado->nombre,
                       tipo_nombre(encontrado->tipo), encontrado->linea,
                       encontrado->columna);
            } else {
                printf("NO_ENCONTRADO %s\n", nombre);
            }
        } else if (strcmp(comando, "volcar") == 0) {
            tabla_imprimir(&tabla, stdout);
        } else if (strcmp(comando, "contar") == 0) {
            printf("CANTIDAD %d\n", tabla_cantidad(&tabla));
        } else {
            return comando_invalido(numero, &tabla, archivo);
        }
    }

    fclose(archivo);
    tabla_liberar(&tabla);
    printf("SIMBOLOS_VIVOS=%d\n", tabla_simbolos_vivos());
    return 0;
}