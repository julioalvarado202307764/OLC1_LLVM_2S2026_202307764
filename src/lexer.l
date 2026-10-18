%option noyywrap nounput noinput never-interactive

%{
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "errors.h"
#include "parser.tab.h"

/* Posicion (base 1) del siguiente caracter que se va a leer. */
static int linea = 1;
static int columna = 1;

/* Antes de cada accion: registra la posicion del lexema y avanza. */
#define YY_USER_ACTION                            \
    yylloc.first_line   = linea;                  \
    yylloc.last_line    = linea;                  \
    yylloc.first_column = columna;                \
    yylloc.last_column  = columna + yyleng - 1;   \
    columna += yyleng;

static char *copiar_texto(const char *texto)
{
    char *copia = strdup(texto);
    if (copia == NULL) {
        fprintf(stderr, "Error fatal: memoria insuficiente\n");
        exit(2);
    }
    return copia;
}
%}

DIGITO     [0-9]
INICIO_ID  [A-Za-z_]
RESTO_ID   [A-Za-z0-9_]

%%

"let"                    { return LET; }
"print"                  { return PRINT; }

{INICIO_ID}{RESTO_ID}*   { yylval.sval = copiar_texto(yytext); return ID; }

{DIGITO}+"."{DIGITO}+    { yylval.dval = strtod(yytext, NULL); return DECIMAL; }

{DIGITO}+                {
        long long valor;

        errno = 0;
        valor = strtoll(yytext, NULL, 10);
        if (errno == ERANGE || valor > 2147483647LL) {
            error_reportar(ERR_LEXICO, yylloc.first_line, yylloc.first_column,
                           "entero fuera de rango de i32: %s", yytext);
            yylval.ival = 0;
        } else {
            yylval.ival = (int) valor;
        }
        return ENTERO;
    }

"+"                      { return '+'; }
"-"                      { return '-'; }
"*"                      { return '*'; }
"/"                      { return '/'; }
"("                      { return '('; }
")"                      { return ')'; }
"="                      { return '='; }
";"                      { return ';'; }

\n                       { linea++; columna = 1; }
[ \t\r]+                 { /* espacios en blanco: se ignoran */ }

<<EOF>>                  {
        yylloc.first_line   = linea;
        yylloc.last_line    = linea;
        yylloc.first_column = columna;
        yylloc.last_column  = columna;
        return 0;
    }

.                        {
        if (isprint((unsigned char) yytext[0])) {
            error_reportar(ERR_LEXICO, yylloc.first_line, yylloc.first_column,
                           "caracter no reconocido '%c'", yytext[0]);
        } else {
            error_reportar(ERR_LEXICO, yylloc.first_line, yylloc.first_column,
                           "caracter no reconocido (codigo 0x%02X)",
                           (unsigned int) (unsigned char) yytext[0]);
        }
    }

%%