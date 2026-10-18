#include <stdio.h>

#include "ast.h"
#include "errors.h"
#include "semantic.h"
#include "symtab.h"

extern FILE *yyin;
extern Nodo *ast_programa;
int yyparse(void);

int main(int argc, char **argv)
{
    int estado;
    TablaSimbolos tabla;

    if (argc != 2) {
        fprintf(stderr, "Uso: %s <archivo>\n", argv[0]);
        return 2;
    }

    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        perror(argv[1]);
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

    /* La Fase 5 generara aqui el LLVM IR a partir del AST y de la tabla. */
    tabla_liberar(&tabla);
    ast_liberar(ast_programa);
    ast_programa = NULL;
    return 0;
}