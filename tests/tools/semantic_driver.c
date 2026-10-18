/* Herramienta de prueba del analisis semantico: analiza un archivo, imprime el
   AST con tipos y la tabla de simbolos, libera todo y termina imprimiendo
   NODOS_VIVOS y SIMBOLOS_VIVOS. Opcion --pos: agrega posiciones al AST. */

#include <stdio.h>
#include <string.h>

#include "ast.h"
#include "errors.h"
#include "semantic.h"
#include "symtab.h"

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
    TablaSimbolos tabla;

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

    tabla_iniciar(&tabla);

    if (estado == 0 && error_total() == 0) {
        semantico_analizar(ast_programa, &tabla);
        ast_imprimir(ast_programa, stdout,
                     AST_TIPOS | (con_posiciones ? AST_POSICIONES : 0));
        tabla_imprimir(&tabla, stdout);
    }

    tabla_liberar(&tabla);
    ast_liberar(ast_programa);
    ast_programa = NULL;

    printf("NODOS_VIVOS=%d\n", ast_nodos_vivos());
    printf("SIMBOLOS_VIVOS=%d\n", tabla_simbolos_vivos());
    return (error_total() > 0) ? 1 : 0;
}