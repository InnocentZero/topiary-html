/**
 * @file CSS grammar for tree-sitter
 * @author Max Brunsfeld <maxbrunsfeld@gmail.com>
 * @author Amaan Qureshi <amaanq12@gmail.com>
 * @license MIT
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

const CSS_ESCAPE = /\\(?:[0-9a-fA-F]{1,6}(?:\r\n|[ \t\r\n\f])?|[^\r\n\f0-9a-fA-F])/;
const UNQUOTED_URL_BODY = /[^ \t\r\n\f"'()\\\x00-\x08\x0b\x0e-\x1f\x7f]+/;
// Each decoded letter may be literal, simply escaped, or hex-escaped.
const URL_NAME = /(?:[Uu]|\\(?:[Uu]|0{0,4}[57]5(?:\r\n|[ \t\r\n\f])?))(?:[Rr]|\\(?:[Rr]|0{0,4}[57]2(?:\r\n|[ \t\r\n\f])?))(?:[Ll]|\\(?:[Ll]|0{0,4}[46][cC](?:\r\n|[ \t\r\n\f])?))/;
const CSS_IDENTIFIER = /(--|-?[a-zA-Z_\u{80}-\u{10FFFF}])[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]*/u;
const DASHED_NAME_BODY = /[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u;
const BEFORE_IDENTIFIER_ESCAPE = /(?:--|-?[a-zA-Z_\u{80}-\u{10FFFF}])[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]*|-+/u;
const CSS_HYPHEN = /(?:-|\\(?:-|0{0,4}2[dD](?:\r\n|[ \t\r\n\f])?))/;
const CSS_BLOCK_COMMENT = /\/\*[^*]*\*+(?:[^/*][^*]*\*+)*\//;
const KEYFRAMES_KEYWORD = /@(?:-[a-zA-Z]+-)?[kK][eE][yY][fF][rR][aA][mM][eE][sS]/;

function badString() {
  return choice(
    seq("'", repeat(choice(/[^\\'\r\n\f]+/, CSS_ESCAPE, /\\(?:\r\n|[\r\n\f])/)), /\r\n|[\r\n\f]/),
    seq('"', repeat(choice(/[^\\"\r\n\f]+/, CSS_ESCAPE, /\\(?:\r\n|[\r\n\f])/)), /\r\n|[\r\n\f]/),
  );
}

function dashedName() {
  const namePart = choice(DASHED_NAME_BODY, CSS_ESCAPE);
  return seq(
    CSS_HYPHEN,
    choice(
      seq(/(?:-|\\-|\\00002[dD](?:\r\n|[ \t\r\n\f])?|\\0{0,3}2[dD](?:\r\n|[ \t\r\n\f]))/, repeat1(namePart)),
      // An unterminated short hex escape can't split before a hex digit.
      seq(/\\0{0,3}2[dD]/, choice(/[g-zG-Z_\-\u{80}-\u{10FFFF}]/u, CSS_ESCAPE), repeat(namePart)),
    ),
  );
}

module.exports = grammar({
  name: 'css',

  extras: $ => [
    /\s/,
    $.comment,
    $.js_comment,
  ],

  externals: $ => [
    $._descendant_operator,
    $._pseudo_class_selector_colon,
    $._spaced_star_property,
    $.trailing_declaration_space,
    $._escaped_important_keyword,
    $.priority_gap,
    $.legacy_prefixed_property,
    $._invalid_priority_name,
    $._eof_declaration_colon,
    $._detached_pseudo_class_colon,
    $.eof_at_keyword_escape,
    $.eof_url_value,
    $.eof_string_value,
    $._eof_value_backslash,
    $._detached_import_supports_open,
    $._before_additional_import_sources,
    $.less_merge_property_name,
    $._blockless_nested_pseudo_name,
    $.glued_attribute_type_name,
    $.__error_recovery,
  ],

  inline: $ => [
    $._top_level_item,
    $._block_item,
  ],

  conflicts: $ => [
    // A slash may be a terminal delimiter or start a binary operation.
    [$._declaration_value, $.binary_expression],
    [$._function_argument_values, $.binary_expression],
    [$._opaque_prelude_component, $.parenthesized_value],
    [$._opaque_prelude_component, $.grid_value],
    [$._opaque_block_component, $.eof_container_query],
    // A later operand distinguishes numeric arithmetic from concatenation.
    [$._sass_range_variable, $._computed_query_part],
  ],

  rules: {
    stylesheet: $ => seq(repeat($._top_level_item), optional(choice(
      $.incomplete_selector,
      alias($.eof_top_level_declaration, $.eof_declaration_rule),
      $.eof_import_statement,
      $.eof_container_query,
      alias($.eof_supports_statement, $.eof_unknown_at_rule),
      alias($.eof_scope_statement, $.eof_unknown_at_rule),
      alias($.eof_layer_statement, $.eof_unknown_at_rule),
      alias($.eof_media_statement, $.eof_unknown_at_rule),
      alias($.eof_grouped_media_condition, $.eof_unknown_at_rule),
      alias($.eof_media_reference, $.eof_unknown_at_rule),
      $.eof_media_function_condition,
      alias($.eof_unclosed_theme_prefix, $.eof_unknown_at_rule),
      $.eof_unknown_at_rule,
      alias($._invalid_line_escape_at_rule, $.eof_unknown_at_rule),
      $.eof_declaration_rule,
      alias($.eof_rule_with_balanced_child, $.eof_declaration_rule),
      alias($.eof_nested_media_rule, $.eof_declaration_rule),
      $.eof_custom_property_rule,
      $.eof_string_rule,
      $.eof_at_keyword_escape,
      alias($._eof_value_backslash, $.eof_stray_backslash),
      alias($._stray_close_prelude, $.eof_unknown_at_rule),
    ))),

    // CSS discards a final bare selector at EOF. Keep the source token,
    // but don't synthesize a block or let it join the preceding rule.
    incomplete_selector: $ => $.selectors,

    // Keep a final declaration outside any rule as authored. In particular,
    // don't synthesize a semicolon or claim a selector followed by a block.
    eof_top_level_declaration: $ => seq(
      $._property_name, alias($._eof_declaration_colon, ':'), $._last_declaration_value,
    ),

    _top_level_item: $ => choice(
      $.html_comment_open,
      $.html_comment_close,
      $.empty_statement,
      alias($.template_value_variable, $.stylesheet_template_placeholder),
      $.declaration,
      $.sass_variable_declaration,
      $.rule_set,
      $.anonymous_nested_block,
      $.numeric_prefix_rule,
      alias($.bare_at_sign_block, $.at_rule),
      $.duplicate_class_dot_rule,
      $.invalid_line_escape_rule,
      $.stray_close_rule,
      alias($.invalid_line_escape_at_rule, $.at_rule),
      alias($.top_level_at_rule_with_stray_close, $.at_rule),
      $.malformed_media_rule_prefix,
      alias($.empty_pseudo_block, $.at_rule),
      $.phorge_print_rule,
      $.import_statement,
      alias($.multi_source_import, $.at_rule),
      alias($.adjacent_import_media_types, $.at_rule),
      alias($.import_block, $.at_rule),
      $.media_statement,
      $.starting_style_statement,
      $.custom_media_statement,
      alias($.custom_media_block, $.at_rule),
      alias($.empty_custom_media_statement, $.at_rule),
      $.custom_selector_statement,
      $.tailwind_custom_variant_statement,
      $.tailwind_theme_statement,
      $.tailwind_utility_statement,
      $.container_statement,
      alias($.empty_container_statement, $.at_rule),
      $.page_statement,
      $.font_face_statement,
      $.font_palette_values_statement,
      $.property_statement,
      alias($.property_extension, $.at_rule),
      $.view_transition_statement,
      $.counter_style_statement,
      $.position_try_statement,
      alias($.named_font_face_statement, $.at_rule),
      alias($.blockless_font_face_statement, $.at_rule),
      $.font_feature_values_statement,
      $.moz_document_statement,
      $.charset_statement,
      $.namespace_statement,
      $.layer_statement,
      alias($.layer_list_block, $.at_rule),
      alias($.layer_list_missing_entry, $.at_rule),
      $.scope_statement,
      $.keyframes_statement,
      alias($.parenthesized_keyframes_statement, $.at_rule),
      alias($.blockless_keyframes_statement, $.at_rule),
      $.custom_function_statement,
      $.supports_statement,
      $.at_rule,
      alias($.escaped_at_rule, $.at_rule),
    ),

    // Statements

    // CSS Syntax ignores CDO/CDC tokens at the top level, not their contents.
    html_comment_open: _ => '<!--',
    html_comment_close: _ => '-->',

    // Celerity expands `!print` selectors into print styles at build time.
    phorge_print_rule: $ => seq(
      choice(
        token(/!print[ \t\r\n\f]+/),
        seq($.selectors, token(/,[ \t\r\n\f]*!print[ \t\r\n\f]+/)),
      ),
      $.selectors,
      $.block,
    ),

    import_statement: $ => seq(
      $._import_prelude,
      ';',
    ),

    // A comma followed by another quoted source is not a media-list item.
    // Keep this preprocessor form intact rather than creating active imports.
    multi_source_import: $ => seq(
      alias(/@[iI][mM][pP][oO][rR][tT]/, '@import'),
      choice($.string_value, $.url_value, $.call_expression),
      $._before_additional_import_sources,
      repeat($._multi_source_import_modifier),
      repeat1(seq(',', $.string_value, repeat($._multi_source_import_modifier))),
      ';',
    ),

    _multi_source_import_modifier: $ => choice(
      $.identifier,
      $.escaped_value_identifier,
      seq('(', repeat($._opaque_block_component), ')'),
    ),

    // Obsolete media types still require separators. Do not supply them:
    // doing so could make a malformed import start loading its resource.
    adjacent_import_media_types: $ => seq(
      alias(/@[iI][mM][pP][oO][rR][tT]/, '@import'),
      choice($.string_value, $.url_value, $.call_expression),
      token(/(?:all|aural|braille|embossed|handheld|print|projection|screen|speech|tty|tv)(?:[ \t\r\n\f]+(?:all|aural|braille|embossed|handheld|print|projection|screen|speech|tty|tv))+/),
      ';',
    ),

    // A block cannot terminate an import. Keep it opaque instead of
    // inserting a semicolon that would activate the resource reference.
    import_block: $ => seq(
      $._import_prelude,
      '{', repeat($._opaque_block_component), '}',
    ),

    // CSS Syntax returns the pending at-rule when it reaches EOF. Limit
    // recovery to the stylesheet tail and keep the missing semicolon missing.
    eof_import_statement: $ => choice(
      $._import_prelude,
      // Share ordinary function-name tokens so complete imports retain their
      // normal lexer path. Only the string token can confirm physical EOF.
      seq(alias(/@[iI][mM][pP][oO][rR][tT]/, '@import'),
        optional(seq(choice($.identifier, $.escaped_value_identifier), token.immediate('('))),
        $.eof_string_value),
    ),

    _import_prelude: $ => seq(
      alias(/@[iI][mM][pP][oO][rR][tT]/, '@import'),
      choice($.string_value, $.url_value, $.call_expression),
      // Cascade 6 permits these modifiers in any order. Preserve authored
      // order, including repeated modifiers in recoverable input.
      repeat(choice($.import_layer_clause, $.import_supports_clause, $.import_scope_clause)),
      optional($.tailwind_import_source),
      optional($.import_media_list),
    ),

    import_media_list: $ => sep1(',', choice($._query, $.detached_import_media_function)),

    // Keep the missing conjunction between a media type and an adjacent
    // function. Require an attached opening parenthesis in the function so
    // valid `print and (...)` conditions still use the regular query grammar.
    detached_import_media_function: $ => seq(
      token(seq(/(?:[aA][lL][lL]|[pP][rR][iI][nN][tT]|[sS][cC][rR][eE][eE][nN]|[sS][pP][eE][eE][cC][hH])[ \t\r\n\f]+/, CSS_IDENTIFIER, '(')),
      repeat($._opaque_block_component), ')',
    ),

    // Tailwind's source() controls class discovery. It is not a media type;
    // only reserve the name when it is immediately followed by parentheses.
    tailwind_import_source: $ => seq(
      token('source('),
      choice($.string_value, 'none'),
      ')',
    ),

    import_layer_clause: $ => seq(alias(/[lL][aA][yY][eE][rR]/, 'layer'), optional(seq(
      token.immediate('('),
      $.layer_name,
      ')',
    ))),

    import_scope_clause: $ => choice(
      alias(/[sS][cC][oO][pP][eE]/, 'scope'),
      seq(token(/[sS][cC][oO][pP][eE]\(/), repeat1($._opaque_block_component), ')'),
    ),

    layer_name: $ => sep1('.', choice($.identifier, $.escaped_value_identifier)),

    _multiple_layer_names: $ => seq($.layer_name, ',', sep1(',', $.layer_name)),

    _layer_keyword: $ => alias(/@[lL][aA][yY][eE][rR]/, $.at_keyword),

    layer_statement: $ => seq($._layer_keyword, choice(
      seq(choice($.layer_name, $._multiple_layer_names), ';'),
      seq(optional($.layer_name), $.block),
    )),

    eof_layer_statement: $ => seq($._layer_keyword, optional($.layer_name), $._eof_opaque_block),

    // Layer name lists are only valid in statement form. Keep a balanced
    // block with that prelude opaque so its contents cannot be activated.
    layer_list_block: $ => seq(
      $._layer_keyword,
      $._multiple_layer_names,
      '{', repeat($._opaque_block_component), '}',
    ),

    // Keep the missing entry: dropping a comma can activate layer ordering.
    layer_list_missing_entry: $ => seq(
      $._layer_keyword,
      choice($.layer_name, $._multiple_layer_names), ',,', repeat($._opaque_prelude_component), ';',
    ),

    _scope_prelude: $ => seq(
      '@scope',
      optional($.scope_boundary),
      optional(seq(alias(/[tT][oO]/, 'to'), $.scope_boundary)),
    ),

    scope_statement: $ => seq($._scope_prelude, $.block),
    eof_scope_statement: $ => seq($._scope_prelude, $._eof_opaque_block),

    // Scope boundaries are emitted as opaque bytes. Do not require the
    // selector grammar to understand them or repair invalid selector syntax.
    scope_boundary: $ => seq('(', repeat($._opaque_block_component), ')'),

    import_supports_clause: $ => seq(
      alias(/[sS][uU][pP][pP][oO][rR][tT][sS]\(/, 'supports('),
      choice(
        seq(alias($.identifier, $.feature_name), ':', repeat1($._value)),
        $.computed_import_supports_declaration,
        $.priority_named_import_supports_declaration,
        $.detached_import_supports_function,
        alias(seq('(', $.priority_named_import_supports_declaration, ')'), $.priority_named_import_supports_declaration),
        $._query,
      ),
      ')',
    ),

    // A gap before '(' keeps this from being a CSS function token. Never
    // remove the gap and thereby change the import's support condition.
    detached_import_supports_function: $ => seq(
      $.identifier, $._detached_import_supports_open,
      repeat($._opaque_block_component),
      ')',
    ),

    // Some preprocessor inputs compute the property name. Keep the whole
    // declaration opaque rather than rewriting its operators or value.
    computed_import_supports_declaration: $ => seq(
      $._computed_query_concatenation,
      ':', repeat1($._opaque_prelude_component),
    ),

    // A priority token is not a property name. Preserve this malformed
    // condition verbatim so it does not become an active declaration test.
    priority_named_import_supports_declaration: $ => seq(
      /![iI][mM][pP][oO][rR][tT][aA][nN][tT]/,
      ':', repeat1($._opaque_prelude_component),
    ),

    _media_prelude: $ => seq(
      alias(/@[mM][eE][dD][iI][aA]/, '@media'),
      optional(sep1(',', choice($._media_list_item, $.media_type_without_conjunction, $.dangling_media_conjunction))),
    ),

    media_statement: $ => seq($._media_prelude, $.block),

    eof_media_statement: $ => seq($._media_prelude, $._eof_opaque_block),

    _media_list_item: $ => choice(
      $._query, $.bracketed_media_list_item, $.grouped_media_list_item, $.block_valued_media_feature,
      $.media_condition_literal_newline,
    ),

    // A literal backslash-n is an escaped identifier, not a line break.
    // Keep it as authored so we do not activate an invalid condition.
    media_condition_literal_newline: $ => seq(
      $._query,
      token(/\\n[ \t]+/),
      choice(alias(/[aA][nN][dD]/, 'and'), alias(/[oO][rR]/, 'or')),
      $._query,
    ),

    // Keep a balanced brace component inside the feature's parentheses,
    // rather than treating it as the body of the surrounding at-rule.
    block_valued_media_feature: $ => seq(
      '(', choice($.identifier, $.escaped_value_identifier), ':',
      '{', repeat($._opaque_block_component), '}', ')',
    ),

    // Keep the authored operator without inventing a right-hand condition.
    dangling_media_conjunction: $ => seq(
      $._query, choice(alias(/[aA][nN][dD]/, 'and'), alias(/[oO][rR]/, 'or')),
    ),

    // Keep commas inside this malformed item separate from list separators.
    bracketed_media_list_item: $ => seq('[', repeat($._opaque_block_component), ']'),

    // Square or brace components can also occur inside a general-enclosed
    // condition. Do not reinterpret their contents as features or selectors.
    grouped_media_list_item: $ => seq('(', choice(
      $.bracketed_media_list_item,
      seq('{', repeat($._opaque_block_component), '}'),
    ), repeat($._opaque_block_component), ')'),

    // An unfinished square or brace component inside a condition consumes
    // the rest of the stylesheet. Do not complete either delimiter.
    eof_grouped_media_condition: $ => seq(
      alias(/@[mM][eE][dD][iI][aA]/, '@media'),
      '(', choice('[', '{'), repeat($._opaque_block_component),
    ),

    // An open parenthesis around a bare reference can end the stylesheet.
    // Keep it separate from complete features and never synthesize `)`.
    eof_media_reference: $ => seq(
      alias(/@[mM][eE][dD][iI][aA]/, '@media'), '(',
      choice($.identifier, $.escaped_custom_media_name),
    ),

    // A function inside an open media condition can itself end at EOF.
    eof_media_function_condition: $ => seq(
      alias(/@[mM][eE][dD][iI][aA]/, '@media'), '(',
      choice($.identifier, $.escaped_value_identifier), token.immediate('('),
      repeat($._opaque_block_component),
    ),

    // A spaced parenthesis after a media type is neither a function call
    // nor a valid conjunction. Preserve the missing `and` as authored.
    media_type_without_conjunction: $ => seq(
      token(/(?:[aA][lL][lL]|[pP][rR][iI][nN][tT]|[sS][cC][rR][eE][eE][nN]|[sS][pP][eE][eE][cC][hH])[ \t\r\n\f]+\(/),
      repeat($._opaque_block_component), ')',
    ),

    starting_style_statement: $ => seq(
      alias(/@[sS][tT][aA][rR][tT][iI][nN][gG]-[sS][tT][yY][lL][eE]/, $.at_keyword),
      $.block,
    ),

    custom_media_statement: $ => seq(
      $._custom_media_keyword,
      choice(alias($.identifier, $.custom_media_name), $.escaped_custom_media_name),
      choice(
        seq(sep1(',', $._media_list_item), optional(alias(',', $.custom_media_trailing_comma))),
        $.invalid_custom_media_value,
      ),
      ';',
    ),

    // Keep a bare numeric value or a condition without its first operand
    // opaque. In `@custom-media screen and (...)` the missing operand is
    // really the missing alias; do not invent one or drop `and`.
    invalid_custom_media_value: $ => choice(
      $.integer_value,
      $.float_value,
      seq(/[aA][nN][dD]/, '(', repeat($._opaque_block_component), ')'),
    ),

    _custom_media_keyword: $ => alias(/@[cC][uU][sS][tT][oO][mM]-[mM][eE][dD][iI][aA]/, '@custom-media'),

    // Preserve a missing query, with or without an authored alias.
    empty_custom_media_statement: $ => seq(
      $._custom_media_keyword,
      optional(choice($.identifier, $.escaped_custom_media_name)),
      ';',
    ),

    // A balanced block is not a custom media statement. Preserve the whole
    // rule rather than turning it into an active semicolon-terminated alias.
    custom_media_block: $ => seq(
      $._custom_media_keyword,
      choice(alias($.identifier, $.custom_media_name), $.escaped_custom_media_name),
      sep1(',', $._media_list_item),
      '{', repeat($._opaque_block_component), '}',
    ),

    escaped_custom_media_name: $ => alias($.escaped_value_identifier, $.escaped_media_identifier),

    // This prelude ends at a semicolon rather than the opening brace that
    // the ordinary selector scanner uses to tell selectors from declarations.
    custom_selector_statement: $ => seq(
      '@custom-selector',
      token(/:--[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u),
      repeat1($._opaque_prelude_component),
      ';',
    ),

    _opaque_component_atom: $ => choice(
      token(/[^\s;{}()\[\]"'\\/]+/),
      $.escape_sequence,
      $.string_value,
      '/',
    ),

    _opaque_prelude_component: $ => choice(
      $._opaque_component_atom,
      seq('(', repeat($._opaque_block_component), ')'),
      seq('[', repeat($._opaque_block_component), ']'),
    ),

    // A nested simple block can contain balanced braces, but a top-level
    // brace must still end the prelude and begin the at-rule's body.
    _opaque_block_component: $ => choice(
      $._opaque_prelude_component,
      ';',
      seq('{', repeat($._opaque_block_component), '}'),
    ),

    // Tailwind's wildcard resets are not CSS custom property names. Keep
    // them in the theme dialect instead of legalizing them in ordinary rules.
    tailwind_theme_statement: $ => seq(
      '@theme',
      repeat($._opaque_prelude_component),
      '{', repeat($._opaque_block_component), '}',
    ),

    // The brace is part of the token so a closed prefix still takes the
    // ordinary theme path. Only recover this misspelling at stylesheet EOF.
    eof_unclosed_theme_prefix: $ => seq(
      '@theme',
      token(seq(/prefix\([ \t]*/, CSS_IDENTIFIER, /[ \t\r\n\f]*\{/)),
      repeat($._opaque_block_component), '}',
    ),

    // Functional utility names and --value() arguments can contain a
    // wildcard. Keep this dialect's balanced block intact.
    tailwind_utility_statement: $ => seq(
      '@utility',
      token(/-?[a-zA-Z][a-zA-Z0-9_-]*(?:-\*)?/),
      '{', repeat($._opaque_block_component), '}',
    ),

    container_statement: $ => seq(
      $._container_keyword,
      sep1(',', $._container_condition),
      $.block,
    ),

    // A container without a query is invalid. Keep its balanced body opaque
    // rather than adding a condition or treating the body as a separate rule.
    empty_container_statement: $ => seq(
      $._container_keyword,
      '{', repeat($._opaque_block_component), '}',
    ),

    _container_keyword: $ => alias(/@[cC][oO][nN][tT][aA][iI][nN][eE][rR]/, '@container'),

    // An unfinished final condition must not acquire a closing parenthesis or block.
    eof_container_query: $ => seq(
      $._container_keyword,
      $._container_query_function_open,
      repeat1($._opaque_prelude_component),
    ),

    // Each condition in the list can select a different named container.
    _container_condition: $ => choice(
      seq(optional(alias($.identifier, $.container_name)), choice($._query, $.infix_not_container_condition)),
      $.escaped_named_container_condition,
      $.class_shaped_container_condition,
    ),

    // This is not a feature name or a selector list. Keep the dot attached
    // so the invalid condition cannot turn into a valid feature query.
    class_shaped_container_condition: $ => seq(
      '(',
      token(seq('.', CSS_IDENTIFIER)),
      ')',
    ),

    // A hex escape can consume the first space after the name. Keep its
    // boundary with the condition intact instead of generating a separator.
    escaped_named_container_condition: $ => seq(
      $.escaped_value_identifier,
      choice($._query, $.infix_not_container_condition),
    ),

    // An infix `not` is not a container-query operator. Keep this malformed
    // condition separate so formatting cannot make it a valid query.
    infix_not_container_condition: $ => seq(
      choice($.feature_query, $.range_query, $.parenthesized_query),
      /[nN][oO][tT]/,
      choice($.feature_query, $.range_query, $.parenthesized_query),
    ),

    page_statement: $ => seq(
      alias(/@[pP][aA][gG][eE]/, '@page'),
      sep(',', $.page_selector),
      $.block,
    ),

    page_selector: $ => choice(
      seq($.identifier, repeat(seq(':', $.identifier))),
      repeat1(seq(':', $.identifier)),
    ),

    font_face_statement: $ => seq($.font_face_keyword, $.block),

    font_palette_values_statement: $ => seq(
      alias(/@[fF][oO][nN][tT]-[pP][aA][lL][eE][tT][tT][eE]-[vV][aA][lL][uU][eE][sS]/, $.at_keyword),
      $.font_palette_name,
      $.block,
    ),

    font_palette_name: _ => token(seq('--', repeat1(choice(/[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]/u, CSS_ESCAPE)))),

    property_statement: $ => seq(
      alias($.property_keyword, $.at_keyword),
      $.registered_property_name,
      $.block,
    ),

    registered_property_name: _ => token(choice(
      dashedName(),
      // Keep the Sass placeholder attached to the custom-property prefix.
      /--#\{\$[a-zA-Z_][a-zA-Z0-9_-]*\}/,
    )),
    property_keyword: _ => /@[pP][rR][oO][pP][eE][rR][tT][yY]/,

    // Preserve the previously supported PostCSS registration shorthand and
    // lists. Share the keyword so the standard handler cannot steal them.
    property_extension: $ => seq(
      $.property_keyword,
      choice(
        seq($.registered_property_name, repeat1($._opaque_prelude_component)),
        seq('--', repeat1($._opaque_prelude_component)),
      ),
      choice(';', $.block),
    ),

    view_transition_statement: $ => seq(
      alias(/@[vV][iI][eE][wW]-[tT][rR][aA][nN][sS][iI][tT][iI][oO][nN]/, $.at_keyword),
      $.block,
    ),

    counter_style_statement: $ => seq(
      alias(/@[cC][oO][uU][nN][tT][eE][rR]-[sS][tT][yY][lL][eE]/, $.at_keyword),
      alias(choice($.identifier, $.escaped_value_identifier), $.counter_style_name),
      $.block,
    ),

    position_try_statement: $ => seq(
      alias(/@[pP][oO][sS][iI][tT][iI][oO][nN]-[tT][rR][yY]/, $.at_keyword),
      alias($.font_palette_name, $.position_try_name),
      $.block,
    ),

    // Tooling can encounter named font-face blocks as passthrough input.
    // Keep their prelude and descriptors opaque, not as standard @font-face.
    named_font_face_statement: $ => seq($.font_face_keyword, $.identifier, $.block),

    // Do not turn a terminated font-face prelude into a descriptor block.
    blockless_font_face_statement: $ => seq($.font_face_keyword, optional($.identifier), ';'),

    font_face_keyword: _ => /@[fF][oO][nN][tT]-[fF][aA][cC][eE]/,

    font_feature_values_statement: $ => seq(
      alias(/@[fF][oO][nN][tT]-[fF][eE][aA][tT][uU][rR][eE]-[vV][aA][lL][uU][eE][sS]/, $.font_feature_values_keyword),
      $.font_family_list,
      $.block,
    ),

    font_family_list: $ => sep1(',', choice($.string_value, repeat1($.identifier))),

    page_margin_statement: $ => seq(
      alias(/@(?:(?:[tT][oO][pP]|[bB][oO][tT][tT][oO][mM])-(?:(?:[lL][eE][fF][tT]|[rR][iI][gG][hH][tT])(?:-[cC][oO][rR][nN][eE][rR])?|[cC][eE][nN][tT][eE][rR])|(?:[lL][eE][fF][tT]|[rR][iI][gG][hH][tT])-(?:[tT][oO][pP]|[mM][iI][dD][dD][lL][eE]|[bB][oO][tT][tT][oO][mM]))/, $.page_margin_keyword),
      $.block,
    ),

    moz_document_statement: $ => seq(
      '@-moz-document',
      $.document_conditions,
      $.block,
    ),

    document_conditions: $ => sep1(',', $._document_condition),

    _document_condition: $ => choice(
      $.url_value,
      alias(token(prec(1, seq(
        /url-prefix\([ \t\r\n\f]*/,
        repeat1(choice(UNQUOTED_URL_BODY, CSS_ESCAPE)),
        /[ \t\r\n\f]*\)/,
      ))), $.document_url_prefix),
      seq(choice('url', 'url-prefix', 'domain', 'regexp'), '(',
        optional(choice($.string_value, $.plain_value)), ')'),
      // Firefox accepts both an identifier and a string for media-document.
      // The enclosing condition stays opaque, including the authored case.
      seq(/[mM][eE][dD][iI][aA]-[dD][oO][cC][uU][mM][eE][nN][tT]/, token.immediate('('),
        choice($.identifier, $.string_value), ')'),
    ),

    // Even invalid variants must stay opaque: normalizing the prelude can
    // turn it into a byte-level encoding declaration.
    charset_statement: $ => seq(
      alias(/@[cC][hH][aA][rR][sS][eE][tT]/, $.at_keyword),
      repeat($._opaque_prelude_component),
      choice(';', seq('{', repeat($._opaque_block_component), '}')),
    ),

    namespace_statement: $ => seq(
      alias(/@[nN][aA][mM][eE][sS][pP][aA][cC][eE]/, $.at_keyword),
      choice(
        seq(optional($.namespace_name), choice($.string_value, $.call_expression, $.url_value)),
        // A prefix without a URI is invalid, but the query can keep this
        // whole statement opaque without inventing a namespace binding.
        optional($.namespace_name),
      ),
      ';',
    ),

    namespace_name: $ => choice($.identifier, $.escaped_value_identifier),

    keyframes_statement: $ => seq(
      alias(KEYFRAMES_KEYWORD, $.at_keyword),
      choice($._keyframes_name, $.scoped_keyframes_name),
      $.keyframe_block_list,
    ),

    // A bare parenthesized prelude is not a valid animation name. Match it
    // as an opaque at-rule so formatting cannot turn it into a valid name.
    parenthesized_keyframes_statement: $ => seq(
      alias(KEYFRAMES_KEYWORD, $.at_keyword),
      '(', repeat($._opaque_block_component), ')',
      $.block,
    ),

    // A semicolon-terminated keyframes rule does not define an animation.
    // Keep the terminator opaque rather than replacing it with a block.
    blockless_keyframes_statement: $ => seq(
      alias(KEYFRAMES_KEYWORD, $.at_keyword),
      optional(choice($._keyframes_name, $.scoped_keyframes_name)),
      ';',
    ),

    _keyframes_name: $ => choice(
      alias(choice($.identifier, $.escaped_value_identifier), $.keyframes_name),
      $.string_value,
    ),

    // CSS Modules supports both the function and prefix forms.
    scoped_keyframes_name: $ => choice(
      seq(/:(?:[lL][oO][cC][aA][lL]|[gG][lL][oO][bB][aA][lL])\(/, $._keyframes_name, ')'),
      seq(/:(?:[lL][oO][cC][aA][lL]|[gG][lL][oO][bB][aA][lL])[ \t\r\n\f]+/, $._keyframes_name),
    ),

    keyframe_block_list: $ => seq(
      '{',
      repeat(choice($.keyframe_block, $.anonymous_nested_block, $.empty_statement)),
      '}',
    ),

    keyframe_block: $ => seq(
      sep1(',', choice($.from, $.to, $.keyframe_percentage, $.keyframe_timeline_range,
        alias($.timeline_range_name, $.keyframe_range_without_offset),
        alias($.bracketed_media_list_item, $.bracketed_keyframe_item))),
      $.block,
    ),

    keyframe_timeline_range: $ => seq(
      $.timeline_range_name,
      $.keyframe_percentage,
    ),

    timeline_range_name: _ => choice(
      /[cC][oO][vV][eE][rR]/,
      /[cC][oO][nN][tT][aA][iI][nN]/,
      /[eE][nN][tT][rR][yY](?:-[cC][rR][oO][sS][sS][iI][nN][gG])?/,
      /[eE][xX][iI][tT](?:-[cC][rR][oO][sS][sS][iI][nN][gG])?/,
      /[sS][cC][rR][oO][lL][lL]/,
    ),

    keyframe_percentage: _ => token(/\+?(?:\d+|\d*\.\d+)(?:[eE][+-]?\d+)?%/),

    from: _ => /[fF][rR][oO][mM]/,
    to: _ => /[tT][oO]/,

    custom_function_statement: $ => seq($.custom_function_signature, $.block),

    custom_function_signature: $ => seq(
      // Only reserve the name after a CSS-style dashed identifier. This
      // avoids stealing unrelated @-rules that use the same keyword.
      token(prec(1, seq(
        /@[fF][uU][nN][cC][tT][iI][oO][nN][ \t\r\n\f]+--/,
        repeat1(choice(DASHED_NAME_BODY, CSS_ESCAPE)),
        '(',
      ))),
      optional(seq(sep1(',', $.custom_function_parameter), optional(','))),
      ')',
      optional(seq(/[rR][eE][tT][uU][rR][nN][sS]/, $._custom_function_type)),
    ),

    custom_function_parameter: $ => seq(
      token(seq('--', repeat1(choice(DASHED_NAME_BODY, CSS_ESCAPE)))),
      optional($._custom_function_type),
      // An explicit empty default is distinct from an omitted default.
      optional(seq(':', repeat(choice($._value, $.function_block_argument)))),
    ),

    _custom_function_type: $ => choice(
      /<[a-zA-Z][a-zA-Z0-9-]*>[+#]?/,
      $.type_syntax_value,
      // A single syntax component may also be a literal keyword.
      token(seq(CSS_IDENTIFIER, optional(/[+#]/))),
    ),

    supports_statement: $ => seq(
      alias(/@[sS][uU][pP][pP][oO][rR][tT][sS]/, $.at_keyword),
      $.supports_condition,
      $.block,
    ),

    // Keep an unfinished condition at stylesheet EOF without inserting a
    // missing parenthesis or creating an active conditional rule.
    eof_supports_statement: $ => seq(
      alias(/@[sS][uU][pP][pP][oO][rR][tT][sS]/, $.at_keyword),
      repeat($._opaque_prelude_component),
      $._open_supports_parenthesis,
    ),

    _open_supports_parenthesis: $ => seq('(', repeat($._opaque_block_component), optional($._open_supports_parenthesis)),

    // Conditions may contain general-enclosed component values. Unlike a
    // declaration, their content can include semicolons inside parentheses.
    supports_condition: $ => repeat1($._opaque_prelude_component),

    // Utility syntax includes syntax such as !p-0, h-4!, and w-1/2. These are
    // Tailwind class names, not CSS declaration values or arithmetic.
    tailwind_apply_statement: $ => seq('@apply', repeat1($._opaque_prelude_component), ';'),

    // CSS mixin applications can take a content block. Do not consume a
    // block as Tailwind utility syntax unless a dashed mixin name precedes it.
    mixin_apply_statement: $ => seq(
      token(/@[aA][pP][pP][lL][yY][ \t\r\n\f]+--[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u),
      optional(seq(token.immediate('('), repeat($._opaque_block_component), ')')),
      choice($.block, ';'),
    ),

    // A Less class mixin call ends in a semicolon, unlike a nested
    // selector. Keep its arguments opaque: commas and semicolons can
    // be distinct argument separators in Less.
    less_class_mixin_call: $ => seq(
      token(seq('.', CSS_IDENTIFIER, '(')),
      repeat($._opaque_block_component), ')', ';',
    ),

    tailwind_custom_variant_statement: $ => seq(
      '@custom-variant',
      $.identifier,
      choice(seq(repeat1($._opaque_prelude_component), ';'), $.block),
    ),

    // Unknown rules may use arbitrary component values, not just media queries
    // or declaration values. The formatter keeps the entire rule opaque.
    at_rule: $ => seq(
      $.at_keyword,
      repeat($._opaque_prelude_component),
      choice(';', $.block),
    ),

    // At stylesheet level an unmatched closing brace can be part of an
    // at-rule's prelude. Inside a block it must remain the block's closing token.
    top_level_at_rule_with_stray_close: $ => seq(
      $.at_keyword, repeat($._opaque_prelude_component), '}',
      repeat(choice('}', $._opaque_prelude_component)), ';',
    ),

    // Keep a simple prelude ending in a backslash and a line break opaque.
    // This is not an escaped identifier; deleting the break would change it.
    _invalid_line_escape_at_rule: _ => token(seq(
      '@', CSS_IDENTIFIER, optional(seq(/[ \t]+/, CSS_IDENTIFIER)),
      /[ \t]*\\(?:\r\n|[\r\n\f])/,
    )),

    invalid_line_escape_at_rule: $ => seq($._invalid_line_escape_at_rule, ';'),

    // A lone at-sign is a delimiter, not an at-keyword. Preserve its
    // balanced block without merging it with the next stylesheet item.
    bare_at_sign_block: $ => seq('@', '{', repeat($._opaque_block_component), '}'),

    // EOF can terminate multiple open blocks. Keep the unknown rule opaque
    // without inserting any of the missing closing braces.
    eof_unknown_at_rule: $ => prec.dynamic(-1, seq(
      $.at_keyword,
      repeat($._opaque_prelude_component),
      $._eof_opaque_block,
    )),

    _eof_opaque_block: $ => seq('{', repeat($._block_item), optional(choice(
      $.eof_unknown_at_rule,
      $.eof_layer_statement,
    ))),

    // Keep escaped keyword spellings. Their decoded names can correspond to
    // built-in or unknown at-rules, so preserve the prelude rather than
    // forcing it into the generic query grammar.
    escaped_at_rule: $ => seq(
      alias($.escaped_at_keyword, $.at_keyword),
      repeat($._opaque_prelude_component),
      choice(';', $.block),
    ),

    // Rule sets

    rule_set: $ => seq(
      $.selectors,
      choice($.block, $.inline_double_slash_block),
    ),

    // CSS doesn't recognize // as a comment, but preprocessors can. When
    // both interpretations disagree about a same-line closing brace, keep
    // this simple declaration-shaped block byte-for-byte.
    inline_double_slash_block: _ => token(/\{[ \t]*\/\/[ \t]*-?[A-Za-z_][A-Za-z0-9_-]*[ \t]*:[^;{}()\[\]"'\/\\\r\n\f]*;(?:[ \t]*-?[A-Za-z_][A-Za-z0-9_-]*[ \t]*:[^;{}()\[\]"'\/\\\r\n\f]*;)+[ \t]*\}/),

    // CSS ends an open block at stylesheet EOF. Accept a complete final
    // declaration here, without permitting a missing brace in nested rules.
    eof_declaration_rule: $ => seq(
      $.selectors, '{', repeat($._block_item), choice($.eof_declaration, $.declaration, $.custom_declaration),
    ),

    // A complete nested rule can be the last item in an open outer rule.
    // This alternative is available only at the end of the stylesheet.
    eof_rule_with_balanced_child: $ => seq(
      $.selectors, '{', repeat($._block_item), $.rule_set,
    ),

    // A final declaration in a nested media block can also end at EOF.
    // Keep both blocks open rather than synthesizing closing braces.
    eof_nested_media_rule: $ => seq(
      $.selectors, '{', repeat($._block_item),
      $._media_prelude, '{', repeat($._block_item), $.eof_declaration,
    ),

    // A number followed by a class cannot begin a selector. Keep the
    // discarded qualified rule intact rather than formatting it as a class.
    numeric_prefix_rule: $ => seq(
      token(/[0-9]+\.[A-Za-z_-]/),
      repeat($._opaque_prelude_component),
      '{', repeat($._opaque_block_component), '}',
    ),

    // A doubled class dot is not a class selector. Preserve the entire
    // qualified rule rather than dropping a dot or formatting its prelude.
    duplicate_class_dot_rule: $ => seq(
      token(/\.\.[A-Za-z_-]/),
      repeat($._opaque_prelude_component),
      '{', repeat($._opaque_block_component), '}',
    ),

    // A backslash followed by a newline is not a CSS escape. Keep the
    // discarded qualified rule opaque rather than attaching it to a selector.
    invalid_line_escape_rule: $ => seq(
      token(seq(
        optional(seq(choice(CSS_IDENTIFIER, CSS_BLOCK_COMMENT), repeat(choice(/[ \t]+/, CSS_BLOCK_COMMENT)))),
        /\\(?:\r\n|[\r\n\f])[ \t\r\n\f]*\{/,
      )),
      repeat($._opaque_block_component), '}',
    ),

    // At stylesheet level a stray closing brace can become part of the
    // following qualified rule's prelude. Keep that rule intact; deleting
    // the brace could make an otherwise discarded selector active.
    _stray_close_prelude: $ => seq(
      '}', repeat(choice('}', ';', $._opaque_prelude_component)),
    ),

    stray_close_rule: $ => seq(
      $._stray_close_prelude,
      '{', repeat($._opaque_block_component), '}',
    ),

    // At stylesheet level the declaration-like prefix and @media text form
    // one invalid qualified rule. Do not turn the latter into an active rule.
    malformed_media_rule_prefix: $ => seq(
      token(/-?[a-zA-Z_][a-zA-Z0-9_-]*[ \t]*:[ \t]*[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)[a-zA-Z]+[ \t]*,[ \t]*@[mM][eE][dD][iI][aA][ \t\r\n\f]+/),
      repeat1($._opaque_prelude_component),
      '{', repeat($._opaque_block_component), '}',
    ),

    // The legacy CSS Nesting proposal used an at-rule whose prelude was a
    // selector list, not the generic component list of an unknown at-rule.
    legacy_nest_statement: $ => seq('@nest', $.selectors, $.block),

    // Keep the trailing colon and any adjoining anonymous blocks opaque.
    // Removing the colon could make the first selector match.
    empty_pseudo_block: $ => prec.right(seq(
      token(seq(CSS_IDENTIFIER, ':', /[ \t\r\n\f]*\{/)),
      repeat($._opaque_block_component), '}',
      repeat(seq('{', repeat($._opaque_block_component), '}')),
    )),

    selectors: $ => sep1(',', $._selector),

    block: $ => seq(
      '{',
      repeat($._block_item),
      optional($._block_last_item),
      '}',
    ),

    _block_last_item: $ => choice(
      alias(choice($.last_declaration, $.last_custom_declaration), $.declaration),
      alias($.last_bare_property, $.bare_property),
      alias($._bare_descendant_block_item, $.bare_descendant_block_item),
      alias($._brace_valued_declaration, $.brace_valued_declaration),
      alias($._templated_dimension_declaration, $.templated_dimension_declaration),
      alias($._invalid_line_escape_declaration, $.invalid_line_escape_declaration),
      alias($._nameless_declaration, $.nameless_declaration),
      alias($._blockless_nested_pseudo, $.blockless_nested_pseudo),
    ),

    // An empty qualified-rule prelude is not a nested selector. Retain
    // the balanced block without promoting its contents to the outer rule.
    anonymous_nested_block: $ => seq('{', repeat($._opaque_block_component), '}'),

    // Experimental @private bodies can contain typed custom property names
    // such as `--size <length>`. Keep them local to the balanced at-rule.
    private_property_block: $ => seq(
      /@[pP][rR][iI][vV][aA][tT][eE]/,
      '{', repeat($._opaque_block_component), '}',
    ),

    _block_item: $ => choice(
      $.empty_statement,
      $.anonymous_nested_block,
      alias($.private_property_block, $.at_rule),
      $.orphan_important,
      $.slash_prefixed_declaration,
      $.dot_prefixed_declaration,
      $.digit_led_declaration,
      $.split_property_declaration,
      $.bare_property,
      $.bare_descendant_block_item,
      $.brace_valued_declaration,
      $.templated_dimension_declaration,
      $.bad_string_declaration,
      $.invalid_line_escape_declaration,
      $.nameless_declaration,
      $.blockless_nested_pseudo,
      $.declaration,
      $.sass_variable_declaration,
      alias($.custom_declaration, $.declaration),
      $.tailwind_apply_statement,
      $.mixin_apply_statement,
      $.less_class_mixin_call,
      $.tailwind_custom_variant_statement,
      $.tailwind_theme_statement,
      $.tailwind_utility_statement,
      $.rule_set,
      $.numeric_prefix_rule,
      $.duplicate_class_dot_rule,
      $.invalid_line_escape_rule,
      $.legacy_nest_statement,
      $.import_statement,
      alias($.import_block, $.at_rule),
      $.media_statement,
      $.starting_style_statement,
      $.custom_media_statement,
      alias($.custom_media_block, $.at_rule),
      alias($.empty_custom_media_statement, $.at_rule),
      $.container_statement,
      $.page_statement,
      $.font_face_statement,
      $.font_palette_values_statement,
      $.property_statement,
      alias($.property_extension, $.at_rule),
      $.view_transition_statement,
      $.counter_style_statement,
      $.position_try_statement,
      alias($.named_font_face_statement, $.at_rule),
      alias($.blockless_font_face_statement, $.at_rule),
      $.font_feature_values_statement,
      $.page_margin_statement,
      $.moz_document_statement,
      $.charset_statement,
      $.namespace_statement,
      $.layer_statement,
      alias($.layer_list_block, $.at_rule),
      alias($.layer_list_missing_entry, $.at_rule),
      $.scope_statement,
      $.keyframes_statement,
      alias($.parenthesized_keyframes_statement, $.at_rule),
      alias($.blockless_keyframes_statement, $.at_rule),
      $.custom_function_statement,
      $.supports_statement,
      $.at_rule,
      alias($.escaped_at_rule, $.at_rule),
    ),

    // A newline terminates a CSS bad-string token. An apparent closing
    // quote after a bare word then opens a second bad string: any semicolon
    // on that line is inside the string, not a declaration terminator.
    bad_string_declaration: _ => token(seq(
      /-?[a-zA-Z_][a-zA-Z0-9_-]*[ \t]*:[ \t]*/,
      badString(), optional(seq(/[ \t]*/, CSS_IDENTIFIER, /[ \t]*/, badString())), /[ \t]*;/,
    )),

    // Recover a simple, terminated invalid declaration without dropping its
    // leading delimiter. Leave compound values and comments to the parser.
    slash_prefixed_declaration: _ => token(/\/[ \t]*-?[A-Za-z_][A-Za-z0-9_-]*[ \t]*:[^;{}()\[\]"'\/\\\r\n\f]*;/),

    // A terminated, simple declaration with a glued dot-prefixed name is
    // not a class selector. Retain the dot instead of activating the name.
    dot_prefixed_declaration: _ => token(/\.-?[A-Za-z_][A-Za-z0-9_-]*[ \t]*:[^;{}()\[\]"'\/\\\r\n\f]*;/),

    // A dimension-shaped property name is not a standard CSS identifier.
    // Keep the complete invalid declaration, including its original name.
    digit_led_declaration: _ => token(/[0-9]+[A-Za-z_][A-Za-z0-9_-]*[ \t]*:[^;{}()\[\]"'\/\\\r\n\f]*;/),

    // Require a simple numeric value so this recovery cannot steal a nested
    // pseudo selector. Keep the authored colon and optional terminator.
    _nameless_declaration: _ => token(/:[ \t]*[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)(?:[a-zA-Z]+|%)?/),
    nameless_declaration: $ => seq($._nameless_declaration, ';'),

    // A bare identifier before a property name is not a separate item.
    // Keep the malformed declaration together, including its terminator.
    split_property_declaration: _ => token(/[A-Za-z_][A-Za-z0-9_-]*[ \t]*[\r\n\f][ \t\r\n\f]*-?[A-Za-z_][A-Za-z0-9_-]*[ \t]*:[^;{}()\[\]"'\/\\\r\n\f]*;/),

    // A name immediately before the block's close is an ignored item, not
    // a declaration. Do not add a colon or semicolon to it.
    bare_property: $ => seq($.identifier, ';'),
    last_bare_property: $ => $.identifier,

    // A descendant prelude stopped by `;` or `}` has no rule body.
    bare_descendant_block_item: $ => seq($._bare_descendant_block_item, ';'),
    _bare_descendant_block_item: $ => $.descendant_selector,

    // Sass variables are not CSS properties. Keep their values and flags
    // opaque and require an authored terminator to bound the declaration.
    sass_variable_declaration: $ => seq(
      choice($.postcss_range_variable, $._extended_sass_variable_name),
      ':', repeat($._opaque_prelude_component), ';',
    ),

    // Recovery is local to declaration names: a plus or dot elsewhere can
    // be an operator or a namespace separator.
    _extended_sass_variable_name: _ => token(/\$[A-Za-z_][A-Za-z0-9_-]*(?:\+|\.[A-Za-z_][A-Za-z0-9_-]*)/),

    // Selectors

    _selector: $ => choice(
      $.universal_selector,
      // Share the star-prefixed token with legacy declarations. Inserting a
      // space here would turn a malformed compound into a descendant.
      alias($.legacy_star_property, $.glued_universal_type_selector),
      alias($.identifier, $.tag_name),
      alias($.escaped_value_identifier, $.escaped_type_name),
      $.class_selector,
      $.detached_class_selector,
      $.suffixed_nesting_selector,
      $.escaped_suffixed_nesting_selector,
      $.sass_placeholder_selector,
      $.nesting_selector,
      $.pseudo_class_selector,
      $.detached_pseudo_class_selector,
      $.pseudo_element_selector,
      $.id_selector,
      $.attribute_selector,
      $.invalid_line_escape_attribute_selector,
      $.unquoted_brace_attribute_selector,
      $.string_value,
      $.child_selector,
      $.descendant_selector,
      $.sibling_selector,
      $.adjacent_sibling_selector,
      $.namespace_selector,
      $.column_selector,
    ),

    nesting_selector: $ => prec(1, seq(optional($._selector), '&')),

    // Keep adjacent name or universal tokens together, whether preprocessor
    // suffixes or invalid native CSS. A space would create a descendant.
    // After substitution a digit can continue the parent identifier, even
    // though it cannot start a standalone CSS identifier.
    suffixed_nesting_selector: _ => token(seq('&', choice(DASHED_NAME_BODY, '*'))),

    escaped_suffixed_nesting_selector: _ => token(seq(
      '&', optional(BEFORE_IDENTIFIER_ESCAPE), CSS_ESCAPE, repeat(choice(DASHED_NAME_BODY, CSS_ESCAPE)),
    )),

    // This Sass/PostCSS selector is not an active class in plain CSS.
    sass_placeholder_selector: $ => seq(optional($._selector), $.sass_placeholder_name),

    sass_placeholder_name: _ => token(seq('%', CSS_IDENTIFIER)),

    universal_selector: _ => '*',

    class_selector: $ => prec(1, seq(
      optional($._selector),
      choice(alias(token(seq('.', CSS_IDENTIFIER)), $.class_name), $.escaped_class_name),
    )),

    // A gap after the dot is invalid CSS. Keeping it within an opaque token
    // prevents the formatter from making the class (and selector list) active.
    detached_class_selector: $ => seq(optional($._selector), $.detached_class_name),
    detached_class_name: _ => token(seq('.', /[ \t]+/, CSS_IDENTIFIER)),

    escaped_class_name: _ => token(prec(1, seq(
      '.',
      optional(choice('-', CSS_IDENTIFIER)),
      CSS_ESCAPE,
      repeat(choice(/[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u, CSS_ESCAPE)),
    ))),

    pseudo_class_selector: $ => seq(
      optional($._selector),
      alias($._pseudo_class_selector_colon, ':'),
      choice(
        // Either a specific pseudo-class that can only accept a selector…
        seq(
          alias(
            /[hH][aA][sS]|[nN][oO][tT]|[iI][sS]|[wW][hH][eE][rR][eE]|[hH][oO][sS][tT]-[cC][oO][nN][tT][eE][xX][tT]/,
            $.class_name,
          ),
          // A bare functional name remains invalid CSS. Keep its spelling
          // without inventing a selector argument list.
          optional(choice(
            alias($.pseudo_class_with_selector_arguments, $.arguments),
            $.malformed_pseudo_class_arguments,
          )),
        ),

        // Unlike the other selector-only forms, :host is also valid bare.
        seq(
          alias(/[hH][oO][sS][tT]/, $.class_name),
          optional(alias($.pseudo_class_with_selector_arguments, $.arguments)),
        ),

        // …or an `nth-child` or `nth-last-child` selector (which can
        // optionally accept a selector)…
        $._nth_child_pseudo_class_selector,
        seq(
          alias(/[nN][tT][hH]-(?:[lL][aA][sS][tT]-)?[oO][fF]-[tT][yY][pP][eE]/, $.class_name),
          optional(alias($.pseudo_class_nth_type_arguments, $.arguments)),
        ),

        seq(alias(/[sS][tT][aA][tT][eE]/, $.class_name), optional($.state_arguments)),

        // ICSS consumes the request separately from the CSS selector grammar.
        seq(alias('import', $.class_name), optional(alias($.escaped_pseudo_class_arguments, $.arguments))),

        // The decoded name can refer to any pseudo-class. Keep its balanced
        // component values rather than guessing an argument grammar.
        seq($.escaped_pseudo_class_name, optional($.escaped_pseudo_class_arguments)),

        // …or any other pseudo-class (for which we'll allow a more diverse set
        // of arguments).
        seq(
          $.class_name,
          optional(alias($.pseudo_class_arguments, $.arguments)),
        ),
      ),
    ),

    // Keep a separated name after a colon invalid. This suffix belongs to
    // a selector, not a declaration or an ordinary pseudo-class.
    detached_pseudo_class_selector: $ => seq(
      $._selector,
      $._detached_pseudo_class_colon,
      token.immediate(seq(/[ \t]+/, CSS_IDENTIFIER)),
      optional($.escaped_pseudo_class_arguments),
    ),

    // A stray colon before a balanced argument list invalidates the selector.
    // Recognize the typo without treating it as an ordinary function call.
    malformed_pseudo_class_arguments: $ => seq(
      token.immediate(':('),
      repeat($._opaque_block_component),
      ')',
    ),

    escaped_pseudo_class_name: _ => token(prec(1, seq(
      optional(choice('-', CSS_IDENTIFIER)),
      CSS_ESCAPE,
      repeat(choice(/[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u, CSS_ESCAPE)),
    ))),

    escaped_pseudo_class_arguments: $ => seq(
      token.immediate('('),
      repeat($._opaque_block_component),
      ')',
    ),

    // Only `nth-child`/`nth-last-child`, not `nth-of-type`/`nth-last-of-type`,
    // allows an optional filtering selector as a parameter.
    _nth_child_pseudo_class_selector: $ => seq(
      alias(
        /[nN][tT][hH]-(?:[lL][aA][sS][tT]-)?[cC][hH][iI][lL][dD]/,
        $.class_name,
      ),
      // Keep a bare name as written, even though a browser ignores this selector.
      optional(choice(alias($.pseudo_class_nth_child_arguments, $.arguments), $.gtk_nth_child_arguments)),
    ),

    // GTK stylesheets use these literal states, not An+B expressions or
    // filtering selectors. Keep their argument spelling as authored.
    gtk_nth_child_arguments: _ => token.immediate(/\([ \t]*(?:first|last)[ \t]*\)/),

    pseudo_element_selector: $ => seq(
      optional($._selector),
      choice(
        $.qt_negated_subcontrol_states,
        seq(
          alias(token(seq('::', /[cC][uU][eE](?:-[rR][eE][gG][iI][oO][nN])?|[sS][lL][oO][tT][tT][eE][dD]/)), $.tag_name),
          optional(alias($.pseudo_class_with_selector_arguments, $.arguments)),
        ),
        seq(
          alias(token(seq('::', CSS_IDENTIFIER)), $.tag_name),
          optional($.pseudo_element_arguments),
        ),
        seq($.escaped_pseudo_element_name, optional($.pseudo_element_arguments)),
      ),
    ),

    // Qt permits :!state on these subcontrols. Keep the whole suffix
    // together; a generic :! token could compete with property priorities.
    qt_negated_subcontrol_states: _ => token(/::(?:tab|item)(?::[a-zA-Z_-][a-zA-Z0-9_-]*)*:![a-zA-Z_-][a-zA-Z0-9_-]*(?::!?[a-zA-Z_-][a-zA-Z0-9_-]*)*/),

    escaped_pseudo_element_name: _ => token(prec(1, seq(
      '::',
      optional(choice('-', CSS_IDENTIFIER)),
      CSS_ESCAPE,
      repeat(choice(/[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u, CSS_ESCAPE)),
    ))),

    id_selector: $ => seq(
      optional($._selector),
      choice(
        alias(token(seq('#', CSS_IDENTIFIER)), $.id_name),
        $.escaped_id_name,
        $.numeric_hash_selector,
      ),
    ),

    // A digit-leading hash is a single token, but it is not an ID selector.
    // Preserve its spelling rather than escaping the digit or splitting it.
    numeric_hash_selector: _ => token(seq(/#-?[0-9]/, repeat(choice(DASHED_NAME_BODY, CSS_ESCAPE)))),

    // A hash and its name are one CSS token, even inside forgiving lists.
    escaped_id_name: _ => token(prec(1, seq(
      '#',
      optional(choice('-', CSS_IDENTIFIER)),
      CSS_ESCAPE,
      repeat(choice(/[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u, CSS_ESCAPE)),
    ))),

    attribute_selector: $ => seq(
      optional($._selector),
      token(prec(1, '[')),
      alias($._attribute_selector_name, $.attribute_name),
      optional(seq(
        choice('=', '~=', '^=', '|=', '*=', '$='),
        choice($._value, $.escaped_attribute_value,
          alias($._colon_prefixed_attribute_component, $.colon_prefixed_attribute_value)),
        optional(choice($.attribute_modifier, $.escaped_attribute_modifier)),
      )),
      ']',
      // A space here would turn a malformed compound into a descendant.
      optional($.glued_attribute_type_name),
    ),

    attribute_modifier: _ => /[iIsS]/,

    // Escaping a colon in the name or quoting it in the value would turn
    // this malformed selector into one that can match.
    _colon_prefixed_attribute_component: _ => token(seq(':', CSS_IDENTIFIER)),

    // Preserve an invalid escape in an unquoted attribute value. Start the
    // token at '[' so it cannot absorb whitespace in ordinary value states.
    invalid_line_escape_attribute_selector: $ => seq(
      optional($._selector),
      $.invalid_line_escape_attribute,
    ),

    invalid_line_escape_attribute: _ => token(prec(2, seq(
      '[', /[ \t]*/, CSS_IDENTIFIER, /[ \t]*/,
      choice('=', '~=', '^=', '|=', '*=', '$='), /[ \t]*/, optional(CSS_IDENTIFIER),
      /\\(?:\r\n|[\r\n\f])[ \t\r\n\f]*\]/,
    ))),

    unquoted_brace_attribute_selector: $ => seq(optional($._selector), $.unquoted_brace_attribute),

    // Keep a bare brace invalid rather than quoting it into a matching value.
    unquoted_brace_attribute: _ => token(prec(2, seq(
      '[', /[ \t]*/, CSS_IDENTIFIER, /[ \t]*/,
      choice('=', '~=', '^=', '|=', '*=', '$='), /[ \t]*/, '{', /[ \t]*/, ']',
    ))),
    escaped_attribute_modifier: _ => token(/\\(?:[iIsS]|0{0,4}(?:49|69|53|73)(?:\r\n|[ \t\r\n\f])?)/),

    // An escape and its optional hexadecimal terminator are part of one
    // identifier. Do not let generic value spacing split the token.
    escaped_attribute_value: _ => token(prec(1, seq(
      /[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]*/u,
      CSS_ESCAPE,
      repeat(choice(
        /[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u,
        CSS_ESCAPE,
      )),
    ))),

    // A qualified attribute name is not a selector expression. In particular,
    // whitespace before *= must not be consumed as a descendant combinator.
    _attribute_selector_name: $ => seq(
      optional(seq(optional(choice($._attribute_name_component, '*')), '|')),
      $._attribute_name_component,
    ),

    _attribute_name_component: $ => choice(
      $.identifier,
      alias($.escaped_value_identifier, $.escaped_attribute_name),
      alias($._colon_prefixed_attribute_component, $.colon_prefixed_attribute_name),
    ),

    child_selector: $ => prec.left(seq(optional($._selector), '>', $._selector)),

    descendant_selector: $ => prec.left(seq($._selector, $._descendant_operator, $._selector)),

    sibling_selector: $ => prec.left(seq(optional($._selector), '~', $._selector)),

    adjacent_sibling_selector: $ => prec.left(seq(optional($._selector), '+', $._selector)),

    namespace_selector: $ => prec.left(seq(optional($._selector), '|', $._selector)),

    column_selector: $ => prec.left(seq(optional($._selector), '||', $._selector)),

    pseudo_class_arguments: $ => seq(
      token.immediate('('),
      sep(',', choice($._selector, repeat1($._value))),
      ')',
    ),

    state_arguments: $ => seq(
      token.immediate('('),
      choice($.identifier, alias($.escaped_attribute_value, $.escaped_state_name)),
      ')',
    ),

    pseudo_class_with_selector_arguments: $ => seq(
      token.immediate('('),
      sep(',', $._selector),
      ')',
    ),

    pseudo_class_nth_child_arguments: $ => prec(-1, seq(
      token.immediate('('),
      $._nth_index,
      optional(
        seq(
          alias(/[oO][fF]/, $.nth_filter_keyword),
          sep1(',', $._selector),
        ),
      ),
      ')',
    )),

    pseudo_class_nth_type_arguments: $ => prec(-1, seq(
      token.immediate('('),
      $._nth_index,
      ')',
    )),

    _nth_index: $ => choice(
      alias(/[eE][vV][eE][nN]/, $.plain_value),
      alias(/[oO][dD][dD]/, $.plain_value),
      $.integer_value,
      alias($._nth_functional_notation, $.plain_value),
      alias($._detached_nth_sign, $.plain_value),
    ),

    // Keep An+B notation as a unit in all four positional pseudo-classes.
    _nth_functional_notation: _ => /[+-]?(?:\d+)?[nN](?:[ \t\r\n\f]*[+-][ \t\r\n\f]*\d+)?/,

    // Joining a detached sign could activate an invalid selector. Limit this
    // recovery to one line so embedded CSS cannot reindent the opaque token.
    _detached_nth_sign: _ => /[+-][ \t]+(?:(?:\d+)?[nN](?:[ \t]*[+-][ \t]*\d+)?|\d+|[oO][dD][dD]|[eE][vV][eE][nN])/,

    pseudo_element_arguments: $ => seq(
      token.immediate('('),
      repeat($._opaque_block_component),
      ')',
    ),

    // Declarations

    empty_statement: _ => ';',

    // These fragments do not set a valid priority. Preserve, rather than
    // deleting them or moving a priority marker onto a nearby declaration.
    orphan_important: $ => seq($.important, ';'),
    invalid_priority: $ => seq('!', optional(seq(optional($.priority_gap), $._invalid_priority_name))),

    // Keep the legacy prefix attached to its property name. A separated
    // universal selector is still parsed as a selector, not a property.
    legacy_star_property: _ => /\*[-_a-zA-Z][-_a-zA-Z0-9]*/,

    _property_name: $ => choice(
      alias(choice($.identifier, $.legacy_star_property, $._spaced_star_property), $.property_name),
      alias($.escaped_value_identifier, $.escaped_property_name),
      $.legacy_prefixed_property,
      $.less_merge_property_name,
      $.simple_vars_property_name,
    ),

    // PostCSS simple-vars can substitute a name or a glued part of one.
    simple_vars_property_name: _ => token(seq(
      optional(CSS_IDENTIFIER), /\$\([a-zA-Z_][a-zA-Z0-9_-]*\)/, /[a-zA-Z0-9_-]*/,
    )),

    _declaration_value: $ => choice(
      $._value, $.hash_delimiter, $.tilde_delimiter, $.simple_vars_substitution,
      $.selector_shaped_declaration_value, $.comment_separated_at_value, $.invalid_line_escape_url,
      $.invalid_spaced_url, $.invalid_parenthesized_url, $.detached_percentage_value,
    ),

    // A number and a separated percent are two tokens, not a percentage.
    detached_percentage_value: _ => token(/[+-]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)[ \t]+%/),

    // An unescaped opening parenthesis makes this a bad URL token; the
    // first unescaped closing parenthesis ends it, not a balanced pair.
    // Keep an immediately following stray closer in the same opaque span.
    invalid_parenthesized_url: _ => token(prec(1, seq(
      URL_NAME, /\([ \t]*/,
      repeat(choice(UNQUOTED_URL_BODY, CSS_ESCAPE)),
      '(', repeat(choice(UNQUOTED_URL_BODY, CSS_ESCAPE, /[ \t(]+/)), ')', optional(')'),
    ))),

    // An unescaped gap inside an unquoted URL makes it a bad URL token.
    // Leave escaped paths to the ordinary URL lexer to avoid claiming hex
    // escapes that legitimately use whitespace as their terminator.
    invalid_spaced_url: _ => token(prec(1, seq(
      URL_NAME, /\([ \t\r\n\f]*/,
      UNQUOTED_URL_BODY,
      repeat1(seq(/[ \t\r\n\f]+/, UNQUOTED_URL_BODY)),
      /[ \t\r\n\f]*\)/,
    ))),

    // A backslash-newline is invalid in an unquoted URL. Retain the bad
    // token through its closing parenthesis without repairing the escape.
    invalid_line_escape_url: _ => token(prec(1, seq(
      URL_NAME, /\([ \t\r\n\f]*/,
      repeat(choice(UNQUOTED_URL_BODY, CSS_ESCAPE)),
      /\\(?:\r\n|[\r\n\f])[ \t\r\n\f]*/,
      repeat(choice(UNQUOTED_URL_BODY, CSS_ESCAPE)),
      /[ \t\r\n\f]*\)/,
    ))),

    // A comment between `@` and a name prevents an at-keyword token.
    // Keep this spelling together, including the authored comment bytes.
    comment_separated_at_value: _ => token(seq(
      '@', repeat1(/\/\*(?:[^*]|\*+[^*/])*\*+\//), CSS_IDENTIFIER,
    )),

    // Require the opening brace in the prefix token so a pseudo-class such
    // as b:hover cannot be consumed as a declaration before its block.
    _brace_valued_declaration: $ => seq(
      token(seq(CSS_IDENTIFIER, /[ \t\r\n\f]*:[ \t\r\n\f]*(?:[+-]?(?:[0-9]*\.[0-9]+|[0-9]+)[ \t\r\n\f]+)?\{/)),
      repeat($._opaque_block_component),
      '}',
    ),

    brace_valued_declaration: $ => seq($._brace_valued_declaration, ';'),

    // A simple template placeholder can supply the number of a dimension.
    // Include the property prefix so it wins over the brace-valued header.
    _templated_dimension_declaration: _ => token(seq(
      CSS_IDENTIFIER, /[ \t]*:[ \t]*/,
      /\{\{[ \t]*[a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*[ \t]*\}\}/,
      choice(CSS_IDENTIFIER, '%'),
    )),

    templated_dimension_declaration: $ => seq($._templated_dimension_declaration, ';'),

    // A bare backslash before a line break is not a CSS escape. Retain the
    // break and value together so formatting cannot turn it into one.
    _invalid_line_escape_declaration: _ => token(seq(
      CSS_IDENTIFIER, /[ \t]*:[ \t]*/, optional(CSS_IDENTIFIER), /[ \t]*\\(?:\r\n|[\r\n\f])/,
      optional(/[ \t]*![ \t]*[iI][mM][pP][oO][rR][tT][aA][nN][tT]/),
    )),

    invalid_line_escape_declaration: $ => seq($._invalid_line_escape_declaration, ';'),

    // Preserve a discarded nested selector without inventing a rule body.
    _blockless_nested_pseudo: $ => seq(
      $._blockless_nested_pseudo_name,
      token.immediate('('), repeat($._opaque_block_component), ')',
    ),

    blockless_nested_pseudo: $ => seq($._blockless_nested_pseudo, ';'),

    // Keep this recovery local to declaration values, not function arguments
    // or arithmetic. The child combinator is literal value data here.
    selector_shaped_declaration_value: _ => token(seq(
      '.', CSS_IDENTIFIER, /[ \t]*>[ \t]*/, CSS_IDENTIFIER,
    )),

    // The preprocessor distinguishes an attached suffix from a separate
    // value. Give the substitution and any attached suffix one token.
    simple_vars_substitution: _ => token(choice(
      /@@[a-zA-Z_][a-zA-Z0-9_-]*/,
      /(?:\${1,2}|@@)\([a-zA-Z_][a-zA-Z0-9_-]*\)[a-zA-Z0-9_-]*/,
    )),

    tilde_delimiter: _ => '~',

    // A standalone asterisk is a delimiter, not a multiplication operator.
    asterisk_delimiter: _ => '*',

    // A leading plus is a delimiter when it does not start a signed number.
    // Keep it separate from binary operators, which occur after an operand.
    leading_plus_delimiter: _ => '+',

    // In a style block a dashed declaration can contain arbitrary balanced
    // component values, including braces that do not begin a nested rule.
    _custom_property_prefix: _ => token(prec(1, seq(dashedName(), /[ \t\r\n\f]*:/))),

    _custom_declaration_value: $ => choice(
      $._opaque_component_atom,
      $._bad_custom_string,
      seq('(', repeat($._custom_block_component), ')'),
      seq('[', repeat($._custom_block_component), ']'),
      seq('{', repeat($._custom_block_component), '}'),
    ),

    _custom_block_component: $ => choice(
      $._custom_declaration_value,
      ';',
    ),

    // Keep the unescaped line break that ends the bad string in the opaque
    // custom value. Without it, layout could extend the string or close it.
    _bad_custom_string: _ => token(badString()),

    // Preserve stray closers at the value level without consuming the rule's
    // closing brace or changing which tokens close nested component blocks.
    _custom_property_component: $ => choice($._custom_declaration_value, ')', ']'),

    custom_declaration: $ => seq(
      $._custom_property_prefix,
      repeat($._custom_property_component),
      ';',
    ),

    last_custom_declaration: $ => seq(
      $._custom_property_prefix,
      repeat($._custom_property_component),
      optional($.trailing_declaration_space),
    ),

    // Only at stylesheet EOF: the rule can end inside the custom property's
    // value or after a balanced value. Don't add a closer or reindent the value.
    eof_custom_property_rule: $ => prec.dynamic(-1, seq(
      $.selectors, '{', repeat($._block_item),
      $._custom_property_prefix, choice(
        repeat1($._custom_property_component),
        seq(repeat($._custom_property_component), choice($._eof_custom_property_block, $._eof_value_backslash)),
      ),
    )),

    _eof_custom_property_block: $ => choice(
      ...[['(', ']', '}'], ['[', ')', '}'], ['{', ')', ']']].map(([open, ...wrongClosers]) => seq(
        open, repeat($._custom_block_component),
        // In an open simple block, nonmatching closers are component values.
        // Branch only at the first mismatch; balanced values keep their grammar.
        optional(seq(choice(...wrongClosers), repeat(choice($._custom_block_component, ...wrongClosers)))),
        optional(choice($._eof_custom_property_block, $._eof_value_backslash, $.eof_string_value)),
      )),
    ),

    eof_string_rule: $ => prec.dynamic(-1, seq(
      $.selectors, '{', repeat($._block_item),
      choice(
        seq($._property_name, alias($._eof_declaration_colon, ':')),
        seq($._custom_property_prefix, repeat($._custom_property_component)),
      ),
      $.eof_string_value,
    )),

    declaration: $ => seq(
      $._property_name,
      ':',
      // Keep the empty first field instead of repairing a malformed value.
      optional(','),
      choice($.asterisk_delimiter, seq(
        choice($._declaration_value, repeat1($.leading_plus_delimiter)),
        repeat(seq(optional(','), $._declaration_value)),
        // Keep the empty final field rather than silently repairing the value.
        optional(choice(',', $.trailing_slash)),
      )),
      optional(choice($.important, $.invalid_priority)),
      ';',
    ),

    _last_declaration_value: $ => seq(
      optional(','),
      choice($.asterisk_delimiter, seq(
        choice($._declaration_value, repeat1($.leading_plus_delimiter)),
        repeat(seq(optional(','), $._declaration_value)),
        optional(choice(',', $.trailing_slash)),
      )),
      optional(choice($.important, $.invalid_priority)),
      optional($.trailing_declaration_space),
    ),

    last_declaration: $ => prec(1, seq($._property_name, ':', $._last_declaration_value)),

    eof_declaration: $ => seq(
      $._property_name, alias($._eof_declaration_colon, ':'), choice($._last_declaration_value, $.eof_url_value),
    ),

    trailing_slash: _ => '/',

    important: $ => seq('!', optional($.priority_gap), choice(
      alias(/[iI][mM][pP][oO][rR][tT][aA][nN][tT]/, $.important_keyword),
      alias($._escaped_important_keyword, $.important_keyword),
    )),

    // Media queries

    _query: $ => choice(
      alias($.identifier, $.keyword_query),
      $.escaped_custom_media_name,
      $.feature_query,
      $.computed_feature_query,
      $.range_query,
      $.binary_query,
      $.unary_query,
      $.container_query_function,
      $.mozilla_preference_query,
      $.general_enclosed_query,
      $.parenthesized_general_enclosed_query,
      $.parenthesized_query,
    ),

    feature_query: $ => seq(
      '(',
      alias(choice($.identifier, $.escaped_value_identifier), $.feature_name),
      ':',
      repeat1($._value),
      repeat(seq(',', repeat1($._value))),
      ')',
    ),

    // Preprocessors can compute a feature name. Keep its components opaque
    // rather than treating the + as ordinary CSS arithmetic.
    computed_feature_query: $ => seq(
      '(',
      choice(
        $.general_enclosed_query,
        $._computed_query_concatenation,
      ),
      ':', repeat1($._opaque_prelude_component), ')',
    ),

    container_query_function: $ => seq(
      $._container_query_function_open,
      // Style and scroll-state conditions can be nested and combined. Keep
      // their balanced component values as authored, including custom values.
      repeat1($._opaque_block_component),
      ')',
    ),

    _container_query_function_open: _ => token(/[sS](?:[cC][rR][oO][lL][lL]-[sS][tT][aA][tT][eE]|[tT][yY][lL][eE])\(/),

    mozilla_preference_query: $ => seq(
      // The same name may appear as a feature before a colon. Only match
      // this token when the opening parenthesis is part of the function.
      token(/-moz-(?:bool-)?pref\(/),
      $.string_value,
      optional(seq(',', $._value)),
      ')',
    ),

    // Keep balanced query operands such as selector() opaque. The rule
    // selector scanner expects a following block; feature tests have none.
    // Future functions use the same general-enclosed form.
    general_enclosed_query: $ => seq(
      choice($.identifier, $.escaped_value_identifier),
      token.immediate('('),
      repeat($._opaque_block_component),
      ')',
    ),

    // An identifier-led parenthesized query can be opaque. Only fall back
    // here when a second name follows, not at a feature colon or comparison.
    parenthesized_general_enclosed_query: $ => prec.dynamic(-1, seq(
      '(',
      choice($.identifier, $.escaped_value_identifier),
      choice($.identifier, $.escaped_value_identifier),
      repeat($._opaque_block_component),
      ')',
    )),

    range_query: $ => seq(
      '(',
      $._range_operand,
      $._range_comparison,
      $._range_operand,
      optional(seq($._range_comparison, $._range_operand)),
      ')',
    ),

    // The general plain-value token would swallow an adjacent comparison.
    _range_operand: $ => choice(
      $.identifier, $.escaped_value_identifier, $._range_numeric_operand,
      $.range_ratio, $.postcss_range_variable, $.computed_range_operand,
      $.parenthesized_range_operand,
    ),

    // Preserve grouping in preprocessor range operands; don't promote an
    // otherwise invalid CSS comparison by removing these parentheses.
    parenthesized_range_operand: $ => seq('(', choice(
      $.integer_value, $.float_value, $.parenthesized_range_operand,
    ), ')'),

    // Keep preprocessor concatenation and interpolation local to comparisons.
    computed_range_operand: $ => choice(
      $.string_value,
      $._query_variable_interpolation,
      $._computed_query_concatenation,
      $._qualified_range_variable,
      seq(choice('+', '-'), $._sass_range_variable),
      seq($._sass_range_variable, choice('+', '-'), $._range_numeric_operand),
      seq($._range_numeric_operand, choice('+', '-'), $._sass_range_variable),
    ),

    _sass_range_variable: $ => choice($.postcss_range_variable, $._qualified_range_variable),

    _qualified_range_variable: _ => token(seq(CSS_IDENTIFIER, /\.\$[a-zA-Z_][a-zA-Z0-9_-]*/)),

    _computed_query_concatenation: $ => seq(
      $._computed_query_part, repeat1(seq('+', $._computed_query_part)),
    ),

    _computed_query_part: $ => choice($.postcss_range_variable, $.string_value, $._query_variable_interpolation),

    _query_variable_interpolation: $ => seq('#{', $.postcss_range_variable, '}'),

    // PostCSS simple variables can supply a breakpoint before CSS is parsed.
    // Keep this extension local to range operands and leave the spelling intact.
    postcss_range_variable: _ => token(/\$[a-zA-Z_][a-zA-Z0-9_-]*/),

    // A function at the start of a parenthesized query may be an operand
    // or a general-enclosed query. Use the same balanced tokenization so
    // the following comparison can select the range interpretation.
    _range_numeric_operand: $ => choice($.integer_value, $.float_value, $.general_enclosed_query),

    // Ratio operands are not general arithmetic expressions. Keep their
    // written slash and spacing inside the opaque range query.
    range_ratio: $ => seq($._range_numeric_operand, '/', $._range_numeric_operand),

    _range_comparison: _ => choice('<', '<=', '=', '>=', '>'),

    parenthesized_query: $ => seq(
      '(',
      $._query,
      ')',
    ),

    binary_query: $ => prec.left(seq(
      $._query,
      choice(alias(/[aA][nN][dD]/, 'and'), alias(/[oO][rR]/, 'or')),
      $._query,
    )),

    unary_query: $ => prec(1, seq(
      choice(alias(/[nN][oO][tT]/, 'not'), alias(/[oO][nN][lL][yY]/, 'only')),
      $._query,
    )),

    // Property Values

    _value: $ => prec(-1, choice(
      alias($.identifier, $.plain_value),
      $.escaped_value_identifier,
      $.plain_value,
      $.dollar_value,
      $.phorge_value_variable,
      $.template_value_variable,
      // At-keywords are component values, even when a property interprets
      // them only in a dialect (for example, GTK's named colors).
      choice($.at_keyword, $.escaped_at_keyword),
      $.hash_value,
      $.integer_value,
      $.float_value,
      $.string_value,
      $.grid_value,
      $.glued_numeric_bracket_value,
      $.call_with_numeric_brackets,
      $.binary_expression,
      $.parenthesized_value,
      $.adjacent_minus_block,
      $.type_syntax_value,
      $.qualified_attr_value,
      $.interpolated_attr_value,
      $.conditional_value,
      $.call_expression,
      $.url_value,
      $.legacy_filter_value,
      $.legacy_expression_value,
      $.important,
    )),

    // '$' is a CSS delimiter that can remain in an unregistered custom
    // property's payload. Keep the adjacent spelling intact; do not turn
    // preprocessor-like text into a CSS variable reference.
    dollar_value: _ => token(/\$[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]*/u),

    // Phorge substitutes this exact spelling before passing assets to CSS.
    phorge_value_variable: _ => token(/\{\$[a-zA-Z_][a-zA-Z0-9_-]*(?:\.[a-zA-Z_][a-zA-Z0-9_-]*)*\}/),

    // Some stylesheet templates supply declaration values via a simple
    // dotted variable. Leave template expressions and control flow out.
    template_value_variable: _ => token(/\{\{[ \t]*[a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*[ \t]*\}\}/),

    // A hexadecimal escape may consume whitespace that is not a separator.
    escaped_value_identifier: _ => token(prec(1, seq(
      optional(BEFORE_IDENTIFIER_ESCAPE),
      CSS_ESCAPE,
      repeat(choice(
        /[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u,
        CSS_ESCAPE,
      )),
    ))),

    // Legacy IE filters use named parameters instead of CSS function values.
    legacy_filter_value: _ => {
      const trivia = repeat(choice(/[ \t\r\n\f]+/, CSS_BLOCK_COMMENT));
      return token(prec(1, choice(
        /[Pp][Rr][Oo][Gg][Ii][Dd]:[A-Za-z_][\w.-]*\((?:[^(){};"']|"(?:[^"\\\r\n]|\\[^\r\n])*"|'(?:[^'\\\r\n]|\\[^\r\n])*')*\)/,
        seq(/[Aa][Ll][Pp][Hh][Aa]\(/, trivia, /[Oo][Pp][Aa][Cc][Ii][Tt][Yy]/, trivia, '=', trivia, /[0-9]+/, trivia, ')'),
      )));
    },

    // Archived stylesheets can contain balanced legacy expression() payloads
    // that are not CSS function arguments. Treat them as source text only.
    legacy_expression_value: $ => seq(
      token(prec(1, /[eE][xX][pP][rR][eE][sS][sS][iI][oO][nN]\(/)),
      repeat($._opaque_block_component),
      ')',
    ),

    // Unquoted url() is a CSS token, not a normal function argument list.
    // Keep the URL atomic so spacing rules cannot split paths or escapes.
    url_value: _ => token(prec(1, seq(
      URL_NAME, /\([ \t\r\n\f]*/,
      repeat(choice(UNQUOTED_URL_BODY, CSS_ESCAPE)),
      /[ \t\r\n\f]*\)/,
    ))),

    parenthesized_value: $ => seq(
      '(',
      sep(',', repeat1($._value)),
      ')',
    ),

    // A minus directly followed by a block is not a signed numeric token.
    // Keep the authored adjacency rather than formatting it as subtraction.
    adjacent_minus_block: $ => seq(
      token(prec(1, '-(')),
      repeat($._opaque_block_component),
      ')',
    ),

    // CSS <syntax> alternatives can be literal keywords as well as types.
    // Keep them atomic rather than formatting them as function arguments.
    type_syntax_value: _ => {
      const component = seq(choice(/<[a-zA-Z][a-zA-Z0-9-]*>/, CSS_IDENTIFIER), optional(/[+#]/));
      const gap = repeat(choice(/[ \t\r\n\f]+/, /\/\*[^*]*\*+(?:[^/*][^*]*\*+)*\//));
      return token(prec(1, seq(
        /[tT][yY][pP][eE]\(/, gap,
        choice('*', seq(component, repeat(seq(gap, '|', gap, component)))),
        gap, ')',
      )));
    },

    // Reserve only qualified names; ordinary attr() uses normal call layout.
    qualified_attr_value: $ => {
      const name = seq(
        choice(CSS_IDENTIFIER, seq(optional('-'), CSS_ESCAPE)),
        repeat(choice(CSS_ESCAPE, /[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u)),
      );
      return seq(
        token(prec(1, seq(/[aA][tT][tT][rR]\([ \t\r\n\f]*/, optional(name), '|', name))),
        repeat($._opaque_block_component),
        ')',
      );
    },

    // Only take over attr() when its name or unit starts with Sass interpolation.
    interpolated_attr_value: $ => seq(
      token(prec(1, seq(/[aA][tT][tT][rR]\([ \t\r\n\f]*/, optional(seq(CSS_IDENTIFIER, /[ \t\r\n\f]+/)), '#{'))),
      $.postcss_range_variable,
      '}',
      repeat($._opaque_block_component),
      ')',
    ),

    // Semicolons separate branches inside if(), not declarations in its
    // containing block. Keep the conditional component list intact.
    conditional_value: $ => seq(
      token(prec(1, /[iI][fF]\(/)),
      repeat($._opaque_block_component),
      ')',
    ),

    // A CSS hash token can include non-hex characters and escapes. Do not
    // reinterpret its hexadecimal prefix as a separate color value.
    hash_value: _ => token(seq('#', repeat1(choice(
      /[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u,
      CSS_ESCAPE,
    )))),

    hash_delimiter: _ => '#',

    // A string is one token. Extras cannot skip an unescaped line break
    // between its contents and closing quote.
    string_value: _ => token(choice(
      seq('\'', repeat(choice(/[^\\'\r\n\f]+/, CSS_ESCAPE, /\\(?:\r\n|[\r\n\f])/)), '\''),
      seq('"', repeat(choice(/[^\\"\r\n\f]+/, CSS_ESCAPE, /\\(?:\r\n|[\r\n\f])/)), '"'),
    )),

    escape_sequence: _ => token(seq(
      '\\',
      choice(
        /[0-9a-fA-F]{1,6}\s?/,
        /[^0-9a-fA-F\n\r]/,
      ),
    )),

    integer_value: $ => seq(
      token(seq(
        optional(choice('+', '-')),
        /\d+/,
      )),
      optional($.unit),
    ),

    float_value: $ => seq(
      token(seq(
        optional(choice('+', '-')),
        /\d*/,
        choice(
          seq('.', /\d+/),
          seq(/[eE]/, optional(/[+-]/), /\d+/),
          seq('.', /\d+/, /[eE]/, optional(/[+-]/), /\d+/),
        ),
      )),
      optional($.unit),
    ),

    // A dimension's unit is an identifier, including any escape terminators.
    unit: _ => token.immediate(prec(2, choice('%', seq(
      choice(/--|-?[a-zA-Z_\u{80}-\u{10FFFF}]/u, seq(optional('-'), CSS_ESCAPE)),
      repeat(choice(/[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u, CSS_ESCAPE)),
    )))),

    // Grid line names and custom-property lists keep their original tokens.
    // In a custom property the brackets can contain any balanced simple block.
    grid_value: $ => seq(
      '[',
      repeat($._opaque_block_component),
      ']',
    ),

    // PostCSS words and Tailwind paths can include a source-adjacent index.
    // A space before or after the bracket still separates component values.
    glued_numeric_bracket_value: _ => token(seq(
      choice(/[a-zA-Z_-][a-zA-Z0-9_.-]*/, /[0-9]+(?:\.[0-9]+)?[a-zA-Z%]*/),
      repeat1(seq(/\[[0-9]+(?:\.[0-9]+)?\]/, optional(/[a-zA-Z_.-][a-zA-Z0-9_.-]*/))),
    )),

    call_expression: $ => seq(
      choice(alias($.identifier, $.function_name), alias($.escaped_value_identifier, $.escaped_function_name)),
      $.arguments,
    ),

    // An immediate suffix preserves the distinction from `var(--x) [0]`.
    call_with_numeric_brackets: $ => seq(
      $.call_expression,
      $.numeric_bracket_suffix,
    ),
    numeric_bracket_suffix: _ => token.immediate(/(?:\[[0-9]+(?:\.[0-9]+)?\])+/),

    binary_expression: $ => prec.left(seq(
      $._value,
      // Adjacent asterisks aren't a CSS operator. Accept the pair for
      // formatting without dropping either delimiter.
      choice('+', '-', '*', '/', '**', $.separated_slash_star),
      $._value,
    )),

    // These two delimiters must stay apart: adjacent `/*` starts a comment.
    separated_slash_star: _ => token(seq('/', /[ \t]+/, '*')),

    arguments: $ => seq(
      token.immediate('('),
      optional(choice(
        seq($._function_argument_values, repeat($._function_argument_separator)),
        seq(',', optional($._function_argument_values), repeat($._function_argument_separator)),
      )),
      ')',
    ),

    // Preserve empty comma-delimited fields, even if a particular function
    // rejects them at value validation time. A semicolon still needs a value.
    _function_argument_separator: $ => choice(
      seq(',', optional($._function_argument_values)),
      seq(';', $._function_argument_values),
    ),

    _function_argument_values: $ => seq(choice(
      repeat1(choice($._value, $.function_bang, $.function_block_argument)),
      seq($.function_prefix_delimiter, repeat1(choice($._value, $.function_bang, $.function_block_argument))),
    ), optional($.trailing_slash)),

    // These delimiters can sit before a component value without being an
    // arithmetic operator or part of a signed number token.
    function_prefix_delimiter: _ => choice('+', '-', '*'),

    // A simple block groups commas into one component value, notably for
    // dashed CSS functions. Do not interpret the contents as a style rule.
    function_block_argument: $ => seq('{', repeat($._opaque_block_component), '}'),

    // `!` inside a function is a delim token, not declaration priority.
    function_bang: _ => '!',

    class_name: $ => repeat1(choice(
      $.identifier,
      $.escape_sequence,
    )),

    // Match non-ASCII code points in CSS identifiers, not just Latin-1.
    identifier: _ => CSS_IDENTIFIER,

    // An at-keyword uses a full CSS identifier. Do not split a longer
    // unknown name into a recognized directive and an invented prelude.
    at_keyword: _ => /@(?:--|-?[a-zA-Z_\u{80}-\u{10FFFF}])[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]*/u,

    escaped_at_keyword: _ => token(seq(
      '@',
      optional(/(?:--|-?[a-zA-Z_\u{80}-\u{10FFFF}])[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]*|-/u),
      CSS_ESCAPE,
      repeat(choice(/[a-zA-Z0-9_\-\u{80}-\u{10FFFF}]+/u, CSS_ESCAPE)),
    )),

    js_comment: _ => token(prec(-1, seq('//', /.*/))),

    // CSS consumes an unclosed block comment through EOF. The complete
    // alternative wins on length when a closing delimiter is present.
    comment: _ => token(seq('/*', choice(
      /[^*]*\*+([^/*][^*]*\*+)*\//,
      /([^*]|\*+[^*/])*\**/,
    ))),

    // Leave slash and multiplication delimiters to binary expressions. Unquoted URLs have
    // their own token and may still contain slashes. A backslash must begin a
    // valid escape here, or a later inserted semicolon could become its target.
    plain_value: _ => token(seq(
      repeat(/[-_]/),
      /[a-zA-Z]/,
      repeat(choice(/[^\\/*\s,;!{}()\[\]]+/, CSS_ESCAPE)),
    )),
  },
});

/**
 * Creates a rule to optionally match one or more of the rules separated by `separator`
 *
 * @param {RuleOrLiteral} separator
 *
 * @param {RuleOrLiteral} rule
 *
 * @returns {ChoiceRule}
 */
function sep(separator, rule) {
  return optional(sep1(separator, rule));
}

/**
 * Creates a rule to match one or more of the rules separated by `separator`
 *
 * @param {RuleOrLiteral} separator
 *
 * @param {RuleOrLiteral} rule
 *
 * @returns {SeqRule}
 */
function sep1(separator, rule) {
  return seq(rule, repeat(seq(separator, rule)));
}
