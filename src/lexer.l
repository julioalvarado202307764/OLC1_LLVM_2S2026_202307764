%option noyywrap nounput noinput never-interactive yylineno

%{
#include <stdlib.h>
#include "parser.tab.h"
%}

DIGITO [0-9]

%%

{DIGITO}+   { yylval = atoi(yytext); return ENTERO; }
"+"         { return '+'; }
";"         { return ';'; }
[ \t\r\n]+  { /* espacios en blanco: se ignoran */ }
.           { return yytext[0]; }

%%