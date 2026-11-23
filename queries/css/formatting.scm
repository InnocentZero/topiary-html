; Keep literal value and selector tokens opaque; their content may include
; meaningful whitespace or escape sequences.
[(string_value) (plain_value) (dollar_value) (phorge_value_variable) (template_value_variable) (integer_value) (float_value) (url_value)] @leaf
(phorge_print_rule) @leaf @prepend_hardline @allow_blank_line_before @append_hardline
(stylesheet_template_placeholder) @leaf @prepend_hardline @allow_blank_line_before @append_hardline
[(hash_value) (numeric_hash_selector)] @leaf
; Only a final LF needs the renderer's whitespace-preservation pass. An
; ordinary color hash does not; an escape terminator can include LF or CRLF.
(([(hash_value) (numeric_hash_selector)] @keep_whitespace)
  (#match? @keep_whitespace "\n\\z"))
; A delimiter followed by a comment and a name is not a hash token.
; Preserve the whole declaration to avoid changing that boundary.
; A value can contain a tilde delimiter even when a descriptor rejects the value.
(declaration [(hash_delimiter) (tilde_delimiter)]) @leaf
; Move continuation lines only when they don't contain protected comment or escape bytes.
((declaration [(hash_delimiter) (tilde_delimiter)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
; Legacy IE declarations must retain the prefix and its token boundaries.
(declaration (legacy_prefixed_property)) @leaf
((declaration (legacy_prefixed_property)) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
; Joining a delimiter to a number can turn it into a signed number token.
(declaration (leading_plus_delimiter)) @leaf
((declaration (leading_plus_delimiter)) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(([(integer_value) (float_value)] @keep_whitespace)
  (#match? @keep_whitespace "\n\\z"))
(legacy_filter_value) @leaf
(legacy_expression_value) @leaf
((legacy_expression_value) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((legacy_filter_value) @multi_line_indent_all
  (#not-match? @multi_line_indent_all "/\\*")
  (#match? @multi_line_indent_all "[\r\n]"))
(type_syntax_value) @leaf
((type_syntax_value) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]"))
; Rebase only breaks between tokens, not those inside comments or escapes.
[(parenthesized_value) (grid_value) (conditional_value) (adjacent_minus_block)] @leaf
(([(parenthesized_value) (grid_value) (conditional_value) (adjacent_minus_block)] @multi_line_indent_all)
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
[(qualified_attr_value) (interpolated_attr_value)] @leaf
(([(qualified_attr_value) (interpolated_attr_value)] @multi_line_indent_all)
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
[(escaped_attribute_value) (escaped_class_name) (escaped_id_name) (escaped_value_identifier) (escaped_property_name) (escaped_function_name) (escaped_at_keyword)] @leaf @keep_whitespace
[(escaped_type_name) (escaped_attribute_name) (escaped_suffixed_nesting_selector)] @leaf @keep_whitespace
(escaped_custom_media_name) @leaf @keep_whitespace
; CSSTree does not parse the custom-state argument. Preserve the full
; argument spelling, including any whitespace that terminates a hex escape.
(state_arguments) @leaf

; The significance of an exclamation delimiter depends on the function.
; Keep the adjacent tokens and whitespace exactly as authored.
(arguments (function_bang)) @leaf
(arguments [(function_block_argument) (function_prefix_delimiter)]) @leaf
((arguments [(function_block_argument) (function_prefix_delimiter)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
; Rebase breaks between tokens for HTML injection, not breaks inside
; comments or escapes. Otherwise every pass adds the host indentation.
((arguments (function_bang)) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))

; Generic pseudo-elements own their balanced component values. Do not
; reinterpret an unfamiliar argument as an ordinary selector or declaration.
(pseudo_element_arguments) @leaf
((pseudo_element_selector (tag_name) @keep_whitespace . (pseudo_element_arguments) @multi_line_indent_all)
  (#not-match? @keep_whitespace "(?i-u:^::part$)")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((pseudo_element_selector (escaped_pseudo_element_name) (pseudo_element_arguments) @multi_line_indent_all)
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(escaped_pseudo_element_name) @leaf @keep_whitespace
(escaped_pseudo_class_name) @leaf @keep_whitespace
[(escaped_pseudo_class_arguments) (malformed_pseudo_class_arguments)] @leaf
(([(escaped_pseudo_class_arguments) (malformed_pseudo_class_arguments)] @multi_line_indent_all)
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))

; CSS Modules and ICSS consume these arguments before standard selector parsing.
; Keep continuation bytes as authored; the host scanner leaves multiline
; module arguments opaque instead of adding HTML indentation inside them.
((pseudo_class_selector (class_name) @keep_whitespace (arguments) @leaf)
  (#match? @keep_whitespace "^(local|global|import)$"))
; Keep transition type identifiers and their separators as authored.
((pseudo_class_selector (class_name) @keep_whitespace (arguments) @leaf)
  (#match? @keep_whitespace "(?i-u:^active-view-transition-type$)"))

; The independent CSS parser stores these arguments as raw syntax. Keep
; their spelling, rather than imposing ordinary declaration-value layout.
((pseudo_element_selector (tag_name) @keep_whitespace (arguments) @leaf)
  (#match? @keep_whitespace "(?i-u:^::(cue|cue-region)$)"))
; Keep standalone comment bodies byte-exact. HTML leaves stylesheets with
; multiline comments opaque rather than rebasing their continuation lines.
(comment) @leaf
; A root-level comment otherwise joins the preceding rule or comment. Its
; changed starting column shifts continuation lines again on the next pass.
(stylesheet (comment) @prepend_hardline @append_hardline)
; Honor an exact directive on the adjacent sibling only. Keep descendants
; opaque so declaration and selector rules cannot reformat the ignored text.
((stylesheet (comment) @keep_whitespace . (rule_set) @leaf)
  (#match? @keep_whitespace "^/\\*[ \t\\r\\n\\f]*prettier-ignore[ \t\\r\\n\\f]*\\*/$"))
((block (comment) @keep_whitespace . [(rule_set) (declaration)] @leaf)
  (#match? @keep_whitespace "^/\\*[ \t\\r\\n\\f]*prettier-ignore[ \t\\r\\n\\f]*\\*/$"))
; Rebase ordinary layout without moving breaks that belong to comments or escapes.
((stylesheet (comment) @keep_whitespace . (rule_set) @multi_line_indent_all)
  (#match? @keep_whitespace "^/\\*[ \t\\r\\n\\f]*prettier-ignore[ \t\\r\\n\\f]*\\*/$")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((block (comment) @keep_whitespace . [(rule_set) (declaration)] @multi_line_indent_all)
  (#match? @keep_whitespace "^/\\*[ \t\\r\\n\\f]*prettier-ignore[ \t\\r\\n\\f]*\\*/$")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
; The parser accepts // extensions; a newline terminates such a comment.
(js_comment) @leaf @append_hardline
(empty_statement) @delete
(incomplete_selector) @leaf @prepend_hardline
(eof_declaration_rule) @leaf @prepend_hardline
; A trailing comment may be a stylesheet extra even though CSS consumes it
; in the unfinished value. Keep the stylesheet opaque to preserve that gap.
(stylesheet (eof_custom_property_rule)) @leaf
; At EOF the parser may attach comments after an open function to the
; stylesheet. Keep their original spacing inside that unfinished condition.
(stylesheet (eof_media_function_condition)) @leaf
; The formatting CLI restores the original physical stylesheet edge.
(stylesheet (eof_string_rule)) @leaf
((eof_declaration_rule) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((incomplete_selector) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
[(html_comment_open) (html_comment_close)] @prepend_hardline @append_hardline

; A custom property's payload is substituted as authored component values.
; Do not let declaration spacing or binary operator rules edit that payload.
; Preserve continuation columns too; the HTML scanner keeps sensitive style
; bodies opaque so injection cannot add indentation to those lines.
; A literal or escaped hyphen can contribute to the two-hyphen prefix.
((declaration) @leaf @keep_whitespace
  (#match? @leaf "^(?:-|\\\\(?:-|0{0,4}2[dD](?:\r\n|[ \t\r\n\f])?)){2}"))
(trailing_declaration_space) @delete
; For non-opaque declarations, attach the terminator to the value, not the
; discarded whitespace leaf. Opaque custom declarations keep the space.
((declaration _ @append_delimiter . (trailing_declaration_space))
  (#delimiter! ";"))
(declaration ":" @append_space)
((declaration) @append_delimiter
  (#not-match? @append_delimiter ";$")
  (#delimiter! ";"))
(block (declaration) . (empty_statement)* . (declaration) @prepend_hardline @allow_blank_line_before)
(block [(rule_set) (legacy_nest_statement)] . (empty_statement)* . (declaration) @prepend_hardline @allow_blank_line_before)
(stylesheet (declaration) . (empty_statement)* . (declaration) @prepend_hardline)
(block (orphan_important) . (empty_statement)* . (declaration) @prepend_hardline)
(orphan_important) @leaf @prepend_hardline
(slash_prefixed_declaration) @leaf @prepend_hardline
(nameless_declaration) @leaf @prepend_hardline @append_hardline
(gtk_nth_child_arguments) @leaf @keep_whitespace
(detached_class_name) @leaf @keep_whitespace
(qt_negated_subcontrol_states) @leaf @keep_whitespace
(detached_percentage_value) @leaf @keep_whitespace
(dot_prefixed_declaration) @leaf @prepend_hardline @append_hardline
(digit_led_declaration) @leaf @prepend_hardline @append_hardline
(less_merge_property_name) @leaf
(simple_vars_property_name) @leaf
(split_property_declaration) @leaf @multi_line_indent_all @prepend_hardline
(simple_vars_substitution) @leaf
(bare_property) @leaf @prepend_hardline @append_hardline
(bare_descendant_block_item) @leaf @prepend_hardline @append_hardline
(brace_valued_declaration) @leaf @prepend_hardline @append_hardline
(templated_dimension_declaration) @leaf @prepend_hardline @append_hardline
(blockless_nested_pseudo) @leaf @prepend_hardline @append_hardline
((blockless_nested_pseudo) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((bare_descendant_block_item) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((brace_valued_declaration) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((bare_property) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]"))
(sass_variable_declaration) @leaf @prepend_hardline @append_hardline @allow_blank_line_before
((sass_variable_declaration) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(block (slash_prefixed_declaration) . (empty_statement)* . (declaration) @prepend_hardline)
(block (split_property_declaration) . (empty_statement)* . (declaration) @prepend_hardline)
; A line break before the semicolon may be present in recovered input.
; Rebase it when embedding, but do not shift continuation lines in comments
; or escapes that are part of the original token spelling.
((orphan_important) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(block (comment) @prepend_hardline @append_hardline)
(block "{" @prepend_space)
; A hexadecimal escape can already own the space before the block. If there
; was no terminator, do not create one: `{` ends the escape on its own.
((rule_set (selectors) @keep_whitespace (block "{" @prepend_antispace))
   (#match? @keep_whitespace "[ \t\r\n\f]\\z|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}\\z"))
(block "{" @append_indent_start @append_hardline
   [(declaration) (orphan_important) (slash_prefixed_declaration) (dot_prefixed_declaration) (digit_led_declaration) (split_property_declaration) (bare_property) (bare_descendant_block_item) (brace_valued_declaration) (blockless_nested_pseudo) (rule_set) (import_statement) (media_statement) (starting_style_statement) (custom_media_statement) (container_statement) (charset_statement)
   (namespace_statement) (layer_statement) (scope_statement) (keyframes_statement) (supports_statement)
    (page_statement) (page_margin_statement) (font_face_statement) (font_palette_values_statement)
    (property_statement) (view_transition_statement) (counter_style_statement) (position_try_statement)
    (font_feature_values_statement)
    (moz_document_statement) (custom_function_statement) (tailwind_apply_statement) (mixin_apply_statement)
    (tailwind_custom_variant_statement) (tailwind_theme_statement) (tailwind_utility_statement)
    (legacy_nest_statement) (invalid_line_escape_rule) (at_rule) (comment) (js_comment)]
   "}" @prepend_indent_end @prepend_hardline)
(rule_set) @prepend_hardline @allow_blank_line_before
(invalid_line_escape_rule) @leaf @keep_whitespace @prepend_hardline @append_hardline @allow_blank_line_before
[(invalid_line_escape_attribute) (unquoted_brace_attribute)] @leaf @keep_whitespace
(invalid_line_escape_url) @leaf @keep_whitespace
(invalid_spaced_url) @leaf @keep_whitespace
(invalid_parenthesized_url) @leaf @keep_whitespace
(inline_double_slash_block) @leaf @prepend_space
(less_class_mixin_call) @leaf @prepend_hardline @append_hardline
((less_class_mixin_call) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
[(numeric_prefix_rule) (stray_close_rule) (duplicate_class_dot_rule) (anonymous_nested_block) (malformed_media_rule_prefix)] @leaf @prepend_hardline @append_hardline @allow_blank_line_before
([(numeric_prefix_rule) (stray_close_rule) (duplicate_class_dot_rule) (anonymous_nested_block) (malformed_media_rule_prefix)] @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
; Keep the older dialect's selector prelude as authored.
(legacy_nest_statement "@nest" @append_space (selectors) @leaf) @prepend_hardline @allow_blank_line_before
((legacy_nest_statement (selectors) @multi_line_indent_all)
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((legacy_nest_statement (selectors) @keep_whitespace (block "{" @prepend_antispace))
   (#match? @keep_whitespace "[ \t\r\n\f]\\z|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}\\z"))
; A block comment can sit inside a combinator or between adjacent selector
; tokens. Keep the whole commented selector's spaces and line breaks.
((selectors) @leaf
  (#match? @leaf "/\\*"))
((selectors) @multi_line_indent_all
  (#match? @multi_line_indent_all "/\\*")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(selectors "," @append_hardline)
(detached_pseudo_class_selector) @leaf
((detached_pseudo_class_selector) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(descendant_selector (_) @append_space . (_))
(child_selector ">" @prepend_space @append_space)
(adjacent_sibling_selector "+" @prepend_space @append_space)
(sibling_selector "~" @prepend_space @append_space)
(column_selector) @leaf
((column_selector) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(attribute_modifier) @prepend_space
(escaped_attribute_modifier) @leaf @keep_whitespace @prepend_space

(important) @prepend_space
(selector_shaped_declaration_value) @leaf
(comment_separated_at_value) @leaf
(glued_numeric_bracket_value) @leaf
(numeric_bracket_suffix) @leaf
(call_with_numeric_brackets (call_expression) @append_antispace)
; Preserve misspelled priorities without treating them as real priorities.
((invalid_priority) @leaf
  (#not-match? @leaf "^!$"))
((invalid_priority) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(priority_gap) @delete
((important_keyword) @keep_whitespace
  (#match? @keep_whitespace "[\r\n\f]\\z"))
; Do not change the spelling of a terminal escape by inserting whitespace
; that CSS tokenization would consume as part of the escape.
((declaration
    (escaped_value_identifier) @keep_whitespace .
    (important) @prepend_antispace)
  (#match? @keep_whitespace "[ \t\r\n\f]\\z|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}\\z"))
; A generated space before a terminal slash can also enter the escape token.
(([(declaration (_) @keep_whitespace . (trailing_slash) @prepend_antispace)
   (arguments (_) @keep_whitespace . (trailing_slash) @prepend_antispace)])
  (#match? @keep_whitespace "(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}(?:\r\n|[ \t\r\n\f])?\\z"))
; Leave a final comma adjacent to an explicit or inserted semicolon.
(declaration "," @append_space . (_))
; The var() fallback is substituted as authored component values. In
; particular, whitespace after its first comma belongs to the fallback.
((call_expression (function_name) @do_nothing (arguments ",")) @leaf @multi_line_indent_all
  (#match? @do_nothing "(?i-u:^var$)"))
; Escaped spellings of var() own the same fallback bytes. A short hex escape
; for v needs a terminator before a literal a, which is itself a hex digit.
; HTML leaves multiline escaped var() calls opaque before CSS injection.
((call_expression (escaped_function_name) @do_nothing (arguments ",")) @leaf
  (#match? @do_nothing "(?i-u:^(?:(?:v|\\\\v|\\\\0{4}[57]6(?:\r\n|[ \t\r\n\f])?|\\\\0{0,3}[57]6(?:\r\n|[ \t\r\n\f]))a|(?:v|\\\\v|\\\\0{0,4}[57]6(?:\r\n|[ \t\r\n\f])?)\\\\0{0,4}[46]1(?:\r\n|[ \t\r\n\f])?)(?:r|\\\\r|\\\\0{0,4}[57]2(?:\r\n|[ \t\r\n\f])?)$)"))
; Keep the punctuation around explicit empty fields as authored.
[(arguments "(" . (comment)* . ",") (arguments "," . (comment)* . ",")] @leaf
(([(arguments "(" . (comment)* . ",") (arguments "," . (comment)* . ",")]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(arguments "," @append_space . (_))
(arguments ";" @append_space)
(arguments (_) @append_space . (_))
(arguments ["," ";"] @prepend_antispace)
(arguments (nth_filter_keyword) @prepend_space @append_space)
(declaration ":" (_)+ @append_space)
(declaration ";" @prepend_antispace)
(declaration "," @prepend_antispace)
; CSS comments do not count as the whitespace required around + and -.
; Keep commented expressions opaque. Also conservatively keep an additive
; expression if a sign touches a token: a spacing rule could turn invalid
; CSS math (including around var() and parentheses) into valid math.
((binary_expression) @leaf
  (#match? @leaf "/\\*"))
((binary_expression ["+" "-"]) @leaf
  (#match? @leaf "[^ \t\r\n\f][+-]|[+-][^ \t\r\n\f]"))
; Rebase breaks between tokens so embedding the stylesheet does not add its
; indentation again. Leave breaks inside comments, escapes, and var()
; fallbacks untouched. In the embedded query, omit the standalone-only
; guards: the HTML scanner already keeps multiline var() opaque. An inline
; var() must not suppress rebasing a line break elsewhere in the expression.
((binary_expression) @multi_line_indent_all
  (#match? @multi_line_indent_all "/\\*")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]")
  (#not-match? @multi_line_indent_all "(?i-u:(?:(?:v|\\\\v|\\\\0{4}[57]6(?:\r\n|[ \t\r\n\f])?|\\\\0{0,3}[57]6(?:\r\n|[ \t\r\n\f]))a|(?:v|\\\\v|\\\\0{0,4}[57]6(?:\r\n|[ \t\r\n\f])?)\\\\0{0,4}[46]1(?:\r\n|[ \t\r\n\f])?)(?:r|\\\\r|\\\\0{0,4}[57]2(?:\r\n|[ \t\r\n\f])?))\\(") ; standalone-only
)
((binary_expression ["+" "-"]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[^ \t\r\n\f][+-]|[+-][^ \t\r\n\f]")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]")
  (#not-match? @multi_line_indent_all "(?i-u:(?:(?:v|\\\\v|\\\\0{4}[57]6(?:\r\n|[ \t\r\n\f])?|\\\\0{0,3}[57]6(?:\r\n|[ \t\r\n\f]))a|(?:v|\\\\v|\\\\0{0,4}[57]6(?:\r\n|[ \t\r\n\f])?)\\\\0{0,4}[46]1(?:\r\n|[ \t\r\n\f])?)(?:r|\\\\r|\\\\0{0,4}[57]2(?:\r\n|[ \t\r\n\f])?))\\(") ; standalone-only
)
(binary_expression ["+" "-" "*" "/" "**"] @prepend_space @append_space)
(separated_slash_star) @leaf @prepend_space @append_space
; A space immediately after a hex escape changes its authored token bytes.
((binary_expression (_) @keep_whitespace . ["*" "/" "**" (separated_slash_star)] @prepend_antispace)
  (#match? @keep_whitespace "(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}(?:\r\n|[ \t\r\n\f])?\\z"))
(media_statement ["@media" ","] @append_space)
[(dangling_media_conjunction) (media_condition_literal_newline)] @leaf
(([(dangling_media_conjunction) (media_condition_literal_newline)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(media_type_without_conjunction) @leaf
((media_type_without_conjunction) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
; A final escaped query name can already own a hex escape terminator.
; Without one, `{` itself ends the escape. Do not add whitespace to the token.
((media_statement (escaped_custom_media_name) @keep_whitespace . (block "{" @prepend_antispace))
  (#match? @keep_whitespace "[ \t\r\n\f]\\z|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}\\z"))
(custom_media_statement ["@custom-media" (custom_media_name) ","] @append_space)
(custom_media_statement "@custom-media" . (escaped_custom_media_name) @append_space)
(custom_media_statement (invalid_custom_media_value)) @leaf
((custom_media_statement (invalid_custom_media_value)) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(custom_media_statement) @prepend_hardline @append_hardline @allow_blank_line_before
; Keep the selector prelude verbatim, including combinators and escaped names.
(custom_selector_statement) @leaf @prepend_hardline @append_hardline @allow_blank_line_before
((custom_selector_statement) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
[(tailwind_apply_statement) (tailwind_custom_variant_statement)
 (tailwind_theme_statement) (tailwind_utility_statement)]
  @leaf @prepend_hardline @append_hardline @allow_blank_line_before
(([(tailwind_apply_statement) (tailwind_custom_variant_statement)
   (tailwind_theme_statement) (tailwind_utility_statement)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(mixin_apply_statement) @leaf @prepend_hardline @append_hardline @allow_blank_line_before
((mixin_apply_statement) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(container_statement ["@container" ","] @append_space)
(container_statement (container_name) @append_space)
[(escaped_named_container_condition) (class_shaped_container_condition)] @leaf
(([(escaped_named_container_condition) (class_shaped_container_condition)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(page_statement "@page" @append_space)
(page_selector) @leaf
((page_selector) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
[(page_statement) (page_margin_statement)] @prepend_hardline @append_hardline @allow_blank_line_before
(font_face_statement) @prepend_hardline @allow_blank_line_before
(property_statement (at_keyword) @append_space) @prepend_hardline @allow_blank_line_before
(bad_string_declaration) @leaf @prepend_hardline @append_hardline
(invalid_line_escape_declaration) @leaf @keep_whitespace @prepend_hardline @append_hardline
(view_transition_statement) @prepend_hardline @allow_blank_line_before
(position_try_statement (at_keyword) @append_space) @prepend_hardline @allow_blank_line_before
(position_try_name) @leaf @keep_whitespace
((position_try_statement (position_try_name) @keep_whitespace (block "{" @prepend_antispace))
  (#match? @keep_whitespace "[ \t\r\n\f]\\z|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}\\z"))
(counter_style_statement (at_keyword) @append_space) @prepend_hardline @allow_blank_line_before
(counter_style_name) @leaf @keep_whitespace
((counter_style_statement (counter_style_name) @keep_whitespace (block "{" @prepend_antispace))
  (#match? @keep_whitespace "[ \t\r\n\f]\\z|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}\\z"))
(registered_property_name) @keep_whitespace
((property_statement (registered_property_name) @keep_whitespace (block "{" @prepend_antispace))
  (#match? @keep_whitespace "[ \t\r\n\f]\\z|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}\\z"))
(font_palette_values_statement (at_keyword) @append_space) @prepend_hardline @allow_blank_line_before
(font_palette_name) @keep_whitespace
((font_palette_values_statement (font_palette_name) @keep_whitespace (block "{" @prepend_antispace))
  (#match? @keep_whitespace "[ \t\r\n\f]\\z|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{1,6}\\z"))
((font_palette_values_statement
    (block (declaration
      (property_name) @keep_whitespace
      ":" @append_indent_start @append_hardline
      "," @append_hardline ","* @append_hardline) @append_indent_end))
  (#match? @keep_whitespace "(?i-u)^override-colors$"))
; An escaped U is not the start of a Unicode-range token. Do not rewrite
; the adjacent plus as an arithmetic operator or consume its new whitespace.
((font_face_statement (block (declaration) @leaf))
  (#match? @leaf "(?i-u:^unicode-range)[ \t\r\n\f]*:[ \t\r\n\f]*\\\\0{0,4}55(?:\r\n|[ \t\r\n\f])?\\+"))
((font_face_statement (block (declaration) @multi_line_indent_all))
  (#match? @multi_line_indent_all "(?i-u:^unicode-range)[ \t\r\n\f]*:[ \t\r\n\f]*\\\\0{0,4}55[ \t\f]?\\+[^\r\n]*[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(font_feature_values_statement (font_feature_values_keyword) @append_space)
(font_family_list) @leaf
((font_family_list) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(font_feature_values_statement) @prepend_hardline @append_hardline @allow_blank_line_before
(moz_document_statement "@-moz-document" @append_space)
(document_conditions) @leaf
((document_conditions) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(moz_document_statement) @prepend_hardline @append_hardline @allow_blank_line_before
(feature_query ":" @append_space)
; A feature value can contain multiple components (including unknown syntax).
; Do not concatenate those components into a different token sequence.
(feature_query (feature_name) . (_) . (_)) @leaf
(feature_query ",") @leaf
; Preserve spelling and spacing of the range, as Prettier does.
[(range_query) (computed_feature_query) (container_query_function) (mozilla_preference_query) (bracketed_media_list_item) (grouped_media_list_item)
  (general_enclosed_query) (parenthesized_general_enclosed_query) (infix_not_container_condition) (bracketed_keyframe_item)
  (block_valued_media_feature)] @leaf
(([(feature_query (feature_name) . (_) . (_)) (feature_query ",") (range_query) (computed_feature_query) (container_query_function)
   (mozilla_preference_query) (general_enclosed_query) (parenthesized_general_enclosed_query) (bracketed_media_list_item) (grouped_media_list_item)
     (infix_not_container_condition) (bracketed_keyframe_item) (block_valued_media_feature)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(binary_query ["and" "or"] @prepend_space @append_space)
(import_statement "@import" @append_space)
[(eof_import_statement) (eof_container_query)] @leaf @prepend_hardline @allow_blank_line_before
(stylesheet (eof_import_statement (eof_string_value))) @leaf
(eof_at_keyword_escape) @leaf @prepend_hardline @allow_blank_line_before
(eof_stray_backslash) @leaf @prepend_hardline
[(import_layer_clause) (import_supports_clause) (import_media_list)] @prepend_space
[(tailwind_import_source) (import_scope_clause)] @leaf @prepend_space
[(computed_import_supports_declaration) (priority_named_import_supports_declaration)
 (detached_import_supports_function) (detached_import_media_function)] @leaf
(([(tailwind_import_source) (import_scope_clause) (computed_import_supports_declaration)
    (priority_named_import_supports_declaration) (detached_import_supports_function)
    (detached_import_media_function)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(import_supports_clause ":" @append_space)
(import_media_list "," @append_space)
(layer_statement (layer_name) @prepend_space)
; The terminal space of an escaped layer name can already separate its block.
((layer_statement (layer_name) @keep_whitespace (block "{" @prepend_antispace))
  (#match? @keep_whitespace "[ \t\r\n\f]\\z"))
(layer_statement) @prepend_hardline @append_hardline @allow_blank_line_before
(scope_statement [(scope_boundary) "to"] @prepend_space)
(scope_boundary) @leaf
((scope_boundary) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(scope_statement) @prepend_hardline @append_hardline @allow_blank_line_before
; Encoding detection requires an exact byte spelling. Do not normalize the
; case, quote style, or whitespace within the declaration.
(charset_statement) @leaf
[(import_statement) (charset_statement) (media_statement) (container_statement) (starting_style_statement)] @prepend_hardline @append_hardline @allow_blank_line_before

(keyframes_statement (at_keyword) @append_space)
(scoped_keyframes_name) @leaf @keep_whitespace
; Rebase breaks between the CSS Modules scope and name on HTML injection.
((scoped_keyframes_name) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(keyframes_statement) @prepend_hardline @allow_blank_line_before
(keyframe_block) @prepend_hardline
(keyframe_block "," @append_hardline)
(keyframe_timeline_range (timeline_range_name) @append_space)
(keyframe_block_list "{" @prepend_space)
((keyframes_statement [(keyframes_name) (scoped_keyframes_name)] @keep_whitespace
  (keyframe_block_list "{" @prepend_antispace))
  (#match? @keep_whitespace "[ \t\r\n\f]\\z"))
(keyframe_block_list "{" @append_indent_start @append_hardline (_) "}" @prepend_indent_end @prepend_hardline)
; A stray semicolon can be part of an invalid keyframe selector. Do not
; delete it and accidentally turn the following frame into a valid rule.
; A block without a selector is also invalid; keep its boundary intact.
(keyframe_block_list [(empty_statement) (anonymous_nested_block)]) @leaf
((keyframe_block_list [(empty_statement) (anonymous_nested_block)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
; Do not supply an offset or rewrite a frame with a missing offset.
(keyframe_block (keyframe_range_without_offset)) @leaf
((keyframe_block (keyframe_range_without_offset)) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))

(custom_function_statement) @prepend_hardline @append_hardline @allow_blank_line_before
(custom_function_signature) @leaf
((custom_function_signature) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))

; Keep unknown at-rule preludes and their token separators intact.
[(at_rule) (eof_unknown_at_rule) (namespace_statement)] @leaf @prepend_hardline @allow_blank_line_before
; The host leaves CSS with multiline comments and escaped line breaks opaque.
; Rebase other multiline directives without changing bytes inside those tokens.
(([(at_rule) (eof_unknown_at_rule) (namespace_statement)]) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
; Keep the supports condition as CSS component values, not a declaration.
; Start with single declaration queries. Keep complex and unknown conditions
; and their bodies opaque, including the original outer spacing.
(supports_statement) @prepend_hardline @allow_blank_line_before
((supports_statement (supports_condition) @keep_whitespace) @leaf
  (#not-match? @keep_whitespace "^\\([a-zA-Z][a-zA-Z-]*:[ \t]*[a-zA-Z0-9_-]+[ \t]*\\)\\z"))
(supports_statement (comment)) @leaf
((supports_statement (supports_condition) @keep_whitespace) @multi_line_indent_all
  (#not-match? @keep_whitespace "^\\([a-zA-Z][a-zA-Z-]*:[ \t]*[a-zA-Z0-9_-]+[ \t]*\\)\\z")
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
((supports_statement (comment)) @multi_line_indent_all
  (#match? @multi_line_indent_all "[\r\n]")
  (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\[0-9A-Fa-f]{0,6}[\r\n\f]"))
(supports_statement (at_keyword) @append_space (supports_condition) @leaf)
(unary_query ["not" "only"] @append_space)
