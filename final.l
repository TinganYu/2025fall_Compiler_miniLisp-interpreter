%{
#include "y.tab.h"
#include <cstring>
#include <string>
using namespace std;

int paren_level = 0;
int need_body = 0;

string body_buffer;
%}

%x PARAM BODY 

%%

"("|")"|"+"|"-"|"*"|"/"|">"|"<"|"="     return yytext[0];

print\-num     return PRINT_NUM;
print\-bool    return PRINT_BOOL;
define        { return DEF; }
fun           { /*cout<<"infunc\n";*/BEGIN(PARAM); return FUNC; }

<PARAM>"("       { paren_level ++; return '('; }
<PARAM>")"       { 
                    paren_level--;
                    if (paren_level == 0){
                        need_body = 1;
                        BEGIN(BODY);
                        //cout<<"outparam\n";
                    }
                    return ')';
                 }

<PARAM>[a-zA-Z_][a-zA-Z0-9_-]* { yylval.sval=strdup(yytext); return ID; }
<PARAM>[ \t\n]+      { }
<PARAM>.             { }



"if" {
    BEGIN(BODY);
    need_body = 3;   // TEST / THEN / ELSE
    paren_level = 0;
    return IF;
}

<BODY>"(" {
    body_buffer += "(";
    paren_level ++;
}

<BODY>")" {
    body_buffer += ")";
    paren_level--;

    if (paren_level == 0) {
        yylval.sval = strdup(body_buffer.c_str());
        body_buffer.clear();
        need_body--;

        if (need_body > 0)
            BEGIN(BODY);
        else
            BEGIN(INITIAL);
        //cout<<"end if normal\n";
        return BODY_STR;
    }
}

<BODY>-?[1-9][0-9]*|0 {
    if (paren_level == 0) {
        yylval.sval = strdup(yytext);
        body_buffer.clear();
        need_body--;

        if (need_body > 0)
            BEGIN(BODY);
        else
            BEGIN(INITIAL);
        //cout<<"end if num\n";
        return BODY_STR;
    } else {
        body_buffer += yytext;
    }
}

<BODY>\#t|\#f {
    if (paren_level == 0) {
        yylval.sval = strdup(yytext);
        body_buffer.clear();
        need_body--;

        if (need_body > 0)
            BEGIN(BODY);
        else
            BEGIN(INITIAL);
        //cout<<"end if true false\n";
        return BODY_STR;
    } else {
        body_buffer += yytext;
    }
}


<BODY>[a-zA-Z_][a-zA-Z0-9_-]* {
    if (paren_level == 0) {
        yylval.sval = strdup(yytext);
        body_buffer.clear();
        need_body--;

        if (need_body > 0)
            BEGIN(BODY);
        else
            BEGIN(INITIAL);
        //cout<<"end if var\n"<<yytext<<endl;
        return BODY_STR;
    } else {
        body_buffer += yytext;
    }
}

<BODY>[ \t\n\r]+ {body_buffer += yytext;}

<BODY>. {body_buffer += yytext;}



and           return AND;
or            return OR;
not           return NOT;
mod           return MOD;

-?[1-9][0-9]*|0      { yylval.sval=strdup(yytext); return NUM; }
\#t           { yylval.sval=strdup(yytext); return BOOL; }
\#f           { yylval.sval=strdup(yytext); return BOOL; }

[a-zA-Z_][a-zA-Z0-9_-]* { yylval.sval=strdup(yytext); return ID; }

[ \t\n\r]+      {}
.               {}
%%

YY_BUFFER_STATE push_lexer_buffer(const char* s) { 
    YY_BUFFER_STATE old = YY_CURRENT_BUFFER;  //Lexer定義的，緩存
    YY_BUFFER_STATE buf = yy_scan_string(s);  //掃入快取
    yy_switch_to_buffer(buf);  //更新快取
    return old;
}

void pop_lexer_buffer(YY_BUFFER_STATE old) {
    YY_BUFFER_STATE cur = YY_CURRENT_BUFFER;
    yy_switch_to_buffer(old);
    yy_delete_buffer(cur);
}
