/****************************************************/
/* File: scan.c                                     */
/* The scanner implementation for the TINY compiler */
/* Compiler Construction: Principles and Practice   */
/* Kenneth C. Louden                                */
/****************************************************/

#include "globals.h"
#include "util.h"
#include "scan.h"

/* states in scanner DFA */
typedef enum
   { START,INASSIGN,INCOMMENT,INNUM,INID,DONE,INEQ,INLT,INGT,INNE,INOVER,INCOMMENT_ }
   StateType;

/* lexeme of identifier or reserved word */
char tokenString[MAXTOKENLEN+1];

/* BUFLEN = length of the input buffer for
   source code lines */
#define BUFLEN 256

static char lineBuf[BUFLEN]; /* holds the current line */
static int linepos = 0; /* current position in LineBuf */
static int bufsize = 0; /* current size of buffer string */
static int EOF_flag = FALSE; /* corrects ungetNextChar behavior on EOF */

/* getNextChar fetches the next non-blank character
   from lineBuf, reading in a new line if lineBuf is
   exhausted */
static int getNextChar(void)
{ if (!(linepos < bufsize))
  { lineno++;
    if (fgets(lineBuf,BUFLEN-1,source))
    { if (EchoSource) fprintf(listing,"%4d: %s",lineno,lineBuf);
      bufsize = strlen(lineBuf);
      linepos = 0;
      return lineBuf[linepos++];
    }
    else
    { EOF_flag = TRUE;
      return EOF;
    }
  }
  else return lineBuf[linepos++];
}

/* ungetNextChar backtracks one character
   in lineBuf */
static void ungetNextChar(void)
{ if (!EOF_flag) linepos-- ;}

/* lookup table of reserved words */
static struct
    { char* str;
      TokenType tok;
    } reservedWords[MAXRESERVED]
   = {{"if",IF},{"else",ELSE},{"while",WHILE},
      {"return",RETURN},{"int",INT},
      {"void",VOID}};

/* lookup an identifier to see if it is a reserved word */
/* uses linear search */
static TokenType reservedLookup (char * s)
{ int i;
  for (i=0;i<MAXRESERVED;i++)
    if (!strcmp(s,reservedWords[i].str))
      return reservedWords[i].tok;
  return ID;
}

/****************************************/
/* the primary function of the scanner  */
/****************************************/
/* function getToken returns the 
 * next token in source file
 */
TokenType getToken(void)
{  /* index for storing into tokenString */
   int tokenStringIndex = 0;
   /* holds current token to be returned */
   TokenType currentToken;
   /* current state - always begins at START */
   StateType state = START;
   /* flag to indicate save to tokenString */
   int save;
   while (state != DONE)
   { int c = getNextChar();
     save = TRUE;
     switch (state)
     { case START:
         if (isdigit(c))
           state = INNUM;
         else if (isalpha(c))
           state = INID;
         else if ((c == ' ') || (c == '\t') || (c == '\n'))
           save = FALSE;

         // <=, >=, ==, !=, /* */ 에 대한 처리 
         else if (c == '<')
           state = INLT; // <인지 <=인지 구분 필요
         else if (c == '>')
           state = INGT; // >인지 >=인지 구분 필요
         else if (c == '=')
           state = INEQ; // =인지 ==인지 구분 필요
         else if (c == '!')
           state = INNE; // !=인지 잘못입력된 !인지 구분 필요
         else if (c == '/')
         { save = FALSE;
           state = INOVER; // /인지 /* */인지 구분 필요
         }
         else
         { state = DONE;
           switch (c)
           { case EOF:
               save = FALSE;
               currentToken = ENDFILE;
               break;
             // 기존에 있던 =, <, / 삭제 (새로 추가된 <= 등과 구분한 뒤 처리해야하기 때문)
             case '+':
               currentToken = PLUS;
               break;
             case '-':
               currentToken = MINUS;
               break;
             case '*':
               currentToken = TIMES;
               break;
             case '(':
               currentToken = LPAREN;
               break;
             case ')':
               currentToken = RPAREN;
               break;
             case ';':
               currentToken = SEMI;
               break;
             // C-Minus에서 사용하는 symbol 추가
             case '[':
               currentToken = LCURLY;
               break;
             case ']':
               currentToken = RCURLY;
               break;
             case '{':
               currentToken = LBRACE;
               break;
             case '}':
               currentToken = RBRACE;
               break;
             case ',':
               currentToken = COMMA;
               break;
             default:
               currentToken = ERROR;
               break;
           }
         }
         break;

       case INNUM:
         if (!isdigit(c))
         { /* backup in the input */
           ungetNextChar();
           save = FALSE;
           state = DONE;
           currentToken = NUM;
         }
         break;
       case INID:
         if (!isalpha(c))
         { /* backup in the input */
           ungetNextChar();
           save = FALSE;
           state = DONE;
           currentToken = ID;
         }
         break;
       // 추가되는 부분 (기존에 있던 case INASSIGN:과 유사한 구조로 작성)
       case INLT: // <인지 <=인지 구분
         state = DONE;
         if (c == '=')
           currentToken = LE;
         else
         {
           ungetNextChar();
           currentToken = LT;
         }
         break;
       case INGT: // >인지 >=인지 구분
         state = DONE;
         if (c == '=')
           currentToken = GE;
         else
         {
           ungetNextChar();
           currentToken = GT;
         }
         break;
       case INEQ: // =인지 ==인지 구분
         state = DONE;
         if (c == '=')
           currentToken = EQ;
         else
         {
           ungetNextChar();
           currentToken = ASSIGN;
         }
         break;
       case INNE: // !=인지 잘못입력된 !인지 구분
         state = DONE;
         if (c == '=')
           currentToken = NE;
         else
         {
           currentToken = ERROR;
         }
         break;
       case INOVER: // /인지 /* */인지 구분
         if (c == '*')
         {
           save = FALSE;
           state = INCOMMENT;
         }
         else
         {
           ungetNextChar();
           currentToken = OVER;
           state = DONE;
         }
         break;
       case INCOMMENT: // /* 안에 들어와있는 상태에서 *만났는지 확인 (기본 동작은 기존에 있던 case INCOMMENT:를 참고함)
         save = FALSE;
         if (c == EOF)
         {
           state = DONE;
           currentToken = ENDFILE;
         }
         else if (c == '*')
         {
           state = INCOMMENT_;
         }
         break;
       case INCOMMENT_: // /* 안에서 *만났을 때 뒤에 /까지 있어 주석이 끝나는지 확인
         save = FALSE;
         if (c == EOF)
         {
           state = DONE;
           currentToken = ENDFILE;
         }
         else if (c == '/')
         {
           state = START;
         }
         else // 그냥 주석 안에 *만 나온 경우
         {
           state = INCOMMENT;
         }
         break;
      
       case DONE:
       default: /* should never happen */
         fprintf(listing,"Scanner Bug: state= %d\n",state);
         state = DONE;
         currentToken = ERROR;
         break;
     }
     if ((save) && (tokenStringIndex <= MAXTOKENLEN))
       tokenString[tokenStringIndex++] = (char) c;
     if (state == DONE)
     { tokenString[tokenStringIndex] = '\0';
       if (currentToken == ID)
         currentToken = reservedLookup(tokenString);
     }
   }
   if (TraceScan) {
     fprintf(listing,"\t%d: ",lineno);
     printToken(currentToken,tokenString);
   }
   return currentToken;
} /* end getToken */

