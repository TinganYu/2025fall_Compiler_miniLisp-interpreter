%{
#include <bits/stdc++.h>
#include "function.h"
using namespace std;

extern int yylex();
void yyerror(const char *s);

//YY_BUFFER_STATE 是 Lexer 提供的 yy_buffer_state 指針， 可以控制lexer的輸入流
typedef struct yy_buffer_state *YY_BUFFER_STATE;  
extern YY_BUFFER_STATE push_lexer_buffer(const char* s);
extern void pop_lexer_buffer(YY_BUFFER_STATE old);

int error = 0;      //記錄錯誤
double answer = 0;  
int syntax_only_mode=0;  //現在需不需要實際計算值，還是只是檢查syntax
map<string,Function> func_table; //紀錄function名稱以及(參數&func body)
double recursive_parse_eval(const string &expr, int syntax_check);  //呼叫function時產生新的parser

vector< map<string,double> > env_stack;  //紀錄當前作用域的variable及對應數值  所以像是 [{global}, {outer func}..., {current func}]

void push_env(){  //加入新的 例如 function call
    env_stack.push_back(map<string,double>());
}

void pop_env(){  //結束，local variable銷毀
    env_stack.pop_back();
}

void bind_var(const string &n,double v){  //將值存入 define var時用到
    env_stack.back()[n]=v;  //最末端的作用域 = 目前的作用域
}

// 綁定虛擬變數 (檢查body時，臨時parameter用)
void bind_temp_vars(const vector<string> &params) {
    int i=0;
    for (i=0;i< params.size();i++) {
        env_stack.back()[params[i]] = 1.0;     // 隨便假設為 1，只是為了讓 lookup_var 可以找到它
    }
}

double lookup_var(const string &n){   //從stack裡面找到相對應的 var
    for(int i=env_stack.size()-1;i>=0;i--){   //從最外層(最新)的環境開始找變數
        map<string,double>::iterator it = env_stack[i].find(n);  
        if(it!=env_stack[i].end()) return it->second;
    }
    yyerror("Undefined variable");
    return 0;
}

//檢查 ID 是否已被定義
bool check_id_defined(const string &id) {
    if (func_table.count(id)) { //找function名
        return true;
    } 
    for (size_t i = 0; i < env_stack.size(); ++i) { //找var名
        if (env_stack[i].count(id)) {
            return true;
        }
    }
    return false;
}

%}

%code requires{
    #include "function.h"
}

%union{
    double fval;
    char* sval;
    vector<double>* dlist;  //存parameter值 (當作Expression*)  
    vector<string>* slist;  //存parameter名稱
    Function* fun;          //function的樣子，有parameter&body
}
%token PRINT_NUM PRINT_BOOL IF AND OR NOT MOD DEF FUNC ERROR_TOKEN
%token<sval> NUM ID BOOL BODY_STR

%type<fval> Line Expressions Expression Math Logic If_func FuncCall Print
%type<dlist> Param
%type<slist> ParamID  
%type<fun> FuncExp
%type<sval> DefIDHandle
%%

Line: Line Expressions { answer=$2; }
    | Expressions { answer=$1; }
    ;

Expressions : Expression { $$=$1; }
            | Print { $$=answer; }
            | Define { $$=answer; }
            ;

Print   : '(' PRINT_NUM Expression ')' {if(error){yyerror;YYABORT;} cout<<$3<<endl; $$=$3; }
        | '(' PRINT_BOOL Expression ')' {if(error){yyerror;YYABORT;} if($3!=0){cout<<"#t"<<endl;}else{cout<<"#f"<<endl;} $$=$3; }
        ;

DefIDHandle : ID {
                    $$ = $1;
                    if (check_id_defined(string($$))) {    // 檢查是不是已存在的變數或函數
                        yyerror("Redefining is not allowed.");
                        YYABORT;
                    }
                    
                    func_table[string($$)] = Function(); // temp函數佔位 因為 funcall檢察要看
                    //只有recursive function會需要有先binding (變數到時候直接存就好)
                 }
            ;

