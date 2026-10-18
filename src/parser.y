%code requires {
#include "ast.h"
}

%{
#include <stdio.h>
#include <stdlib.h>

#include "ast.h"
#include "errors.h"

int yylex(void);
void yyerror(const char *mensaje);

/* Raiz del AST. Solo queda asignada si el analisis sintactico termina bien.
   Quien la recibe es responsable de liberarla con ast_liberar. */
Nodo *ast_programa = NULL;
%}

%locations
%define parse.error verbose

%union {
    int    ival;
    double dval;
    char  *sval;
    Nodo  *nodo;
}

%token LET PRINT
%token <sval> ID
%token <ival> ENTERO
%token <dval> DECIMAL

%type <nodo> instrucciones instruccion expresion termino factor

%destructor { free($$); } <sval>
%destructor { ast_liberar($$); } <nodo>

%%

programa
    : instrucciones
        { ast_programa = $1; }
    ;

instrucciones
    : instrucciones instruccion
        { ast_programa_agregar($1, $2); $$ = $1; }
    | instruccion
        { $$ = ast_programa_nuevo(); ast_programa_agregar($$, $1); }
    ;

instruccion
    : LET ID '=' expresion ';'
        { $$ = ast_let_nuevo($2, $4, @2.first_line, @2.first_column); }
    | PRINT expresion ';'
        { $$ = ast_print_nuevo($2, @1.first_line, @1.first_column); }
    ;

expresion
    : expresion '+' termino
        { $$ = ast_binario_nuevo(OP_SUMA, $1, $3, @2.first_line, @2.first_column); }
    | expresion '-' termino
        { $$ = ast_binario_nuevo(OP_RESTA, $1, $3, @2.first_line, @2.first_column); }
    | termino
    ;

termino
    : termino '*' factor
        { $$ = ast_binario_nuevo(OP_MULT, $1, $3, @2.first_line, @2.first_column); }
    | termino '/' factor
        { $$ = ast_binario_nuevo(OP_DIV, $1, $3, @2.first_line, @2.first_column); }
    | factor
    ;

factor
    : ENTERO
        { $$ = ast_entero_nuevo($1, @1.first_line, @1.first_column); }
    | DECIMAL
        { $$ = ast_decimal_nuevo($1, @1.first_line, @1.first_column); }
    | ID
        { $$ = ast_id_nuevo($1, @1.first_line, @1.first_column); }
    | '(' expresion ')'
        { $$ = $2; }
    ;

%%

void yyerror(const char *mensaje)
{
    error_reportar(ERR_SINTACTICO, yylloc.first_line, yylloc.first_column,
                   "%s", mensaje);
}