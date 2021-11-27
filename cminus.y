/****************************************************/
/* File: tiny.y                                     */
/* The TINY Yacc/Bison specification file           */
/* Compiler Construction: Principles and Practice   */
/* Kenneth C. Louden                                */
/****************************************************/
%{
#define YYPARSER /* distinguishes Yacc output from other code files */

#include "globals.h"
#include "util.h"
#include "scan.h"
#include "parse.h"

#define YYSTYPE TreeNode *
static char * savedName; /* for use in assignments */
static int savedLineNo;  /* ditto */
static int savedNumber;
static int savedType; // Type 저장 위해 추가
static TreeNode * savedTree; /* stores syntax tree for later return */
static int yylex(void); // added 11/2/11 to ensure no conflict with lex

%}

%token IF ELSE UNTIL RETURN WHILE ENDIF
%token ID NUM 
%token ASSIGN EQ LT GE GT LE NE PLUS MINUS TIMES OVER
%token LPAREN RPAREN LBRACE RBRACE LCURLY RCURLY SEMI COMMA
%token ERROR 

%token INT VOID

%nonassoc ENDIF
%nonassoc ELSE

%% /* Grammar for TINY */

program     : stmt_seq
                 { savedTree = $1;} 
            ;
stmt_seq    : stmt_seq stmt
                 { YYSTYPE t = $1;
                   if (t != NULL)
                   { while (t->sibling != NULL)
                        t = t->sibling;
                     t->sibling = $2;
                     $$ = $1; }
                     else $$ = $2;
                 }
            | stmt  { $$ = $1; }
            ;
stmt        : var_declaration { $$ = $1; }
            | fun_declaration { $$ = $1; }
            | error  { $$ = NULL; }
            ;

type_specifier  : INT { savedType = INT; }
                | VOID { savedType = VOID; }
            ;

sub_stmt    : compound_stmt { $$ = $1; }
            | selection_stmt { $$ = $1; }
            | iteration_stmt { $$ = $1; }
            | return_stmt { $$ = $1; }
            | exp_stmt { $$ = $1; }
            ;

var_declaration : type_specifier id SEMI
                  { $$ = newStmtNode(VariableK);
                    $$->attr.name = savedName;
                    $$->typename = savedType;
                  }
                | type_specifier id LCURLY num
                  RCURLY SEMI
                  { $$ = newStmtNode(ArrayK);
                    $$->child[0] = $4;
                    $$->attr.name = savedName;
                    $$->typename = savedType;
                  }
                ;

fun_declaration : type_specifier id { $$ = newStmtNode(FunctionK); $$->attr.name = savedName; $$->typename = savedType; }
                  LPAREN params RPAREN compound_stmt
                  { $$ = $3;
                    $$->child[0] = $5;
                    $$->child[1] = $7;
                  }
                ;

params      : param_all { $$ = $1; }
            | VOID { $$ = newStmtNode(VoidParameterK); $$->typename = VOID; }
            ;

param_all   : param_all COMMA param_single
              { YYSTYPE t = $1;
                if (t != NULL)
                { while (t->sibling != NULL)
                    t = t->sibling;
                  t->sibling = $3;
                  $$ = $1; }
                  else $$ = $3;
              }
            | param_single { $$ = $1; }
            ;

param_single  : type_specifier id
                { $$ = newStmtNode(ParameterK);
                  $$->attr.name = savedName;
                  $$->typename = savedType;
                }
              ;

compound_stmt : LBRACE local_declarations statement_list RBRACE
                { $$ = newStmtNode(CompoundK);
                  $$->child[0] = $2;
                  $$->child[1] = $3;
                }
              ;

local_declarations  : local_declarations var_declaration
                      { YYSTYPE t = $1;
                        if (t != NULL)
                        { while (t->sibling != NULL)
                              t = t->sibling;
                          t->sibling = $2;
                          $$ = $1; }
                          else $$ = $2;
                      }
                    | { $$ = NULL; } /* 없는 경우 */
                    ;

statement_list  : statement_list sub_stmt
                  { YYSTYPE t = $1;
                    if (t != NULL)
                    { while (t->sibling != NULL)
                          t = t->sibling;
                      t->sibling = $2;
                      $$ = $1; }
                      else $$ = $2;
                  }
                | { $$ = NULL; } /* 없는 경우 */
                ;

