(* Copyright (c) 2013, The Trustees of the University of Pennsylvania
   All rights reserved.

   LICENSE: 3-clause BSD style.
   See the LICENSE file for details on licensing.
*)
{
open Support.FileInfo
open Support.Error

let lex_error fi s = error_msg Support.Options.Lexer fi "%s" s

let reservedWords = [
  (* Symbols *)
  ("+", fun i -> Parser.ADD i);
  (":", fun i -> Parser.COLON i);
  (",", fun i -> Parser.COMMA i);
  ("=>", fun i -> Parser.DBLARROW i);
  ("=", fun i -> Parser.EQUAL i);
  (";", fun i -> Parser.SEMI i);
  ("{", fun i -> Parser.LBRACE i);
  ("}", fun i -> Parser.RBRACE i);
  ("(", fun i -> Parser.LPAREN i);
  (")", fun i -> Parser.RPAREN i);
  ("|", fun i -> Parser.PIPE i);
  ("`", fun i -> Parser.TICK i);
  ("!", fun i -> Parser.BANG i);

  (* Keywords *)
  ("dmul", fun i -> Parser.DMULOP i);
  ("add", fun i -> Parser.ADDOP i);
  ("mul", fun i -> Parser.MULOP i);
  ("sub", fun i -> Parser.SUBOP i);
  ("div", fun i -> Parser.DIVOP i);
  ("case", fun i -> Parser.UNIONCASE i);
  ("inl", fun i -> Parser.INL i);
  ("inr", fun i -> Parser.INR i);
  ("of", fun i -> Parser.OF i);
  ("dlet", fun i -> Parser.DLET i);
  ("let", fun i -> Parser.LET i);
  ("dnum", fun i -> Parser.DNUM i);
  ("num", fun i -> Parser.NUM i);
  ("bool", fun i -> Parser.BOOL i);
]

(* Support functions *)

type buildfun = info -> Parser.token
let (symbolTable : (string, buildfun) Hashtbl.t) = Hashtbl.create 1024
let _ =
  List.iter (fun (str, f) -> Hashtbl.add symbolTable str f) reservedWords

let createID i str =
  try (Hashtbl.find symbolTable str) i
  with _ -> Parser.ID {i = i; v = str}

let lineno = ref 1
and depth  = ref 0
and start  = ref 0

and filename = ref ""
and startLex = ref dummyinfo

let create inFile stream =
  if not (Filename.is_implicit inFile) then filename := inFile
  else filename := Filename.concat (Sys.getcwd()) inFile;
  lineno := 1; start := 0; Lexing.from_channel stream

let newline lexbuf = incr lineno; start := (Lexing.lexeme_start lexbuf)

let info lexbuf =
  createInfo (!filename) (!lineno) (Lexing.lexeme_start lexbuf - !start)

let text = Lexing.lexeme

let stringBuffer = ref (Bytes.create 2048)
let stringEnd = ref 0

let resetStr () = stringEnd := 0

let addStr ch =
  let x = !stringEnd in
  let buffer = !stringBuffer
in
  if x = Bytes.length buffer then
    begin
      let newBuffer = Bytes.create (x * 2) in
      Bytes.blit buffer 0 newBuffer 0 x;
      Bytes.set newBuffer x ch;
      stringBuffer := newBuffer;
      stringEnd := x + 1
    end
  else
    begin
      Bytes.set buffer x ch;
      stringEnd := x + 1
    end

let getStr () = Bytes.(to_string (sub (!stringBuffer) 0 (!stringEnd)))

let extractLineno yytext offset =
  int_of_string String.(sub yytext offset (length yytext - offset))
}

rule main = parse
  [' ' '\009' '\012'] + { main lexbuf }

| [' ' '\009' '\012'] * ("\r")?"\n" { newline lexbuf; main lexbuf }

| "*/" { lex_error (info lexbuf) "Unmatched end of comment" }

| "/*" { depth := 1; startLex := info lexbuf; comment lexbuf; main lexbuf }

| "//" [^ '\n'] * { main lexbuf }

| "# " ['0'-'9']+
    { lineno := extractLineno (text lexbuf) 2 - 1; getFile lexbuf }

| "# line " ['0'-'9']+
    { lineno := extractLineno (text lexbuf) 7 - 1; getFile lexbuf }

| ['0'-'9']+ '.' ['0'-'9']+
    { Parser.FLOATV {i = info lexbuf; v = float_of_string (text lexbuf)} }

| "inf" { Parser.INF (info lexbuf) }

| ['A'-'Z' 'a'-'z' '_']
  ['A'-'Z' 'a'-'z' '_' '0'-'9' '\''] *
    { createID (info lexbuf) (text lexbuf) }

| ":=" | "<:" | "<-" | "->" | "=>" | "==>"
| "{|" | "|}" | "<|" | "|>" | "[|" | "|]" | "=="
    { createID (info lexbuf) (text lexbuf) }

| ['~' '%' '\\' '+' '-' '&' '|' ':' '@' '`' '$'] +
    { createID (info lexbuf) (text lexbuf) }

| ['*' '#' '/' '!' '?' '^' '(' ')' '{' '}' '[' ']' '<' '>' '.' ';' '_' ',' '=' '\'']
    { createID (info lexbuf) (text lexbuf) }

| "\"" { resetStr(); startLex := info lexbuf; string lexbuf }

| eof { Parser.EOF (info lexbuf) }

| _  { lex_error (info lexbuf) "Illegal character" }

and comment = parse
  "/*"
    { depth := succ !depth; comment lexbuf }
| "*/"
    { depth := pred !depth; if !depth > 0 then comment lexbuf }
| eof
    { lex_error (!startLex) "Comment not terminated" }
| [^ '\n']
    { comment lexbuf }
| "\n"
    { newline lexbuf; comment lexbuf }

and getFile = parse
  " " * "\"" { getName lexbuf }

and getName = parse
  [^ '"' '\n'] + { filename := (text lexbuf); finishName lexbuf }

and finishName = parse
  '"' [^ '\n'] * { main lexbuf }

and string = parse
  '"'  { Parser.STRINGV {i = !startLex; v = getStr()} }
| '\\' { addStr(escaped lexbuf); string lexbuf }
| '\n' { addStr '\n'; newline lexbuf; string lexbuf }
| eof  { lex_error (!startLex) "String not terminated" }
| _    { addStr (Lexing.lexeme_char lexbuf 0); string lexbuf }

and escaped = parse
  'n'	 { '\n' }
| 't'	 { '\t' }
| '\\' { '\\' }
| '"'  { '\034' }
| '\'' { '\'' }
| ['0'-'9']['0'-'9']['0'-'9']
    {
      let x = int_of_string(text lexbuf) in
      if x > 255 then
	      lex_error (info lexbuf) "Illegal character constant"
      else
	      Char.chr x
    }
| [^ '"' '\\' 't' 'n' '\'']
    { lex_error (info lexbuf) "Illegal character constant" }
