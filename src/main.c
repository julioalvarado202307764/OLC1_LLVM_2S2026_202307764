#include <stdio.h>

extern FILE *yyin;
int yyparse(void);

int main(int argc, char **argv)
{
    int estado;

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

    if (estado != 0) {
        fprintf(stderr, "Analisis sintactico fallido.\n");
        return 1;
    }

    printf("Analisis sintactico exitoso.\n");
    return 0;
}