selection_stmt  : IF LPAREN exp RPAREN sub_stmt %prec ENDIF
                  { $$ = newStmtNode(IfK);
                    $$->child[0] = $3;
                    $$->child[1] = $5;
                  }
                | IF LPAREN exp RPAREN sub_stmt ELSE sub_stmt
                  { $$ = newStmtNode(IfelseK);
                    $$->child[0] = $3;
                    $$->child[1] = $5;
                    $$->child[2] = $7;
                  }
                ;

iteration_stmt  : WHILE LPAREN exp RPAREN sub_stmt
                  { $$ = newStmtNode(WhileK);
                    $$->child[0] = $3;
                    $$->child[1] = $5;
                  }
                ;

return_stmt : RETURN SEMI
              { $$ = newStmtNode(ReturnK);
                $$->child[0] = NULL;
              }
            | RETURN exp SEMI
              { $$ = newStmtNode(ReturnK);
                $$->child[0] = $2;
              }
            ;

exp_stmt    : var_exp SEMI { $$ = $1; } /* a=3이 단독으로 쓰일 경우 ;가 뒤에 붙어야한다 */

id          : ID
              { $$ = newExpNode(IdK);
                savedName = copyString(tokenString);
                $$->attr.name = savedName; }
            ;

num         : NUM
              { $$ = newExpNode(ConstK);
                savedNumber = atoi(tokenString);
                $$->attr.val = savedNumber; }
            ;

var_exp     : var ASSIGN var_exp
              { $$ = newStmtNode(AssignK);
                $$->child[0] = $1;
                $$->child[1] = $3;
              }
            | exp { $$ = $1; }
            ;

var         : id { $$ = $1; }
            | id { $$ = $1; }
              LCURLY exp RCURLY
              { $$ = $2;
                $$->child[0] = $4;
              }
            ;

exp         : simple_exp LT simple_exp 
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = LT;
                 }
            | simple_exp EQ simple_exp
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = EQ;
                 }
            | simple_exp NE simple_exp
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = NE;
                 }
            | simple_exp LE simple_exp
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = LE;
                 }
            | simple_exp GT simple_exp
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = GT;
                 }
            | simple_exp GE simple_exp
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = GE;
                 }
            | simple_exp { $$ = $1; }
            ;
simple_exp  : simple_exp PLUS term 
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = PLUS;
                 }
            | simple_exp MINUS term
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = MINUS;
                 } 
            | term { $$ = $1; }
            ;
term        : term TIMES factor 
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = TIMES;
                 }
            | term OVER factor
                 { $$ = newExpNode(OpK);
                   $$->child[0] = $1;
                   $$->child[1] = $3;
                   $$->attr.op = OVER;
                 }
            | factor { $$ = $1; }
            ;
factor      : LPAREN exp RPAREN
                 { $$ = $2; }
            | var { $$ = $1; }
            | num { $$ = $1; }
            | call { $$ = $1; }
            | error { $$ = NULL; }
            ;

call        : id
              { $$ = newStmtNode(CallK);
                $$->attr.name = savedName;
              }
              LPAREN args RPAREN
              { $$ = $2;
                $$->child[0] = $4;
              }
            ;

args      : arg_all { $$ = $1; }
            | { $$ = NULL; } /* params과 달리 args에서는 void 대신 () 사용 */
            ;

arg_all   : arg_all COMMA arg_single
              { YYSTYPE t = $1;
                if (t != NULL)
                { while (t->sibling != NULL)
                    t = t->sibling;
                  t->sibling = $3;
                  $$ = $1; }
                  else $$ = $3;
              }
            | arg_single { $$ = $1; }
            ;

arg_single  : exp { $$ = $1; }
            ;

%%

int yyerror(char * message)
{ fprintf(listing,"Syntax error at line %d: %s\n",lineno,message);
  fprintf(listing,"Current token: ");
  printToken(yychar,tokenString);
  Error = TRUE;
  return 0;
}

/* yylex calls getToken to make Yacc/Bison output
 * compatible with ealier versions of the TINY scanner
 */
static int yylex(void)
{ return getToken(); }

TreeNode * parse(void)
{ yyparse();
  return savedTree;
}

