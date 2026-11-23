; Only rewrite constructs with an explicit layout below. Keep other statements
; and expressions opaque so token adjacency and ASI-sensitive gaps survive.
; Tree-sitter can split a line-broken await into a contextual identifier
; and a separate statement. Do not insert a semicolon at that boundary.
((program) @leaf @keep_whitespace
  (#match? @leaf "\\bawait[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]"))
; The HTML host only injects the opaque line-comment case. Rebase that
; case for embedding, not standalone programs with byte-sensitive lines.
((program) @multi_line_indent_all
  (#match? @multi_line_indent_all "//")
  (#not-match? @multi_line_indent_all "/\\*|`|\\\\[\r\n]"))
(([(program) (statement_block)]
    (_) @leaf @multi_line_indent_all)
   (#not-match? @leaf "^(const[ \t\r\n]|let[ \t\r\n]|var[ \t\r\n]|import[ \t{'\"*]|export[ \t]*[{*]|(async[ \t]+)?function[* \t\r\n]|class[ \t\r\n{]|return[; \t\r\n]|throw[ \t\r\n]|(break|continue|debugger)([; \t\r\n]|$)|(if|else[ \t\r\n]+if|while|catch|switch)[ \t\r\n]*\\(|(else|do|try|catch|finally)[ \t\r\n]*\\{|[A-Za-z_$][A-Za-z0-9_$]*([.(]|[ \t\r\n]*:[ \t\r\n]*(?:\\{|while[ \t\r\n]*\\(|do[ \t\r\n]*\\{))|//|/\\*)")
   (#not-match? @leaf "^(?:[A-Za-z_$][A-Za-z0-9_$]*[ \t\r\n]*:[ \t\r\n]*)?for(?:[\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]+await)?[\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]*\\("))

[(string) (regex) (template_string)] @leaf
(lexical_declaration ["const" "let"] @append_space)
(variable_declaration "var" @append_space)
(variable_declarator "=" @prepend_space @append_space)
; An unparenthesized opening brace in statement position starts a block in
; ECMAScript even when the CST classifies it as an object expression.
((expression_statement) @append_delimiter
  (#not-match? @append_delimiter ";$|^let$|(?s:^\\{.*\\}\\z)")
  (#not-match? @append_delimiter "(?s:\\basync[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}][\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]*function\\b.*\\}\\z)")
  (#delimiter! ";"))
; The same block may be classified as a return operand across a line break.
((return_statement) @append_delimiter
  (#not-match? @append_delimiter ";$|(?s:^return[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}][\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]*\\{.*\\}\\z)")
  (#not-match? @append_delimiter "(?s:\\basync[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}][\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]*function\\b.*\\}\\z)")
  (#delimiter! ";"))

; Add separators on the next statement, after any preceding inserted `;`.

(function_declaration "function" @append_space (statement_block) @prepend_space)
(function_declaration "async" @append_space)
[(function_expression "function" @append_space (statement_block) @prepend_space)
 (function_expression "async" @append_space)]
[(generator_function "*" @append_space body: (statement_block) @prepend_space)
 (generator_function_declaration "*" @append_space body: (statement_block) @prepend_space)
 (generator_function "async" @append_space)
 (generator_function_declaration "async" @append_space)]
; A line break can make `async` a separate identifier rather than a
; function modifier, even if the CST attaches it to the function.
([(function_declaration) (function_expression) (generator_function_declaration) (generator_function)] @leaf
  (#match? @leaf "^async[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]"))
([(function_declaration) (function_expression) (generator_function_declaration) (generator_function)] @multi_line_indent_all
  (#match? @multi_line_indent_all "^async[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
(return_statement "return" @append_space (_))
; The CST may attach an expression across a line terminator, but JavaScript
; inserts a semicolon after `return` there. Keep that gap even if the CST
; calls the following expression an operand.
((return_statement) @leaf
  (#match? @leaf "^return[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]"))
((return_statement) @multi_line_indent_all
  (#match? @multi_line_indent_all "^return[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
; Throw requires its operand on the same line. Keep the operand opaque and
; leave any line-break form accepted by the parser unchanged.
((throw_statement) @leaf
  (#not-match? @leaf "^throw[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[^\\s\\x{FEFF}]"))
((throw_statement) @multi_line_indent_all
  (#not-match? @multi_line_indent_all "^throw[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[^\\s\\x{FEFF}]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
(throw_statement "throw" @append_space (_) @leaf)
; The operand is already opaque, so it must protect any nested JSX itself.
((throw_statement "throw" (_) @multi_line_indent_all)
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
((throw_statement) @append_delimiter
  (#not-match? @append_delimiter ";$")
  (#not-match? @append_delimiter "(?s:\\basync[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}][\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]*function\\b.*\\}\\z)")
  (#delimiter! ";"))
(statement_block "{" @append_hardline @append_indent_start (_) "}" @prepend_indent_end @prepend_hardline)

[(arguments "," @append_space (_))
 (formal_parameters "," @append_space (_))
 (array "," @append_space)
 (object "," @append_space)
 (lexical_declaration "," @append_space)
 (variable_declaration "," @append_space)]
; These argument nodes cannot emit their own line breaks. Remove the final
; comma even when the input was split across lines, so pass two is unchanged.
((arguments
  . ([(identifier) (string) (number) (true) (false) (null) (undefined) (this) (regex)] ",")*
  . [(identifier) (string) (number) (true) (false) (null) (undefined) (this) (regex)]
  . "," @delete . ")") @keep_whitespace
  (#not-match? @keep_whitespace "^\\(\\s*,|,\\s*,"))
; Use separate patterns for multiple and single identifiers: an anchored
; repeated group does not match the empty prefix of a one-parameter list.
(object "{" @append_space (_) "}" @prepend_space)
(pair ":" @append_space)
(assignment_expression "=" @prepend_space @append_space)
(augmented_assignment_expression operator: _ @prepend_space @append_space)
(binary_expression operator: _ @prepend_space @append_space)
; A line terminator can separate `async` from an ordinary arrow expression.
; Do not rejoin it, or turn a line break before `=>` into valid syntax.
((arrow_function) @leaf
  (#match? @leaf "^async[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]|[\r\n\\x{2028}\\x{2029}][\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]*=>"))
((arrow_function) @multi_line_indent_all
  (#match? @multi_line_indent_all "^async[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]|[\r\n\\x{2028}\\x{2029}][\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]*=>")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
(arrow_function "=>" @prepend_space @append_space)
(arrow_function "async" @append_space)
((arrow_function parameter: (identifier) @prepend_delimiter)
  (#delimiter! "("))
((arrow_function parameter: (identifier) @append_delimiter)
  (#delimiter! ")"))
(ternary_expression ["?" ":"] @prepend_space @append_space)
; Leave missing argument lists as authored. Inserting `()` at a statement's
; end can put it after the semicolon inserted at the same byte offset.
(new_expression "new" @append_space)
; Continuation indentation can be part of JSX text or a quoted prop value.
[(jsx_element) (jsx_self_closing_element)] @leaf
; Keep computed key expressions intact. Only plain computed methods with a
; single-line key are laid out; contextual modifiers still use ordinary names.
((method_definition) @leaf
  (#not-match? @leaf "^(?:(?:(?:async|get|set)[ \t]+|(?:async[ \t]*)?\\*[ \t]*)?[A-Za-z_$][A-Za-z0-9_$]*|\\[[^\r\n\\x{2028}\\x{2029}]*\\])[ \t]*\\("))
((method_definition) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "^(?:(?:(?:async|get|set)[ \t]+|(?:async[ \t]*)?\\*[ \t]*)?[A-Za-z_$][A-Za-z0-9_$]*|\\[[^\r\n\\x{2028}\\x{2029}]*\\])[ \t]*\\(")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
(object (method_definition name: (computed_property_name) @leaf))
(object "{" @append_indent_start (method_definition) "}" @prepend_indent_end @prepend_hardline)
(object (method_definition body: (statement_block) @prepend_space))
(object (method_definition ["async" "get" "set"] @append_space))
(object "{" @append_hardline (method_definition))
(object (method_definition) (_) @prepend_hardline)
((object (method_definition) @prepend_hardline)
  (#match? @prepend_hardline "^(?:(?:(?:async|get|set)[ \t]+|(?:async[ \t]*)?\\*[ \t]*)?[A-Za-z_$][A-Za-z0-9_$]*|\\[[^\r\n\\x{2028}\\x{2029}]*\\])[ \t]*\\("))
; Objects ending in a formatted method are multiline. Add a comma to
; that method only if it has no authored comma before the closing brace.
((object (method_definition) @append_delimiter . "}") @keep_whitespace
  (#match? @append_delimiter "^(?:(?:(?:async|get|set)[ \t]+|(?:async[ \t]*)?\\*[ \t]*)?[A-Za-z_$][A-Za-z0-9_$]*|\\[[^\r\n\\x{2028}\\x{2029}]*\\])[ \t]*\\(")
  (#not-match? @keep_whitespace ",\\s*}\\z")
  (#delimiter! ","))
; A property immediately after a method also starts on its own line.
((object (method_definition) . [(pair) (shorthand_property_identifier) (spread_element)] @append_delimiter . "}") @keep_whitespace
  (#not-match? @keep_whitespace ",\\s*}\\z")
  (#delimiter! ","))
; A line break can end a yield expression. Only normalize single-line forms.
((yield_expression) @leaf
  (#match? @leaf "[\r\n\\x{2028}\\x{2029}]"))
((yield_expression) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
(yield_expression "yield" . (_) @prepend_space @leaf)
(yield_expression "*" @append_space . (_) @leaf)
; Class members can be separated by ASI. Keep the body and heritage expression
; intact. A multiline class stays opaque because moving the opening brace
; would also move relative indentation inside an otherwise opaque body.
[(class decorator: (decorator)) (class_declaration decorator: (decorator))] @leaf
(([(class) (class_declaration)] @leaf)
  (#match? @leaf "[\r\n\\x{2028}\\x{2029}]"))
; Rebase opaque class layout unless it may contain JSX. As in the HTML
; host guard, skip strings and line comments only before an ambiguous token.
([(class) (class_declaration)] @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "\\A(?:[^<'\"`/]|'(?:[^'\\\\\r\n]|\\\\(?:\r\n|[\\s\\S]))*'|\"(?:[^\"\\\\\r\n]|\\\\(?:\r\n|[\\s\\S]))*\"|//[^\r\n\\x{2028}\\x{2029}]*(?:[\r\n\\x{2028}\\x{2029}]|\\z))*(?:(?:[<`]|/[^/])[\\s\\S]*|/)?(?:</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>)"))
[(class "class" @append_space body: (class_body) @prepend_space)
 (class_declaration "class" @append_space body: (class_body) @prepend_space)]
(class_body) @leaf
; `await` can be an identifier in a script. Do not join it to an expression
; on the next line even if the parser recognizes an await expression there.
((await_expression) @leaf
  (#not-match? @leaf "^await[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[^\\s\\x{FEFF}]"))
(await_expression "await" @append_space (_) @leaf)
; An opaque await may own JSX inside a call or a parenthesized operand.
((await_expression) @multi_line_indent_all
  (#not-match? @multi_line_indent_all "^await[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[^\\s\\x{FEFF}]")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
((await_expression "await" (_) @multi_line_indent_all)
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
[(unary_expression) (update_expression) (object_pattern) (array_pattern) (sequence_expression)] @leaf
([(unary_expression) (update_expression) (object_pattern) (array_pattern) (sequence_expression)] @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
; Default expressions keep their own token spacing, but the assignment
; separator in the parameter list can be normalized independently.
(assignment_pattern "=" @prepend_space @append_space right: (_) @leaf)
((assignment_pattern right: (_) @multi_line_indent_all)
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
; Format static imports by CST, not as expressions. Keep attributes and
; explicitly multiline imports opaque until their layout is handled.
(import_statement (import_attribute)) @leaf @multi_line_indent_all
((import_statement) @leaf @multi_line_indent_all
  (#match? @leaf "[\r\n\\x{2028}\\x{2029}]"))
(import_statement "import" @append_space)
(import_statement "from" @prepend_space @append_space)
(import_clause "," @append_space)
(namespace_import "as" @prepend_space @append_space)
(import_specifier "as" @prepend_space @append_space)
(named_imports "{" @append_space (import_specifier) "}" @prepend_space)
(named_imports "," @append_space)
(named_imports "," @delete . "}")
; Leave exported declarations, values, and multiline lists opaque.
((export_statement) @leaf
  (#not-match? @leaf "^export[ \t]*[{*][^\r\n\\x{2028}\\x{2029}]*\\z"))
((export_statement) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
((export_statement) @append_delimiter
  (#match? @append_delimiter "^export[ \t]*[{*]")
  (#not-match? @append_delimiter ";$")
  (#delimiter! ";"))
(export_statement "export" @append_space)
(export_statement "from" @prepend_space @append_space)
(namespace_export "as" @prepend_space @append_space)
(export_specifier "as" @prepend_space @append_space)
(export_clause "{" @append_space (export_specifier) "}" @prepend_space)
(export_clause "," @append_space)
(export_clause "," @delete . "}")
; Resource declarations must retain spaces around their contextual keywords.
; Braced branches have an explicit statement boundary. Preserve the body of
; each unbraced arm, even when it occurs inside an otherwise formatted chain.
((if_statement consequence: (_) @keep_whitespace) @leaf
  (#not-match? @keep_whitespace "^\\{"))
((if_statement alternative: (else_clause) @keep_whitespace) @leaf
  (#not-match? @keep_whitespace "^else(?:[ \t\r\n]*\\{|[ \t\r\n]+if[ \t\r\n]*\\()"))
(if_statement "if" @append_space consequence: (statement_block) @prepend_space)
(else_clause "else" @prepend_space @append_space [(statement_block) (if_statement)])

((while_statement body: (_) @keep_whitespace) @leaf
  (#not-match? @keep_whitespace "^\\{"))
(while_statement "while" @append_space body: (statement_block) @prepend_space)

(do_statement "do" @append_space body: (statement_block)
  "while" @prepend_space @append_space)
((do_statement body: (statement_block)) @append_delimiter
  (#not-match? @append_delimiter ";$")
  (#delimiter! ";"))
((do_statement body: (_) @keep_whitespace) @leaf
  (#not-match? @keep_whitespace "^\\{"))

; Do not join a jump keyword to a label from another line.
(([(break_statement label: (_)) (continue_statement label: (_))] @leaf @multi_line_indent_all)
  (#not-match? @leaf "^(break|continue)[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]+[^\\s\\x{FEFF}]"))
[(break_statement "break" @append_space label: (_))
 (continue_statement "continue" @append_space label: (_))]
(([(break_statement) (continue_statement)] @append_delimiter)
  (#not-match? @append_delimiter ";$")
  (#delimiter! ";"))

((for_in_statement body: (_) @keep_whitespace) @leaf
  (#not-match? @keep_whitespace "^\\{"))
((for_in_statement) @leaf @multi_line_indent_all
  (#not-match? @leaf "^for(?:[\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]+await)?[\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{2028}\\x{2029}\\x{FEFF}]*\\("))
(for_in_statement "for" @append_space
  operator: _ @prepend_space @append_space
  body: (statement_block) @prepend_space)
(for_in_statement "for" "await" @append_space "(")
(for_in_statement kind: ["const" "let" "var" "using"] @append_space)

((for_statement body: (_) @keep_whitespace) @leaf
  (#not-match? @keep_whitespace "^\\{"))
(for_statement "for" @append_space body: (statement_block) @prepend_space)
(for_statement increment: (_) @prepend_space)
((for_statement condition: (_) @prepend_space)
  (#not-match? @prepend_space "^;$"))
((for_statement initializer: (_) @keep_whitespace condition: (empty_statement) @prepend_space)
  (#not-match? @keep_whitespace "^;$"))
(for_statement condition: (empty_statement) @prepend_space increment: (_))

; Rebase the opaque statement, not the arm alone, unless it contains JSX.
([
  (if_statement consequence: (_) @keep_whitespace)
  (while_statement body: (_) @keep_whitespace)
  (do_statement body: (_) @keep_whitespace)
  (for_in_statement body: (_) @keep_whitespace)
  (for_statement body: (_) @keep_whitespace)
] @multi_line_indent_all
  (#not-match? @keep_whitespace "^\\{")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
((if_statement alternative: (else_clause) @keep_whitespace) @multi_line_indent_all
  (#not-match? @keep_whitespace "^else(?:[ \t\r\n]*\\{|[ \t\r\n]+if[ \t\r\n]*\\()")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))

(try_statement "try" @append_space)
(catch_clause "catch" @prepend_space @append_space body: (statement_block) @prepend_space)
(finally_clause "finally" @prepend_space @append_space)
; Prettier expands empty try/finally bodies, but keeps an empty catch compact.
[(try_statement body: (statement_block "{" . "}" @prepend_hardline))
 (finally_clause body: (statement_block "{" . "}" @prepend_hardline))]

(switch_statement "switch" @append_space body: (switch_body) @prepend_space)
(switch_body "{" @append_indent_start (_) "}" @prepend_indent_end)
(switch_body "}" @prepend_hardline)
[(switch_case) (switch_default)] @prepend_hardline @allow_blank_line_before
(switch_case "case" @append_space)
[(switch_case ":" @append_indent_start (_) @append_indent_end .)
 (switch_default ":" @append_indent_start (_) @append_indent_end .)]

; A keyword followed by '(' is not necessarily a call. Copy control flow as
; a unit until its grammar has rules for contextual keywords and ASI.
(with_statement) @leaf
((labeled_statement body: (_) @keep_whitespace) @leaf
  (#not-match? @keep_whitespace "^(?:\\{|(?:while|for(?:[ \t\r\n]+await)?)[ \t\r\n]*\\(|do[ \t\r\n]*\\{)"))
((labeled_statement body: [
  (while_statement body: (_) @keep_whitespace)
  (do_statement body: (_) @keep_whitespace)
  (for_statement body: (_) @keep_whitespace)
  (for_in_statement body: (_) @keep_whitespace)
 ]) @leaf
  (#not-match? @keep_whitespace "^\\{"))
; An opaque statement must not rebase JSX text or quoted attribute contents.
((with_statement) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
((labeled_statement body: (_) @keep_whitespace) @multi_line_indent_all
  (#not-match? @keep_whitespace "^(?:\\{|(?:while|for(?:[ \t\r\n]+await)?)[ \t\r\n]*\\(|do[ \t\r\n]*\\{)")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
((labeled_statement body: [
  (while_statement body: (_) @keep_whitespace)
  (do_statement body: (_) @keep_whitespace)
  (for_statement body: (_) @keep_whitespace)
  (for_in_statement body: (_) @keep_whitespace)
 ]) @multi_line_indent_all
  (#not-match? @keep_whitespace "^\\{")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>"))
(labeled_statement ":" @append_space body: [
  (statement_block)
  (while_statement body: (statement_block))
  (do_statement body: (statement_block))
  (for_statement body: (statement_block))
  (for_in_statement body: (statement_block))
])

; TSX has distinct nodes for typed declarations that Flow also accepts.
(type_annotation ":" @append_space)
(flow_named_function_annotation ":" @append_space)
(type_predicate_annotation ":" @append_space)
(type_predicate "is" @prepend_space @append_space)
(type_alias_declaration "type" @append_space "=" @prepend_space @append_space)
(type_alias_declaration "opaque" @append_space)
(import_statement ["type" "typeof"] @append_space)
(import_specifier ["type" "typeof"] @append_space)
(ambient_declaration "declare" @append_space)
(ambient_declaration ["export" "default"] @append_space)
(flow_ambient_export_value ["const" "let" "var"] @append_space)
(flow_ambient_opaque_type ["opaque" "type"] @append_space)
(function_signature "function" @append_space)
(function_type "=>" @prepend_space @append_space)
(flow_bare_named_function_type "=>" @prepend_space @append_space)
(flow_chained_callback_annotation ":" @append_space)
(flow_chained_callback_type "=>" @prepend_space @append_space)
(flow_named_function_member_type "=>" @prepend_space @append_space)
(as_expression "as" @prepend_space @append_space)
(type_query "typeof" @append_space)
(index_type_query "keyof" @append_space)
(mapped_type_clause "in" @prepend_space @append_space)
(conditional_type ["extends" "?" ":"] @prepend_space @append_space)
(infer_type "infer" @append_space)
(infer_type "extends" @prepend_space @append_space)
(interface_declaration "interface" @append_space body: (interface_body) @prepend_space)
(flow_interface_type "interface" @append_space (object_type) @prepend_space)
(flow_inferred_predicate) @prepend_space
(extends_type_clause "extends" @prepend_space @append_space ","* @append_space)
(extends_clause "extends" @prepend_space @append_space)
(implements_clause "implements" @prepend_space @append_space ","* @append_space)
(property_signature "readonly" @append_space)
(enum_declaration "enum" @append_space body: (enum_body) @prepend_space)
(flow_enum_representation "of" @prepend_space @append_space)
(enum_body "{" @append_space (_) "}" @prepend_space)
(enum_body "," @append_space . [_ "..."])
(enum_assignment "=" @prepend_space @append_space)
(flow_component_type_parameters "," @append_space . (_))
(flow_component_render_type ["renders" "renders?" "renders*"] @prepend_space @append_space)
(tuple_type "," @append_space . (_))

; The generic parameter layout can move a standalone suppression comment
; onto the previous parameter's line. Keep commented lists intact.
((formal_parameters (comment) @do_nothing) @leaf
  (#match? @do_nothing "^//"))

; Inline object-type layout must not move a standalone member comment.
((object_type (comment) @do_nothing) @leaf
  (#match? @do_nothing "^//"))
((interface_body (comment) @do_nothing) @leaf
  (#match? @do_nothing "^//"))

; In libdefs, standalone block comments can serve as tuple element labels.
(tuple_type (comment)) @leaf

; Keep a suppression comment between the opening parenthesis and its operand.
((parenthesized_expression (comment) @do_nothing) @leaf
  (#match? @do_nothing "^//"))

; An initializer can have a standalone explanation after the equals sign.
((variable_declarator (comment) @prepend_input_softline @allow_blank_line_before)
  (#match? @prepend_input_softline "^//"))

((binary_expression (comment) @prepend_input_softline @allow_blank_line_before)
  (#match? @prepend_input_softline "^//"))

((arguments (comment) @prepend_input_softline @allow_blank_line_before)
  (#match? @prepend_input_softline "^//"))

((array (comment) @prepend_input_softline @allow_blank_line_before)
  (#match? @prepend_input_softline "^//"))

((object (comment) @prepend_input_softline @allow_blank_line_before)
  (#match? @prepend_input_softline "^//"))

; Keep comments on the same or a separate line as authored, including
; trailing comments after statements in function and control-flow bodies.
((program (_) @prepend_hardline @allow_blank_line_before)
  (#not-match? @prepend_hardline "^/(?:\\*|/)"))
(program (comment) @prepend_input_softline @allow_blank_line_before)
((statement_block (_) @prepend_hardline @allow_blank_line_before)
  (#not-match? @prepend_hardline "^/(?:\\*|/)"))
(statement_block (comment) @prepend_input_softline @allow_blank_line_before)
(switch_body (comment) @prepend_input_softline @allow_blank_line_before)
([(switch_case ":" (_) @prepend_hardline @allow_blank_line_before)
  (switch_default ":" (_) @prepend_hardline @allow_blank_line_before)]
  (#not-match? @prepend_hardline "^/(?:\\*|/)"))
[(switch_case ":" (comment) @prepend_input_softline @allow_blank_line_before)
 (switch_default ":" (comment) @prepend_input_softline @allow_blank_line_before)]

; A comment between the receiver and property can annotate a split chain.
((member_expression (comment) @prepend_input_softline @append_input_softline)
  (#match? @prepend_input_softline "^/\\*"))

; Without a line break, formatting can turn the next token into comment text.
((comment) @leaf @append_hardline
  (#match? @leaf "^//"))

; The CST may include a trailing line comment in an unterminated declaration.
; Keep the authored ASI boundary rather than putting a semicolon in the comment.
(([(lexical_declaration) (variable_declaration) (debugger_statement) (import_statement)] @append_delimiter)
  (#not-match? @append_delimiter ";$|^let$|//[^\r\n\\x{2028}\\x{2029}]*$")
  (#not-match? @append_delimiter "(?s:\\basync[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}][\\p{Zs}\t\r\n\\x{000B}\\x{000C}\\x{FEFF}]*function\\b.*\\}\\z)")
  (#delimiter! ";"))
(([(lexical_declaration) (variable_declaration)] (comment) @prepend_input_softline)
  (#match? @prepend_input_softline "^//"))
