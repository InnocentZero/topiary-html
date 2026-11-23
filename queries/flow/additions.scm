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