Define  : '(' DEF DefIDHandle FuncExp ')'
            {
                string func_name($3); 
                //FuncExp檢查完
                if (error) {
                    func_table.erase(func_name); 
                } else if (syntax_only_mode == 0) {
                    func_table[func_name] = *$4; 
                } else {
                    func_table.erase(func_name); //只是測試所以可以刪掉
                }
                
                delete $4;
                free($3);
            }
        | '(' DEF DefIDHandle Expression ')' 
            { 
                string var_name($3); 
                func_table.erase(var_name); //不是函數所以可以直接刪掉
                if (syntax_only_mode == 0) bind_var(var_name, $4);  // 存入變數
                
                free($3);
            }
        ;

Expression  : NUM { $$=atof($1); }
            | ID { $$=lookup_var(string($1)); }
            | BOOL { $$ = strcmp($1,"#t")==0; }
            | Math { $$=$1; }
            | Logic { $$=$1; }
            | If_func { $$=$1; }
            | FuncCall { $$=$1; }
            ;

Math: '(' '+' Expression Expression Param ')' { 
        double sum = 0,i;
        for(i = 0; i < $5->size(); i++) sum += (*$5)[i] ;
        delete $5;
        sum+=$3;
        sum+=$4;
        $$ = sum; 
      }
    | '(' '-' Expression Expression ')' { $$=$3-$4; }
    | '(' '*' Expression Expression Param ')' {
        double ans = 1, i;
        for(i = 0; i < $5->size(); i++) ans *= (*$5)[i] ;
        delete $5;
        ans*=$3;
        ans*=$4;
        $$ = ans;
      }
    | '(' '/' Expression Expression ')' { if($4==0){yyerror("devider cannot be 0");YYABORT;} $$=(double)(int)($3/$4);; }
    | '(' MOD Expression Expression ')' { if($4==0){yyerror("devider cannot be 0");YYABORT;} $$=(int)$3%(int)$4; }
    | '(' '>' Expression Expression ')' { $$=$3>$4; }
    | '(' '<' Expression Expression ')' { $$=$3<$4; }
    | '(' '=' Expression Expression Param ')'{
        double ans = 1, i, num;
        if($3==$4){
            num=$3;
            for(i = 0; i < $5->size(); i++){
                if(num!=(*$5)[i]){
                    ans=0;
                    break;
                } 
            }
        }else{
            ans=0; 
        }
        delete $5;
        $$ = ans;
      }
    ;

Logic   : '(' AND Expression Expression Param ')' {
            double ans = 1, i;
            ans= ans&&$3;
            ans= ans&&$4;
            for(i = 0; i < $5->size(); i++){
                ans = ans && ((*$5)[i] != 0);
            }
            delete $5;
            $$ = ans;
        }
        | '(' OR Expression Expression Param ')' {
            double ans = 0, i;
            ans= ans||$3;
            ans= ans||$4;
            for(i = 0; i < $5->size(); i++){
                ans = ans || ((*$5)[i] != 0);
            }
            delete $5;
            $$ = ans;
        }
        | '(' NOT Expression ')' { $$=!($3!=0); }
        ;

If_func : '(' IF BODY_STR BODY_STR BODY_STR')' {  
            recursive_parse_eval(string($3), 1);  //先檢查三個body文法
            if (error) { // 如果語法檢查過程中發現錯誤，立刻停止
                yyerror("Syntax error in IF branches"); 
                YYABORT; 
            }
            recursive_parse_eval(string($4), 1);
            if (error) { 
                yyerror("Syntax error in IF branches"); 
                YYABORT; 
            }
            recursive_parse_eval(string($5), 1);            
            if (error) { 
                yyerror("Syntax error in IF branches"); 
                YYABORT; 
            }

            if (syntax_only_mode == 1) {
                $$ = 1; // 僅檢查模式，直接回傳
            } else {
                // 真正的求值階段：根據 TEST-EXP 的結果決定執行哪一邊
                if (recursive_parse_eval(string($3), 0) != 0) {
                    if(error) { yyerror("Error in IF condition"); YYABORT; }
                    $$ = recursive_parse_eval(string($4), 0);
                } else {
                    if(error) { yyerror("Error in IF condition"); YYABORT; }
                    $$ = recursive_parse_eval(string($5), 0);
                }
            }
            
            if(error) { yyerror("Error in IF execution"); YYABORT; }
        }
        ;

