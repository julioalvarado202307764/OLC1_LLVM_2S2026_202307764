/* Herramienta de prueba del AST: analiza un archivo, imprime el arbol y
   libera todo. Siempre termina imprimiendo NODOS_VIVOS=<n>. */

#include <stdio.h>
#include <string.h>

#include "ast.h"
#include "errors.h"

extern FILE *yyin;
extern Nodo *ast_programa;
int yyparse(void);

static int uso(const char *programa)
{
    fprintf(stderr, "Uso: %s <archivo> [--pos]\n", programa);
    return 2;
}

int main(int argc, char **argv)
{
    const char *archivo = NULL;
    int con_posiciones = 0;
    int estado;
    int i;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--pos") == 0) {
            con_posiciones = 1;
        } else if (archivo == NULL) {
            archivo = argv[i];
        } else {
            return uso(argv[0]);
        }
    }
    if (archivo == NULL) {
        return uso(argv[0]);
    }

    yyin = fopen(archivo, "r");
    if (yyin == NULL) {
        perror(archivo);
        return 2;
    }

    estado = yyparse();
    fclose(yyin);

    if (estado == 0 && ast_programa != NULL) {
        ast_imprimir(ast_programa, stdout, con_posiciones);
    }

    ast_liberar(ast_programa);
    ast_programa = NULL;

    printf("NODOS_VIVOS=%d\n", ast_nodos_vivos());
    return (estado != 0 || error_total() > 0) ? 1 : 0;
}