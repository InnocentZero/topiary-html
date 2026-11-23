/**
 * @file HTML grammar for tree-sitter
 * @author Max Brunsfeld <maxbrunsfeld@gmail.com>
 * @author Amaan Qureshi <amaanq12@gmail.com>
 * @license MIT
 */

/// <reference types="tree-sitter-cli/dsl" />
// @ts-check

module.exports = grammar({
  name: 'html',

  extras: $ => [
    $.comment,
    /[ \t\n\f\r]+/,
  ],

  externals: $ => [
    $._start_tag_name,
    $._script_start_tag_name,
    $._style_start_tag_name,
    $._text_start_tag_name,
    $._end_tag_name,
    $.erroneous_end_tag_name,
    '/>',
    $._implicit_end_tag,
    $.raw_text,
    $.comment,
    $._literal_less_than,
    $.cdata,
    $._html_tag_name,
    $.bogus_comment,
    $._void_tag_name,
    $._void_tag_close,
    $._missing_attribute_value,
    $._attribute_stray_solidus,
    $._text_element_eof,
    $._flow_container_name,
    $._list_container_name,
    $._flow_item_name,
    $._list_item_name,
    $._flow_void_name,
    $._document_container_name,
    $._body_name,
    $.opaque_style_text,
    $.opaque_script_text,
    $._raw_start_solidus_close,
  ],

  rules: {
    document: $ => repeat($._node),

    doctype: $ => seq(
      '<!',
      alias($._doctype, 'doctype'),
      optional($.doctype_payload),
      '>',
    ),

    _doctype: _ => /[Dd][Oo][Cc][Tt][Yy][Pp][Ee]/,

    doctype_payload: _ => /[^>]+/,

    _node: $ => choice(
      $.doctype,
      $.cdata,
      $.bogus_comment,
      $.entity,
      $.text,
      alias('&', $.text),
      alias($._literal_less_than, $.text),
      $.element,
      alias($._text_element, $.element),
      $.script_element,
      $.style_element,
      $.erroneous_end_tag,
    ),

    element: $ => choice(
      seq(
        $.start_tag,
        repeat($._node),
        choice($.end_tag, $._implicit_end_tag),
      ),
      $.self_closing_tag,
      $.void_tag,
    ),

    script_element: $ => seq(
      alias($.script_start_tag, $.start_tag),
      choice(
        seq(optional(choice($.raw_text, $.opaque_script_text)), $.end_tag),
        alias($._text_element_eof, $.opaque_script_text),
      ),
    ),

    style_element: $ => seq(
      alias($.style_start_tag, $.start_tag),
      choice(
        seq(optional(choice($.raw_text, $.opaque_style_text)), $.end_tag),
        alias($._text_element_eof, $.opaque_style_text),
      ),
    ),

    _text_element: $ => seq(
      alias($._text_start_tag, $.start_tag),
      choice(seq(optional($.raw_text), $.end_tag), alias($._text_element_eof, $.raw_text)),
    ),

  _text_start_tag: $ => seq(
      '<',
      alias($._text_start_tag_name, $.tag_name),
      repeat($._attribute_item),
      choice('>', alias($._raw_start_solidus_close, '/>')),
    ),

    start_tag: $ => seq(
      '<',
      alias($._ordinary_start_name, $.tag_name),
      repeat($._attribute_item),
      '>',
    ),

    script_start_tag: $ => seq(
      '<',
      alias($._script_start_tag_name, $.tag_name),
      repeat($._attribute_item),
      choice('>', alias($._raw_start_solidus_close, '/>')),
    ),

    style_start_tag: $ => seq(
      '<',
      alias($._style_start_tag_name, $.tag_name),
      repeat($._attribute_item),
      choice('>', alias($._raw_start_solidus_close, '/>')),
    ),

    self_closing_tag: $ => seq(
      '<',
      alias(choice($._ordinary_start_name, $._text_start_tag_name), $.tag_name),
      repeat($._attribute_item),
      '/>',
    ),

    void_tag: $ => seq(
      '<',
      alias($._void_name, $.tag_name),
      repeat($._attribute_item),
      choice(alias($._void_tag_close, '>'), '/>'),
    ),

    _void_name: $ => alias($.void_html_tag_name, $.html_tag_name),

    void_html_tag_name: $ => choice($._void_tag_name, alias($._flow_void_name, $.flow_void_name)),

    end_tag: $ => seq(
      '</',
      alias($._matching_end_name, $.tag_name),
      optional($.end_tag_attributes),
      optional('/'),
      '>',
    ),

    // The HTML tokenizer recognizes these attributes, but the tree builder
    // ignores them. Recognize their quoted values before looking for `>`.
    end_tag_attributes: $ => repeat1($._attribute_item),

    _ordinary_start_name: $ => choice($._start_tag_name, $.html_tag_name),
    _matching_end_name: $ => choice($._end_tag_name, alias($._html_tag_name, $.html_tag_name)),

    html_tag_name: $ => choice(
      $._html_tag_name,
      alias($._flow_container_name, $.flow_container_name),
      alias($._list_container_name, $.list_container_name),
      alias($._flow_item_name, $.flow_item_name),
      alias($._list_item_name, $.list_item_name),
      alias($._document_container_name, $.document_container_name),
      alias($._body_name, $.body_name),
    ),

    erroneous_end_tag: $ => seq(
      '</',
      $.erroneous_end_tag_name,
      optional($.end_tag_attributes),
      optional('/'),
      '>',
    ),

    _attribute_item: $ => choice($.attribute, $._attribute_stray_solidus),

    attribute: $ => seq(
      $.attribute_name,
      optional(seq(
        '=',
        choice(
          $.attribute_value,
          $.quoted_attribute_value,
          alias($._missing_attribute_value, $.missing_attribute_value),
        ),
      )),
    ),

    // Browsers retain stray quotes and `<` inside attribute names, including
    // a quote immediately following a closed value. Do not consume them as text.
    // Only the five HTML space characters delimit attribute names or values.
    attribute_name: $ => choice(/[^>/= \t\n\f\r]+/, $._equals_prefixed_attribute_name),
    // When an attribute is already open, its assignment delimiter takes
    // precedence over recovery for an equals sign starting a new name.
    _equals_prefixed_attribute_name: _ => token(prec(-1, /=[^>/= \t\n\f\r]*/)),

    // HTML tokenization keeps `=` and `<` in an unquoted value, even though
    // using them there is a parse error. Quoting preserves the browser's value.
    // A quote at the start opens a quoted value. A quote encountered after
    // the unquoted value has started is a parse error but stays in the value.
    attribute_value: _ => /[^>"' \t\n\f\r][^> \t\n\f\r]*/,

    // An entity can be named, numeric (decimal), or numeric (hexacecimal). The
    // longest entity name is 29 characters long, and the HTML spec says that
    // no more will ever be added.
    entity: _ => /&(#([xX][0-9a-fA-F]{1,6}|[0-9]{1,5})|[A-Za-z]{1,30});?/,

    quoted_attribute_value: $ => choice(
      seq('\'', optional(alias(/[^']+/, $.attribute_value)), '\''),
      seq('"', optional(alias(/[^"]+/, $.attribute_value)), '"'),
    ),

    // Formatting needs the exact text boundaries, including whitespace-only
    // runs between inline elements and spaces beside entities.
    text: _ => token(prec(1, /[^<&]+/)),
  },
});
