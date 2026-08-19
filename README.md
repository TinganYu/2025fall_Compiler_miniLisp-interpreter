# Compiler Final Project - miniLisp

---使用 Lex 與 Yacc 實作的簡單直譯器---

## 使用環境

- OS: Linux Ubuntu 64-bit
- Tools: Flex、Bison (Yacc)、g++

## 功能

1. 可宣告變數與函式：`define func/var`
2. 可以輸出 `print-num`、`print-bool`
3. 四則運算與邏輯運算（numerical & logical）
4. 支援條件判斷 `if-then-else`
5. 可以呼叫 anonymous function
6. 可以定義、呼叫 named function
7. 支援 recursive function call
8. 會輸出 syntax error

## Lex

### 狀態 State

1. `INITIAL`：主要根據 Bison 的 token 規則回傳值，例如 `ID`、`NUM`、`+`、`-`、`*`、`/` 等。
2. `PARAM`：用來蒐集 function 的 parameters，直到括號配對完成。
3. `BODY`：用於蒐集 `if` 以及 function 的內容，並回傳 `BODY_STR`，供之後的 recursive parser 使用。

### Buffer Control

1. `push_lexer_buffer`：儲存目前的 Lex buffer，並匯入新的 string buffer 給 Lex。
2. `pop_lexer_buffer`：刪除目前的 Lex buffer，並恢復原本的 buffer。

## Yacc

### Symbol Table

1. `func_table`：儲存所有函式。
2. `env_stack`：模擬 Function Call Stack，儲存變數與其作用域（scope）。

### Buffer Control

執行函式時，先 push 新的 environment，接著執行
`recursive_parse_eval`，結束後再 pop 該 environment。

`recursive_parse_eval` 使用 **push_lexer_buffer** 與 **pop_lexer_buffer**
控制 Lexer 的輸入流，實現字串輸入的動態分析，同時重新開啟 parser。

### 程式邏輯

前面的 print、四則運算與邏輯運算基本上沒有特別的地方，直接執行。

`define` 會先檢查是否有重複定義。比較特別的是，定義函式時需要先存入
ID placeholder，這樣後面檢查函式內容時，如果裡面有 recursive call，才不會
發生 `function not defined` 的錯誤。

比較複雜的部分是 `if` 以及 Function。為了避免 Expression 馬上執行，程式
會先用 `BODY_STR` 蒐集內容，等到實際要使用的時候（例如 function call，或是
知道 `if` 的 test case 結果後），再呼叫 `recursive_parse_eval` 進入新的 parser，
讓 Lex 重新讀取 body 內的程式。`if` 使用這種方式，也可以避免未被選中的分支
被執行，並支援 recursive function call。

Function Call 會先檢查 function 是否存在以及 argument 數量是否正確，接著
bind parameter with argument value，最後使用 `recursive_parse_eval` 實際執行
函式結果。

我額外增加 `syntax_only_mode`，是因為希望在 define 的時候，先檢查 `funcEXP`
的 body 內容是否正確，避免函式後來沒有被呼叫時，錯誤一直沒有被發現。為了
避免在這個情況下產生任何輸出，syntax-only 模式只進行語法檢查。

任何 `recursive_parse_eval` 中檢查出的錯誤，都會將 `error` 設為 1，並立即
使用 `YYABORT` 結束程式。

此外，透過 `function.h` 定義跨模組共享的資料結構：

- `Function` 結構：
  - `vector<string> parameters`：紀錄參數清單。
  - `string body`：以字串形式保存函式主體，用來之後進行延遲解析與執行。

## 如何編譯

```bash
bison -d -o y.tab.c final.y
g++ -c -g -I.. y.tab.c
flex -o lex.yy.c final.l
g++ -c -g -I.. lex.yy.c
g++ -o final y.tab.o lex.yy.o -ll
```

如果系統使用 Flex 提供的 `libfl`，也可以將最後一行的 `-ll` 改成 `-lfl`。

## 如何執行

```bash
./final < input.txt
```

## 檔案說明

- `final.l`：Lex lexer 原始碼。
- `final.y`：Yacc parser 與直譯器原始碼。
- `function.h`：跨模組共享的 `Function` 結構。
- `input.txt`：範例輸入。

`lex.yy.c`、`y.tab.c`、`y.tab.h`、`.o` 檔案與 `final` 執行檔都是可以由
原始碼重新產生的建置檔，因此不需要放進 GitHub；`.gitignore` 會避免它們
被誤提交。
