const tsx = require('tree-sitter-typescript/tsx/grammar.js');

module.exports = grammar(tsx, {
  name: 'tsx',
  conflicts: ($, original) => original.concat([
    [$.arrow_function, $.predefined_type],
    [$.primary_type, $.function_type],
    [$.flow_maybe_type, $.flow_nullable_anonymous_parameter],
    [$._formal_parameter, $.type],
    [$.formal_parameters, $.flow_object_type_parameters],
    [$.primary_type, $.flow_object_type_parameters],
  ]),
  rules: {
    type_parameter: ($, original) => seq(optional(field('variance', choice('+', '-'))), original),

    tuple_parameter: ($, original) => seq(optional(field('variance', choice('+', '-'))), original),
    optional_tuple_parameter: ($, original) => seq(optional(field('variance', choice('+', '-'))), original),

    tuple_type: $ => {
      const members = seq($._tuple_type_member, repeat(seq(',', $._tuple_type_member)));
      const marker = seq($.flow_inexact_tuple_marker, optional(','));
      return seq('[', optional(choice(marker, seq(members, optional(seq(',', optional(marker)))))), ']');
    },

    flow_inexact_tuple_marker: _ => '...',

    primary_type: ($, original) => choice(original, $.flow_component_type, $.flow_interface_type),

    flow_maybe_type: ($, original) => choice(original, prec.right(seq('?', $.function_type))),

    _formal_parameter: ($, original) => choice(original, $.flow_nullable_anonymous_parameter, $.function_type),

    flow_nullable_anonymous_parameter: $ => prec.right(seq('?', $.primary_type)),

    function_type: ($, original) => choice(original, prec.left(seq(
      field('parameters', $.predefined_type), '=>', field('return_type', $.type),
    )), prec.left(seq(
      field('type_parameters', optional($.type_parameters)),
      field('parameters', alias($.flow_object_type_parameters, $.formal_parameters)), '=>',
      field('return_type', $.type),
    ))),

    flow_object_type_parameters: $ => seq(
      '(', repeat(seq($._formal_parameter, ',')), $.object_type,
      repeat(seq(',', choice($._formal_parameter, $.object_type))), optional(','), ')',
    ),

    // Only offer bare named shorthand in a type alias, where it cannot steal
    // the arrow after a return-type annotation on a JavaScript expression.
    flow_bare_named_function_type: $ => prec.left(seq(
      $._type_identifier, '=>',
      field('return_type', choice($.type, $.flow_bare_named_function_type)),
    )),

    variable_declarator: ($, original) => choice(original, seq(
      field('name', $.identifier), field('type', $.flow_chained_callback_annotation),
      $._initializer,
    )),

    // Limit this to variable initializers so an arrow after an expression's
    // return annotation still introduces the expression body.
    flow_chained_callback_annotation: $ => seq(':', $.flow_chained_callback_type),
    flow_chained_callback_type: $ => seq(
      field('type_parameters', optional($.type_parameters)),
      field('parameters', $.formal_parameters), '=>',
      field('return_type', $.flow_bare_named_function_type),
    ),

    flow_interface_type: $ => seq('interface', optional($.extends_type_clause), $.object_type),

    _call_signature: ($, original) => choice(original, seq(
      field('type_parameters', optional($.type_parameters)),
      field('parameters', $.formal_parameters),
      choice(
        seq(field('return_type', $.type_annotation), $.flow_inferred_predicate),
        field('return_type', $.type_predicate_annotation),
      ),
    )),

    function_signature: ($, original) => choice(original, seq(
      'function', field('name', $.identifier),
      field('parameters', $.flow_void_parameters), field('return_type', $.type_annotation),
      choice($._semicolon, $._function_signature_automatic_semicolon),
    )),

    flow_void_parameters: _ => seq('(', 'void', optional(','), ')'),

    flow_inferred_predicate: _ => '%checks',

    flow_component_type: $ => prec.right(seq(
      'component', optional($.type_parameters), $.flow_component_type_parameters,
      optional($.flow_component_render_type),
    )),

    flow_component_type_parameters: $ => {
      const rest = seq($.flow_component_type_rest, optional(','));
      const params = seq($.flow_component_type_parameter, repeat(seq(',', $.flow_component_type_parameter)));
      return seq('(', optional(choice(rest, seq(params, optional(seq(',', optional(rest)))))), ')');
    },

    flow_component_type_parameter: $ => seq(choice($.identifier, $.string), optional('?'), $.type_annotation),
    flow_component_type_rest: $ => seq('...', choice($.flow_component_type_parameter, $.type)),
    flow_component_render_type: $ => prec.right(seq(choice('renders', 'renders?', 'renders*'), $.type)),

    property_signature: ($, original) => seq(optional(choice('+', '-')), choice(original, seq(
      field('name', $._property_name), optional('?'), field('type', $.flow_named_function_annotation),
    ))),

    // Limit this shorthand inside members to primitive results, keeping
    // object literals with arrow-valued fields out of the type branch.
    flow_named_function_annotation: $ => seq(':', $.flow_named_function_member_type),
    flow_named_function_member_type: $ => seq($._type_identifier, '=>', $.predefined_type),

    public_field_definition: ($, original) => choice(original, seq(
      field('variance', choice('+', '-')),
      field('name', $._property_name), optional('?'), field('type', $.type_annotation),
    )),

    index_signature: ($, original) => choice(original, seq(
      field('variance', choice('+', '-')),
      '[', optional(seq(field('name', $.identifier), ':')),
      field('index_type', $.type), ']', field('type', $.type_annotation),
    )),

    ambient_declaration: ($, original) => choice(original,
      seq('declare', $.flow_ambient_opaque_type),
      seq('declare', 'export', choice(
        seq(optional('default'), $.function_signature),
        seq(optional('default'), $.class_declaration),
        seq('default', $.flow_ambient_default_type),
        $.flow_ambient_export_value, $.type_alias_declaration, $.interface_declaration, $.flow_ambient_opaque_type,
      )),
    ),

    flow_ambient_default_type: $ => seq($.type, $._semicolon),

    flow_ambient_export_value: $ => seq(choice('const', 'let', 'var'), $.identifier, $.type_annotation, $._semicolon),

    flow_ambient_opaque_type: $ => seq(
      'opaque', 'type', field('name', $._type_identifier),
      field('type_parameters', optional($.type_parameters)),
      optional(field('supertype', $.type_annotation)), $._semicolon,
    ),

    enum_declaration: $ => seq(
      'enum', field('name', $.identifier), optional($.flow_enum_representation), field('body', $.enum_body),
    ),

    flow_enum_representation: _ => seq('of', choice('boolean', 'number', 'string', 'symbol', 'bigint')),

    enum_body: $ => {
      const member = choice(field('name', $._property_name), $.enum_assignment);
      const unknown = seq('...', optional(','));
      return seq('{', optional(choice(unknown, seq(member, repeat(seq(',', member)), optional(seq(',', optional(unknown)))))), '}');
    },

    type_alias_declaration: ($, original) => choice(original, seq(
      'opaque', 'type', field('name', $._type_identifier),
      field('type_parameters', optional($.type_parameters)),
      optional(field('supertype', $.type_annotation)),
      '=', field('value', $.type), $._semicolon,
    ), seq(
      optional('opaque'), 'type', field('name', $._type_identifier),
      field('type_parameters', optional($.type_parameters)),
      '=', field('value', $.flow_bare_named_function_type), $._semicolon,
    )),

    // Preserve the upstream object-type members and delimiters, adding Flow's
    // type spread (not the similarly spelled JavaScript expression spread).
    object_type: $ => {
      const separator = choice(',', $._semicolon);
      const member = choice(
        $.export_statement, $.property_signature, $.call_signature,
        $.construct_signature, $.index_signature, $.method_signature, $.flow_object_type_spread,
      );
      const members = seq(optional(choice(',', ';')), member, repeat(seq(separator, member)));
      const marker = seq($.flow_inexact_object_marker, optional(separator));
      return choice(
        seq('{', optional(choice(marker, seq(members, optional(seq(separator, optional(marker)))))), '}'),
        seq('{|', optional(seq(members, optional(separator))), '|}'),
      );
    },

    flow_object_type_spread: $ => seq('...', $.type),
    flow_inexact_object_marker: _ => '...',
  },
});
