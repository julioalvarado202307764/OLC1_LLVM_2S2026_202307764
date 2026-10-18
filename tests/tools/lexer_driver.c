/* Herramienta de prueba del lexer: imprime el flujo de tokens sin usar
   el parser. Define las variables que normalmente define parser.tab.c. */

#include <stdio.h>
#include <stdlib.h>

#include "errors.h"
#include "parser.tab.h"

YYSTYPE yylval;
YYLTYPE yylloc;

extern FILE *yyin;
extern char *yytext;
int yylex(void);

static void imprimir_token(int token)
{
    printf("%d:%d ", yylloc.first_line, yylloc.first_column);

    switch (token) {
    case LET:
        printf("LET\n");
        break;
    case PRINT:
        printf("PRINT\n");
        break;
    case ID:
        printf("ID %s\n", yylval.sval);
        free(yylval.sval);
        break;
    case ENTERO:
        printf("ENTERO %s (valor=%d)\n", yytext, yylval.ival);
        break;
    case DECIMAL:
        printf("DECIMAL %s (valor=%g)\n", yytext, yylval.dval);
        break;
    default:
        if (token > 0 && token < 256) {
            printf("'%c'\n", token);
        } else {
            printf("TOKEN_DESCONOCIDO(%d)\n", token);
        }
        break;
    }
}

int main(int argc, char **argv)
{
    int token;

    if (argc != 2) {
        fprintf(stderr, "Uso: %s <archivo>\n", argv[0]);
        return 2;
    }

    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        perror(argv[1]);
        return 2;
    }

    while ((token = yylex()) != 0) {
        imprimir_token(token);
    }

    fclose(yyin);
    printf("FIN errores=%d\n", error_total());
    return 0;
}