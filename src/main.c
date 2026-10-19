#include <stdio.h>
#include <string.h>

#include "ast.h"
#include "codegen.h"
#include "errors.h"
#include "semantic.h"
#include "symtab.h"

extern FILE *yyin;
extern Nodo *ast_programa;
int yyparse(void);

static int uso(const char *programa)
{
    fprintf(stderr, "Uso: %s <entrada.olc> [-o <salida.ll>]\n", programa);
    return 2;
}

/* Escribe el IR en la ruta indicada. Devuelve 0 si todo salio bien, 1 si fallo
   la generacion (el archivo parcial se elimina) y 2 si no se pudo abrir. */
static int escribir_ir(const char *ruta, const Nodo *programa, TablaSimbolos *tabla)
{
    FILE *archivo = fopen(ruta, "wb");
    int fallo;

    if (archivo == NULL) {
        perror(ruta);
        return 2;
    }

    fallo = codegen_generar(programa, tabla, archivo);
    if (fclose(archivo) != 0) {
        fallo = 1;
    }

    if (fallo) {
        fprintf(stderr, "Error al generar el LLVM IR.\n");
        remove(ruta);
        return 1;
    }

    printf("LLVM IR generado en %s\n", ruta);
    return 0;
}

int main(int argc, char **argv)
{
    const char *entrada = NULL;
    const char *salida = NULL;
    int estado;
    int resultado = 0;
    int i;
    TablaSimbolos tabla;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0) {
            if (i + 1 >= argc || salida != NULL) {
                return uso(argv[0]);
            }
            i++;
            salida = argv[i];
        } else if (entrada == NULL) {
            entrada = argv[i];
        } else {
            return uso(argv[0]);
        }
    }
    if (entrada == NULL) {
        return uso(argv[0]);
    }

    yyin = fopen(entrada, "r");
    if (yyin == NULL) {
        perror(entrada);
        return 2;
    }

    estado = yyparse();
    fclose(yyin);

    if (estado != 0 || error_total() > 0) {
        fprintf(stderr, "Analisis fallido: %d error(es).\n", error_total());
        ast_liberar(ast_programa);
        ast_programa = NULL;
        return 1;
    }

    printf("Analisis sintactico exitoso.\n");

    tabla_iniciar(&tabla);
    semantico_analizar(ast_programa, &tabla);

    if (error_total() > 0) {
        fprintf(stderr,
                "Analisis semantico fallido: %d error(es). No se genera LLVM IR.\n",
                error_total());
        tabla_liberar(&tabla);
        ast_liberar(ast_programa);
        ast_programa = NULL;
        return 1;
    }

    printf("Analisis semantico exitoso.\n");

    if (salida != NULL) {
        resultado = escribir_ir(salida, ast_programa, &tabla);
    }

    tabla_liberar(&tabla);
    ast_liberar(ast_programa);
    ast_programa = NULL;
    return resultado;
}