FuncExp : '(' FUNC '(' ParamID ')' BODY_STR ')'
        {
            // BodySTR內部語法檢查
            vector<string> *params_ptr = $4;
            push_env(); // 建立臨時檢查環境
            bind_temp_vars(*params_ptr); // 綁定暫時參數名稱
            recursive_parse_eval(string($6), 1); // 進行語法檢查 1代表是臨時的
            pop_env(); // 移除臨時檢查環境
            if(error){yyerror; YYABORT;}
            
            Function* f=new Function;
            f->parameters = *$4;
            f->body = string($6);
            $$=f;
            delete $4;
            free($6);
        }
        ;

FuncCall: '(' ID Param ')'
        {
            string fname($2);
            if(func_table.find(fname)==func_table.end()){  //確定有該function名
                yyerror("Undefined function");
                YYABORT;
                $$=0;
            }else{
                
                if (syntax_only_mode == 0) {  //不應該在繼續往下展開，funexp已經檢查過了，避免recursive
                    Function &f=func_table[fname];
                    vector<double> &args=*$3;
                    if(args.size()!=f.parameters.size()){  //確定Argument&parameter數量正確
                        yyerror("Argument count mismatch");
                        YYABORT;
                        $$=0;
                    }else{
                        push_env();
                        for(int i=0;i<args.size();i++)
                            bind_var(f.parameters[i],args[i]);
                        $$=recursive_parse_eval(f.body,syntax_only_mode);
                        pop_env();
                        if(error){yyerror;YYABORT;}
                    }
                }else{
                    $$=1;
                }
                delete $3;
            }
        }
        |   '(' FuncExp Param ')'
        { 
            Function *f = $2;
            vector<double> &args = *$3; //參數實際值
            double result = 0;

            // 參數數量檢查
            if (args.size() != f->parameters.size()){
                yyerror("Argument count mismatch in anonymous function call");
                YYABORT;
                result = 0;
            } else {
                if (syntax_only_mode == 0) { 
                    push_env();
                    for(size_t i = 0; i < args.size(); i++)
                        bind_var(f->parameters[i], args[i]);
                    result = recursive_parse_eval(f->body, syntax_only_mode);
                    pop_env();  
                }else{
                    result = 1;
                }
                if(error){yyerror;YYABORT;}  //如果有錯就往回
            }

            delete $3; 
            delete $2; 
            $$ = result;
        }
        ;

Param   :  /* empty */ { $$ = new vector<double>(); }
        | Param Expression { $1->push_back($2); $$ = $1; }
        ;

ParamID : /* empty */ { $$=new vector<string>(); }
        | ParamID ID { $$=$1; $1->push_back(string($2)); }
        ;


%%

double recursive_parse_eval(const string &expr, int syntax_check=0) {
    ///// 儲存舊狀態
    double old_answer = answer;
    answer = 0; 
    int old_mode = syntax_only_mode;
    syntax_only_mode = syntax_check;
    int old_error = error;
    error = 0; 

    extern int paren_level;  //lex的
    extern int need_body;
    extern string body_buffer;

    int saved_paren_level = paren_level;
    int saved_need_body = need_body;
    string saved_body_buffer = body_buffer;
    paren_level = 0;     // 重置
    need_body = 0;       
    body_buffer.clear(); 
    /////

    YY_BUFFER_STATE old = push_lexer_buffer(expr.c_str());
    yyparse();     //開啟新的parser
    pop_lexer_buffer(old);

    if (error != 0) {//發生了錯誤
        error = 1;
        return 0;
    }
    // 恢復舊狀態
    double result = answer;
    answer = old_answer;
    syntax_only_mode = old_mode;
    paren_level = saved_paren_level;
    need_body = saved_need_body;
    body_buffer = saved_body_buffer;
    return result; 
}

void yyerror(const char *s){
    error=1;
    //fprintf(stderr,"%s\n",s);  
}

int main(){
    push_env(); //讓stack不是空的 (global)
    //cout<<fixed<<setprecision(0);
    yyparse();
    if(error){cout<<"syntax error\n";}
    return 0;
}