%{
#include <stdio.h>
#include <stdlib.h>

#include "errors.h"

int yylex(void);
void yyerror(const char *mensaje);
%}

%locations
%define parse.error verbose

%union {
    int    ival;
    double dval;
    char  *sval;
}

%token LET PRINT
%token <sval> ID
%token <ival> ENTERO
%token <dval> DECIMAL

%destructor { free($$); } <sval>

%%

programa
    : instrucciones
    ;

instrucciones
    : instrucciones instruccion
    | instruccion
    ;

instruccion
    : LET ID '=' expresion ';'   { free($2); }
    | PRINT expresion ';'
    ;

expresion
    : expresion '+' termino
    | expresion '-' termino
    | termino
    ;

termino
    : termino '*' factor
    | termino '/' factor
    | factor
    ;

factor
    : ENTERO                     { }
    | DECIMAL                    { }
    | ID                         { free($1); }
    | '(' expresion ')'
    ;

%%

void yyerror(const char *mensaje)
{
    error_reportar(ERR_SINTACTICO, yylloc.first_line, yylloc.first_column,
                   "%s", mensaje);
}