%{
#include <stdio.h>

int yylex(void);
void yyerror(const char *mensaje);
extern int yylineno;
%}

%define api.value.type {int}
%define parse.error verbose

%token ENTERO

%%

entrada
    : expresion ';'          { printf("Resultado de humo: %d\n", $1); }
    ;

expresion
    : expresion '+' ENTERO   { $$ = $1 + $3; }
    | ENTERO                 { $$ = $1; }
    ;

%%

void yyerror(const char *mensaje)
{
    fprintf(stderr, "Error sintactico en linea %d: %s\n", yylineno, mensaje);
}