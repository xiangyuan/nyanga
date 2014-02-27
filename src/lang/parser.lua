--[=[
Copyright (C) 2013-2014 Richard Hundt and contributors.
See Copyright Notice in nyanga
]=]

local lpeg = require('lpeg')
local util = require('nyanga.lang.util')
local defs = require('nyanga.lang.tree')
local re   = require('nyanga.lang.re')
lpeg.setmaxstack(1024)

local patt = [=[
   chunk  <- {|
      s (<main_stmt> (<sep> s <main_stmt>)* <sep>?)? s (!. / %1 => error)
   |} -> chunk

   close    <- ']' =eq ']' / (<nl> / .) <close>

   lcomment <- "--" (!<nl> .)* <nl>
   bcomment <- ('--[' {:eq: '='* :} '[' <close>)
   comment  <- <bcomment> / <lcomment>
   idsafe   <- !(%alnum / "_")
   nl       <- %nl -> line
   s        <- (<comment> / <nl> / !%nl %s)*
   S        <- (<comment> / <nl> / !%nl %s)+
   ws       <- <nl> / %s
   hs       <- (!%nl %s)*
   HS       <- (!%nl %s)+
   digits   <- %digit (%digit / (&('_' %digit) '_') %digit)*
   word     <- (%alpha / "_") (%alnum / "_")*

   reserved <- (
      "local" / "function" / "nil" / "true" / "false" / "return" / "end"
      / "break" / "goto" / "not" / "do" / "for" / "in" / "and" / "or"
      / "while" / "repeat" / "until" / "if" / "elseif" / "else" / "then"
   ) <idsafe>

   keyword  <- (
      <reserved> / "class" / "module" / "static"
      / "continue" / "throw" / "of" / "super"
      / "import" / "export" / "try" / "catch" / "finally"
      / "is" / "as" / "include" / "grammar" / "given" / "case"
   ) <idsafe>

   sep <- <bcomment>? (<nl> / ";" / <lcomment>) / <ws> <sep>?

   escape <- {~ ('\' (%digit^3 / .)) -> escape ~}

   astring <- "'" {~ (<escape> / <nl> / {!"'" .})* ~} "'"

   qstring <- {|
      '"' (
         <raw_expr> / {~ (<escape> / <nl> / !(<raw_expr> / '"') .)+ ~}
      )* '"'
   |} -> rawString

   raw_expr <- (
      "${" s <expr> s "}"
   ) -> rawExpr

   string  <- <astring>

   hexnum <- "-"? "0x" %xdigit+

   decexp <- ("e"/"E") "-"? <digits>

   decimal <- "-"? <digits> ("." <digits> <decexp>? / <decexp>)

   integer <- { "-"? <digits> ('LL'/'UL')? } -> integer

   octal   <- {~ { "-"? "0" [0-7]+ } -> octal ~}

   number  <- {~
      <hexnum> / <octal> / <decimal>
   ~} -> tonumber / <integer>

   boolean <- (
      {"true"/"false"} <idsafe>
   ) -> boolean

   literal <- ( <number> / <string> / <boolean> ) -> literal

   main_stmt <- (
      <export_stmt> / <stmt>
   )

   in  <- "in"  <idsafe>
   end <- "end" <idsafe>
   do  <- "do"  <idsafe>

   export_stmt <- (
      "export" <idsafe> s {| <ident_list> |}
   ) -> exportStmt

   import_stmt <- (
      "import" <idsafe> s {| <ident> (s "," s <ident>)* |} s
      "from" <idsafe> s <expr>
   ) -> importStmt

   stmt <- ({} (
      <import_stmt>
      / <if_stmt>
      / <while_stmt>
      / <repeat_stmt>
      / <for_stmt>
      / <for_in_stmt>
      / <do_stmt>
      / <decl_stmt>
      / <return_stmt>
      / <try_stmt>
      / <throw_stmt>
      / <break_stmt>
      / <continue_stmt>
      / <given_stmt>
      / <expr_stmt>
   )) -> stmt

   stmt_list <- {|
      (<stmt> (<sep> s <stmt>)* <sep>?)?
   |}

   break_stmt <- (
      "break" <idsafe>
   ) -> breakStmt

   continue_stmt <- (
      "continue" <idsafe>
   ) -> continueStmt

   return_stmt <- (
      "return" <idsafe> {| (hs <expr_list>)? |}
   ) -> returnStmt

   throw_stmt <- (
      "throw" <idsafe> hs <expr>
   ) -> throwStmt

   try_stmt <- (
      "try" <idsafe> s <block_stmt>
      {| <catch_clause>* |} (s "finally" <idsafe> s <block_stmt>)?
      s <end>
   ) -> tryStmt

   catch_clause <- (
      s "catch" <idsafe> s "(" s
      <ident> (s "if" <idsafe> s <expr>)? s ")" s <block_stmt> s
   ) -> catchClause

   decl_stmt <- (
        <local_coro>
      / <local_func>
      / <local_decl>
      / <coro_decl>
      / <func_decl>
      / <class_decl>
      / <module_decl>
      / <grammar_decl>
   )

   local_decl <- (
      "local" <idsafe> s {| <decl_left> (s "," s <decl_left>)* |}
      (s "=" s {| <expr_list> |})?
   ) -> localDecl

   local_func <- (
      "local" <idsafe> s
      "function" <idsafe> s <ident> s <func_head> s <func_body>
   ) -> localFuncDecl

   local_coro <- (
      "local" <idsafe> s
      "function*" <idsafe> s <ident> s <func_head> s <func_body>
   ) -> localCoroDecl

   bind_left <- (
      <array_patt> / <table_patt> / <apply_patt> / <member_expr>
   )
   decl_left <- (
      <array_patt_decl> / <table_patt_decl> / <apply_patt_decl> / <ident>
   )

   array_patt <- (
      "[" s {| <bind_left> (s "," s <bind_left>)* |} s "]"
   ) -> arrayPatt

   array_patt_decl <- (
      "[" s {| <decl_left> (s "," s <decl_left>)* |} s "]"
   ) -> arrayPatt

   table_sep <- (
      hs (","/";"/<nl>)
   )
   table_patt <- (
      "{" s {|
         <table_patt_pair> (<table_sep> s <table_patt_pair>)*
         <table_sep>?
      |} s "}"
      (hs "as" <idsafe> hs <expr>)?
   ) -> tablePatt

   table_patt_decl <- (
      "{" s {|
         <table_patt_pair_decl> (<table_sep> s <table_patt_pair_decl>)*
         <table_sep>?
      |} s "}"
      (hs "as" <idsafe> hs <expr>)?
   ) -> tablePatt

   table_patt_pair <- {|
      ( {:name: <name> :} / {:expr: "[" s <expr> s "]" :} ) s
      "=" s {:value: <bind_left> :}
      / {:value: <bind_left> :}
   |}

   table_patt_pair_decl <- {|
      ( {:name: <name> :} / {:expr: "[" s <expr> s "]" :} ) s
      "=" s {:value: <decl_left> :}
      / {:value: <decl_left> :}
   |}

   apply_patt <- {|
      <term> <apply_tail>* <apply_call>
   |} -> applyPatt

   apply_patt_decl <- {|
      <term> <apply_tail>* <apply_call_decl>
   |} -> applyPatt

   apply_tail <- {|
        s { "." } s <ident>
      / s { "::" } s (<ident> / %1 => error)
      / s { "[" } s <expr> s ("]" / %1 => error)
   |}

   apply_call <- {|
      { "(" } s {| <bind_left> (s "," s <bind_left>)* |} s ")"
   |}
   apply_call_decl <- {|
      { "(" } s {| <decl_left> (s "," s <decl_left>)* |} s ")"
   |}

   ident_list <- (
      <ident> (s "," s <ident>)*
   )

   expr_list <- (
      <expr> (s "," s <expr>)*
   )

   func_path <- (
      (<ident> (s {"."} s <func_path> / s {"::"} s <ident>)) / <ident>
   )

   func_decl <- (
      "function" <idsafe> s {| <func_path> |} s <func_head> s <func_body>
   ) -> funcDecl

   func_head <- (
      "(" s {| <param_list>? |} s ")"
   )

   func_expr <- (
      "function" <idsafe> s <func_head> s <func_body>
      / (<func_head> / {| |}) s "=>" (hs <expr> / s <block_stmt> s <end> / %1 => error)
   ) -> funcExpr

   func_body <- <block_stmt> s (<end> / %1 => error)

   coro_expr <- (
      "function*" s <func_head> s <func_body>
      / "*" <func_head> s "=>" s (hs <expr> / <block_stmt> s <end> / %1 => error)
   ) -> coroExpr

   coro_decl <- (
      "function*" s {| <func_path> |} s <func_head> s <func_body>
   ) -> coroDecl

   coro_prop <- (
      ({"get"/"set"} <idsafe> HS &<ident> / '' -> "init") "*" <ident> s
      <func_head> s <func_body>
   ) -> coroProp

   include_stmt <- (
      "include" <idsafe> s {| <expr_list> |}
   ) -> includeStmt

   module_decl <- (
      "module" <idsafe> s <ident> s
      <class_body> s
      (<end> / %1 => error)
   ) -> moduleDecl

   class_decl <- (
      "class" <idsafe> s <ident> (s <class_heritage>)? s
      <class_body> s
      (<end> / %1 => error)
   ) -> classDecl

   class_body <- {|
      (<class_body_stmt> (<sep> s <class_body_stmt>)* <sep>?)?
   |} -> classBody

   class_body_stmt <- ({} (
      <class_member> / <include_stmt> / !<return_stmt> <stmt>
   )) -> stmt

   class_member <- (
      ({"static"} <idsafe> s / '' -> "virt") (<coro_prop> / <prop_defn>)
   ) -> classMember

   class_heritage <- (
      "extends" <idsafe> s <expr> / {| |}
   )

   prop_defn <- (
      ({"get"/"set"} <idsafe> HS &<ident> / '' -> "init") <ident> s
      <func_head> s <func_body>
   ) -> propDefn

   param <- {|
      {:name: <ident> :} (s "=" s {:default: <expr> :})?
   |}
   param_list <- (
        <param> s "," s <param_list>
      / <param> s "," s <param_rest>
      / <param>
      / <param_rest>
   )

   param_rest <- {| "..." {:name: <ident>? :} {:rest: '' -> 'true' :} |}

   block_stmt <- (
      {| (<stmt> (<sep> s <stmt>)* <sep>?)? |}
   ) -> blockStmt

   if_stmt <- (
      "if" <idsafe> s <expr> s "then" <idsafe> s <block_stmt> s (
           "else" <if_stmt>
         / "else" <idsafe> s <block_stmt> s (<end> / %1 => error)
         / (<end> / %1 => error)
      )
   ) -> ifStmt

   given_stmt <- (
      "given" <idsafe> s <expr>
         {| <given_case>+ |}
         (s "else" <idsafe> s <block_stmt>)? s
      (<end> / %1 => error)
   ) -> givenStmt

   given_case <- (
      s "case" <idsafe> s <bind_left> s "then" <idsafe> s <block_stmt>
   ) -> givenCase

   for_stmt <- (
      "for" <idsafe> s <ident> s "=" s <expr> s "," s <expr>
      (s "," s <expr> / ('' -> '1') -> literalNumber) s
      <loop_body>
   ) -> forStmt

   for_in_stmt <- (
      "for" <idsafe> s {| <ident_list> |} s <in> s <expr> s
      <loop_body>
   ) -> forInStmt

   loop_body <- <do> s <block_stmt> s <end>

   do_stmt <- <loop_body> -> doStmt

   while_stmt <- (
      "while" <idsafe> s <expr> s <loop_body>
   ) -> whileStmt

   repeat_stmt <- (
      "repeat" <idsafe> s <block_stmt> s "until" <idsafe> s <expr>
   ) -> repeatStmt

   ident <- (
      !<keyword> { <word> }
   ) -> identifier

   name <- (
      !<reserved> { <word> }
   ) -> identifier

   term <- ({} (
        <coro_expr>
      / <func_expr>
      / <nil_expr>
      / <super_expr>
      / <comp_expr>
      / <table_expr>
      / <array_expr>
      / <regex_expr>
      / <ident>
      / <literal>
      / <qstring>
      / "(" s <expr> s ")"
   )) -> term

   expr <- ({} (<infix_expr> / <spread_expr>)) -> expr

   spread_expr <- (
      "..." <postfix_expr>?
   ) -> spreadExpr

   nil_expr <- (
      "nil" <idsafe>
   ) -> nilExpr

   super_expr <- (
      "super" <idsafe>
   ) -> superExpr

   expr_stmt <- (
      {} (<assign_expr> / <update_expr> / <postfix_expr> / <ident>)
   ) -> exprStmt

   binop <- {
      "+" / "-" / "~" / "/" / "**" / "*" / "%" / "^" / "|" / "&"
      / ">>>" / ">>" / ">=" / ">" / "<<" / "<=" / "<" / ".."
      / "!=" / "==" / ("or" / "and" / "is" / "as") <idsafe>
   }

   infix_expr  <- (
      {| <prefix_expr> (s <binop> s <prefix_expr>)+ |}
   ) -> infixExpr / <prefix_expr>

   prefix_expr <- (
      { "#" / "-" !('-' / <number>) <idsafe> } s <postfix_expr>
      / { "~" / "!" / "not" <idsafe> } s <prefix_expr>
   ) -> prefixExpr / <postfix_expr>

   postfix_expr <- {|
      <term> <postfix_tail>+
   |} -> postfixExpr / <term>

   postfix_tail <- {|
        s { "." } s <name>
      / s { "::" } s (<name> / %1 => error)
      / hs { "[" } s <expr> s ("]" / %1 => error)
      / { "(" } s {| <expr_list>? |} s (")" / %1 => error)
      / {~ (hs &['"[{] / HS) -> "(" ~} {| <spread_expr> / !<binop> <expr_list> |}
   |}

   member_expr <- {|
      <term> <member_next>?
   |} -> postfixExpr / <term>

   member_next <- (
      <postfix_tail> <member_next> / <member_tail>
   )
   member_tail <- {|
        s { "." } s <name>
      / s { "::" } s <name>
      / s { "[" } s <expr> s ("]" / %1 => error)
   |}

   assop <- {
      "+=" / "-=" / "~=" / "**=" / "*=" / "/=" / "%=" / "and="
      / "|=" / "or=" / "&=" / "^=" / "<<=" / ">>>=" / ">>="
   }

   assign_expr <- (
      {| <bind_left> (s "," s <bind_left>)* |} s "=" s {| <expr_list> |}
   ) -> assignExpr

   update_expr <- (
      <bind_left> s <assop> s <expr>
   ) -> updateExpr

   array_expr <- (
      "[" s {| <array_elements>? |} s "]"
   ) -> arrayExpr

   array_elements <- <expr> (s "," s <expr>)* (s ",")?

   table_expr <- (
      "{" s {| <table_entries>? |} s "}"
   ) -> tableExpr

   table_entries <- (
      <table_entry> (<table_sep> s <table_entry>)* <table_sep>?
   )
   table_entry <- {|
      ( {:name: <name> :} / {:expr: "[" s <expr> s "]" :} ) s
      "=" s {:value: <expr> :}
      / {:value: <expr> :}
   |} -> tableEntry

   comp_expr <- (
      "[" s <expr> {| (s <comp_block>)+ |} s "]"
   ) -> compExpr

   comp_block <- (
      "for" <idsafe> s {| <ident_list> |} s <in> s <expr>
      (s "if" <idsafe> s <expr>)? s
   ) -> compBlock

   regex_expr <- (
      "/" s <patt_expr> s ("/" / %s => error)
   ) -> regexExpr

   grammar_decl <- (
      "grammar" <idsafe> HS <ident> (s <grammar_body>)? s
      (<end> / %1 => error)
   ) -> grammarDecl

   grammar_body <- <patt_expr>

   patt_expr <- (<patt_grammar> / <patt_alt>) -> pattExpr

   patt_grammar <- {|
      <patt_decl> (s <patt_decl>)*
   |} -> pattGrammar

   patt_decl <- (
      <patt_name> s '<-' s <patt_expr>
   )

   patt_sep <- '|' !'}'
   patt_alt <- {|
      <patt_seq> (s <patt_sep> s <patt_seq>)*
   |} -> pattAlt

   patt_seq <- {|
      (<patt_prefix> (s <patt_prefix>)*)?
   |} -> pattSeq

   patt_any <- '.' -> pattAny

   patt_prefix <- (
      <patt_assert> / <patt_suffix>
   )

   patt_assert  <- (
      {'&' / '!' } s <patt_prefix>
   ) -> pattAssert

   patt_suffix <- (
      <patt_primary> {| (s <patt_tail>)* |}
   ) -> pattSuffix

   patt_tail <- (
      <patt_opt> / <patt_rep> / <patt_prod>
   )

   patt_prod <- (
        {'~>'} s <postfix_expr>
      / {'->'} s <postfix_expr>
      / {'+>'} s <postfix_expr>
   ) -> pattProd

   patt_opt <- (
      !'+>' { [+*?] }
   ) -> pattOpt

   patt_rep <- (
      '^' { [+-]? <patt_num> }
   ) -> pattRep

   patt_capt <- (
        <patt_capt_subst>
      / <patt_capt_const>
      / <patt_capt_group>
      / <patt_capt_table>
      / <patt_capt_basic>
      / <patt_capt_back>
   )

   patt_capt_subst <- (
      '{~' s <patt_expr> s '~}'
   ) -> pattCaptSubst

   patt_capt_group <- (
      '{:' (<patt_name> ':')? s <patt_expr> s ':}'
   ) -> pattCaptGroup

   patt_capt_table <- (
      '{|' s <patt_expr> s '|}'
   ) -> pattCaptTable

   patt_capt_basic <- (
      '{' s <patt_expr> s '}'
   ) -> pattCaptBasic

   patt_capt_const <- (
      '{`'  s <expr> s '`}'
   ) -> pattCaptConst

   patt_capt_back <- (
      '=' <patt_name>
   ) -> pattCaptBack

   patt_primary  <- (
      '(' s <patt_expr> s ')'
      / <patt_term>
      / <patt_class>
      / <patt_predef>
      / <patt_capt>
      / <patt_arg>
      / <patt_any>
      / <patt_ref>
      / '<{' s <expr> s '}>'
   )

   patt_ref <- (
      '<' <patt_name> '>'
      / !<keyword> <patt_name> !(s '<-')
   ) -> pattRef

   patt_arg <- (
      '%' { <patt_num> }
   ) -> pattArg

   patt_class <- (
      '[' {'^' / ''} {| <patt_item> (!']' <patt_item>)* |} ']'
   ) -> pattClass

   patt_item <- (
      <patt_predef> / <patt_range> / ({ . } -> pattTerm)
   )

   patt_range   <- ({ . } '-' { [^]] }) -> pattRange
   patt_name    <- { [A-Za-z_][A-Za-z0-9_]* } -> pattName
   patt_num     <- [0-9]+
   patt_term    <- ('"' { [^"]* } '"' / "'" { [^']* } "'") -> pattTerm
   patt_predef  <- '%' <patt_name> -> pattPredef
]=]

local grammar = re.compile(patt, defs)
local function parse(src, ...)
   return grammar:match(src, nil, ...)
end

return {
   parse = parse
}


