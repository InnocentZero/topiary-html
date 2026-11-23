#include "tree_sitter/parser.h"
#include <string.h>

enum TokenType {
    DESCENDANT_OP,
    PSEUDO_CLASS_SELECTOR_COLON,
    SPACED_STAR_PROPERTY,
    TRAILING_DECLARATION_SPACE,
    ESCAPED_IMPORTANT_KEYWORD,
    PRIORITY_GAP,
    LEGACY_PREFIXED_PROPERTY,
    INVALID_PRIORITY_NAME,
    EOF_DECLARATION_COLON,
    DETACHED_PSEUDO_CLASS_COLON,
    EOF_AT_KEYWORD_ESCAPE,
    EOF_URL_VALUE,
    EOF_STRING_VALUE,
    EOF_VALUE_BACKSLASH,
    DETACHED_IMPORT_SUPPORTS_OPEN,
    BEFORE_ADDITIONAL_IMPORT_SOURCES,
    LESS_MERGE_PROPERTY_NAME,
    BLOCKLESS_NESTED_PSEUDO_NAME,
    GLUED_ATTRIBUTE_TYPE_NAME,
    ERROR_RECOVERY,
};

static inline void advance(TSLexer *lexer) { lexer->advance(lexer, false); }

static inline void skip(TSLexer *lexer) { lexer->advance(lexer, true); }

static bool css_whitespace(int32_t c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
}

// Match the grammar's identifier characters independent of process locale.
static bool css_name_character(int32_t c) {
    return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') ||
           (c >= 'a' && c <= 'z') || c == '_' || c == '-' || c >= 0x80;
}

static bool ascii_letter(int32_t c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

static int hex_digit(int32_t c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    return -1;
}

// The caller has already consumed a backslash. Leave invalid escapes for the
// surrounding token logic and consume a hex escape's optional terminator.
static int32_t scan_escape_body(TSLexer *lexer) {
    if (lexer->eof(lexer)) return -1;
    int32_t c = lexer->lookahead;
    if (c == '\r' || c == '\n' || c == '\f') return -1;
    if (hex_digit(c) < 0) {
        advance(lexer);
        return c;
    }
    c = 0;
    for (unsigned count = 0; count < 6; count++) {
        int digit = hex_digit(lexer->lookahead);
        if (digit < 0) break;
        c = c * 16 + digit;
        advance(lexer);
    }
    if (css_whitespace(lexer->lookahead)) {
        int32_t separator = lexer->lookahead;
        advance(lexer);
        if (separator == '\r' && lexer->lookahead == '\n') advance(lexer);
    }
    return c;
}

// A final backslash in an identifier consumes EOF as U+FFFD. This token
// must end at physical EOF: whitespace after the backslash is not equivalent.
static bool scan_eof_at_keyword_escape(TSLexer *lexer) {
    advance(lexer); // '@'
    int32_t c = lexer->lookahead;
    if (c == '-') {
        advance(lexer);
        c = lexer->lookahead;
        if (!(ascii_letter(c) || c == '_' || c == '-' || c == '\\' || c >= 0x80)) return false;
    } else if (!(ascii_letter(c) || c == '_' || c == '\\' || c >= 0x80)) {
        return false;
    }
    while (css_name_character(lexer->lookahead) || lexer->lookahead == '\\') {
        c = lexer->lookahead;
        advance(lexer);
        if (c != '\\') continue;
        if (lexer->eof(lexer)) {
            lexer->mark_end(lexer);
            lexer->result_symbol = EOF_AT_KEYWORD_ESCAPE;
            return true;
        }
        if (scan_escape_body(lexer) < 0) return false;
    }
    return false;
}

enum StringEnd { STRING_CLOSED, STRING_BAD, STRING_EOF };

// Called after the opening quote. Escaped line endings and the optional
// whitespace after a hexadecimal escape do not form bad-string tokens.
static enum StringEnd scan_string_body(TSLexer *lexer, int32_t quote) {
    bool bad = false;
    while (!lexer->eof(lexer)) {
        int32_t c = lexer->lookahead;
        if (c == '\n' || c == '\r' || c == '\f') bad = true;
        advance(lexer);
        if (c == quote) return STRING_CLOSED;
        if (c == '\\' && !lexer->eof(lexer)) {
            int32_t escaped = lexer->lookahead;
            advance(lexer);
            if (escaped == '\r' && lexer->lookahead == '\n') advance(lexer);
            else if (hex_digit(escaped) >= 0) {
                for (unsigned digits = 1; digits < 6 && hex_digit(lexer->lookahead) >= 0; digits++) advance(lexer);
                if (css_whitespace(lexer->lookahead)) {
                    int32_t end = lexer->lookahead;
                    advance(lexer);
                    if (end == '\r' && lexer->lookahead == '\n') advance(lexer);
                }
            }
        }
    }
    return bad ? STRING_BAD : STRING_EOF;
}

static bool scan_eof_string_value(TSLexer *lexer) {
    int32_t quote = lexer->lookahead;
    advance(lexer);
    if (scan_string_body(lexer, quote) != STRING_EOF) return false;
    lexer->mark_end(lexer);
    lexer->result_symbol = EOF_STRING_VALUE;
    return true;
}

// Match the complete decoded identifier, not the prefix of a longer name.
static bool scan_priority_name(TSLexer *lexer, const bool *valid_symbols) {
    const char *letter = "important";
    bool matches = true;
    bool escaped = false;
    while (css_name_character(lexer->lookahead) || lexer->lookahead == '\\') {
        int32_t c = lexer->lookahead;
        advance(lexer);
        if (c == '\\') {
            escaped = true;
            c = scan_escape_body(lexer);
            if (c < 0) return false;
        }
        if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
        if (matches && *letter && *letter == c) letter++;
        else matches = false;
    }
    if (lexer->lookahead == '(') return false;
    if (matches && !*letter) {
        if (!escaped || !valid_symbols[ESCAPED_IMPORTANT_KEYWORD]) return false;
        lexer->result_symbol = ESCAPED_IMPORTANT_KEYWORD;
    } else {
        if (!valid_symbols[INVALID_PRIORITY_NAME]) return false;
        lexer->result_symbol = INVALID_PRIORITY_NAME;
    }
    lexer->mark_end(lexer);
    return true;
}

// Consume a CSS name and recognize only a complete, decoded URL function
// name. A hash or at-keyword containing that name is not a URL token.
static bool scan_url_name(TSLexer *lexer, bool eligible) {
    const char *letter = "url";
    while (css_name_character(lexer->lookahead) || lexer->lookahead == '\\') {
        int32_t c = lexer->lookahead;
        advance(lexer);
        if (c == '\\') c = scan_escape_body(lexer);
        if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
        if (eligible && *letter && *letter == c) letter++;
        else eligible = false;
    }
    return eligible && !*letter && lexer->lookahead == '(';
}

// These are not CSS spaces. Topiary can trim them from the end of an
// injected stylesheet, where they would otherwise be part of the URL.
static bool non_css_renderer_space(int32_t c) {
    return c == 0x85 || c == 0xa0 || c == 0x1680 || (c >= 0x2000 && c <= 0x200a) ||
           c == 0x2028 || c == 0x2029 || c == 0x202f || c == 0x205f || c == 0x3000;
}

// Even a bad unquoted URL consumes through the next unescaped ')'. Track
// whether it can be recovered at EOF without the renderer changing it.
// The caller has already consumed the initial CSS whitespace.
static bool scan_unquoted_url_body(TSLexer *lexer) {
    bool trailing_space = false;
    bool valid = true;
    bool trimmable_url_byte = false;
    while (!lexer->eof(lexer) && lexer->lookahead != ')') {
        int32_t c = lexer->lookahead;
        advance(lexer);
        if (css_whitespace(c)) {
            trailing_space = true;
        } else {
            if (trailing_space || c == '"' || c == '\'' || c == '(' || c < 0x20 || c == 0x7f) valid = false;
            trimmable_url_byte = non_css_renderer_space(c);
            if (c == '\\') {
                // A literal escaped space still ends in whitespace; a hex
                // escape ends in a digit or an optional CSS terminator.
                trimmable_url_byte = css_whitespace(lexer->lookahead) || non_css_renderer_space(lexer->lookahead);
                if (scan_escape_body(lexer) < 0) valid = false;
            }
        }
    }
    return valid && !trimmable_url_byte;
}

static bool scan_eof_url_value(TSLexer *lexer) {
    if (!scan_url_name(lexer, true)) return false;
    advance(lexer);
    while (css_whitespace(lexer->lookahead)) advance(lexer);
    if (lexer->eof(lexer) || !scan_unquoted_url_body(lexer) || !lexer->eof(lexer)) return false;
    lexer->mark_end(lexer);
    lexer->result_symbol = EOF_URL_VALUE;
    return true;
}

// Don't let the opaque multi-source prelude compete with ordinary media
// query tokens. Only enable it after finding a top-level comma and string.
static bool scan_additional_import_sources(TSLexer *lexer) {
    lexer->mark_end(lexer);
    unsigned depth = 0;
    bool after_comma = false;
    while (!lexer->eof(lexer)) {
        int32_t c = lexer->lookahead;
        if (!depth && (c == ';' || c == '{' || c == '}')) return false;
        if (css_whitespace(c)) {
            advance(lexer);
            continue;
        }
        if (c == '/') {
            advance(lexer);
            if (lexer->lookahead == '*') {
                advance(lexer);
                while (!lexer->eof(lexer)) {
                    int32_t next = lexer->lookahead;
                    advance(lexer);
                    if (next == '*' && lexer->lookahead == '/') {
                        advance(lexer);
                        break;
                    }
                }
                continue;
            }
            after_comma = false;
            continue;
        }
        if (c == '"' || c == '\'') {
            advance(lexer);
            if (scan_string_body(lexer, c) != STRING_CLOSED) return false;
            if (after_comma) {
                lexer->result_symbol = BEFORE_ADDITIONAL_IMPORT_SOURCES;
                return true;
            }
        } else if (css_name_character(c) || c == '\\') {
            if (scan_url_name(lexer, true)) {
                advance(lexer);
                while (css_whitespace(lexer->lookahead)) advance(lexer);
                if (lexer->lookahead == '"' || lexer->lookahead == '\'') {
                    depth++;
                } else {
                    scan_unquoted_url_body(lexer);
                    if (lexer->lookahead == ')') advance(lexer);
                }
            }
        } else {
            advance(lexer);
            if (c == '(' || c == '[' || c == '{') depth++;
            else if (c == ')' || c == ']' || c == '}') {
                if (!depth) return false;
                depth--;
            }
        }
        after_comma = !depth && c == ',';
    }
    return false;
}

// Delimiters inside selector arguments, strings and comments do not tell us
// whether this colon begins a pseudo-class or separates a property value.
static bool scan_to_rule_block(TSLexer *lexer, bool *complete_value) {
    unsigned depth = 0;
    if (complete_value) *complete_value = false;
    while (!lexer->eof(lexer)) {
        int32_t c = lexer->lookahead;
        if (depth == 0) {
            if (c == '{') {
                // Value placeholders are not nested rule bodies. Match
                // the grammar's exact spellings for both forms.
                advance(lexer);
                bool dotted_template = lexer->lookahead == '{';
                if (!dotted_template && lexer->lookahead != '$') return true;
                advance(lexer);
                if (dotted_template) {
                    while (lexer->lookahead == ' ' || lexer->lookahead == '\t') advance(lexer);
                }
                while (true) {
                    if (!ascii_letter(lexer->lookahead) && lexer->lookahead != '_') return true;
                    do { advance(lexer); } while (
                        lexer->lookahead < 0x80 && css_name_character(lexer->lookahead) &&
                        (!dotted_template || lexer->lookahead != '-'));
                    if (lexer->lookahead != '.') break;
                    advance(lexer);
                }
                if (dotted_template) {
                    while (lexer->lookahead == ' ' || lexer->lookahead == '\t') advance(lexer);
                }
                if (lexer->lookahead != '}') return true;
                advance(lexer);
                if (dotted_template) {
                    if (lexer->lookahead != '}') return true;
                    advance(lexer);
                }
                continue;
            }
            if (c == ';' || c == '}') return false;
        }
        if (css_name_character(c) || c == '\\' || c == '#' || c == '@') {
            bool eligible = c != '#' && c != '@';
            if (!eligible) advance(lexer);
            if (!scan_url_name(lexer, eligible)) continue;
            advance(lexer); // Opening parenthesis.
            while (css_whitespace(lexer->lookahead)) advance(lexer);
            if (lexer->lookahead == '\'' || lexer->lookahead == '"') {
                depth++; // Quoted url() follows ordinary function-token rules.
                continue;
            }
            bool nonempty_url = !lexer->eof(lexer);
            bool valid_url = scan_unquoted_url_body(lexer);
            if (lexer->lookahead == ')') advance(lexer);
            else {
                if (complete_value) *complete_value = depth == 0 && nonempty_url && valid_url;
                return false;
            }
            continue;
        }
        advance(lexer);
        if (c == '[' || c == '(') {
            depth++;
        } else if ((c == ']' || c == ')') && depth > 0) {
            depth--;
        } else if (c == '\'' || c == '"') {
            enum StringEnd end = scan_string_body(lexer, c);
            if (end != STRING_CLOSED) {
                if (complete_value) *complete_value = end == STRING_EOF && depth == 0;
                return false;
            }
        } else if (c == '/' && lexer->lookahead == '*') {
            advance(lexer);
            bool closed = false;
            while (!lexer->eof(lexer)) {
                int32_t next = lexer->lookahead;
                advance(lexer);
                if (next == '*' && lexer->lookahead == '/') {
                    advance(lexer);
                    closed = true;
                    break;
                }
            }
            if (!closed) return false;
        }
    }
    if (complete_value) *complete_value = depth == 0;
    return false;
}

static bool scan_blockless_nested_pseudo_name(TSLexer *lexer) {
    advance(lexer); // '&'
    if (lexer->lookahead != ':') return false;
    advance(lexer);
    unsigned length = 0;
    char name[6];
    while (ascii_letter(lexer->lookahead) && length < sizeof(name) - 1) {
        int32_t c = lexer->lookahead;
        name[length++] = (char)(c >= 'A' && c <= 'Z' ? c + 'a' - 'A' : c);
        advance(lexer);
    }
    name[length] = '\0';
    if (lexer->lookahead != '(' ||
        (strcmp(name, "is") && strcmp(name, "not") && strcmp(name, "where") && strcmp(name, "has"))) return false;
    lexer->mark_end(lexer);
    // Don't steal the prefix of an ordinary nested rule. Only the name
    // becomes an external token; the grammar balances the arguments.
    if (scan_to_rule_block(lexer, NULL)) return false;
    lexer->result_symbol = BLOCKLESS_NESTED_PSEUDO_NAME;
    return true;
}

// The colon has been consumed. A detached name is only a selector
// recovery when a rule block follows, not in e.g. `color: blue;`.
static bool scan_detached_pseudo_class_colon(TSLexer *lexer, bool allow_eof_declaration) {
    lexer->mark_end(lexer);
    do { advance(lexer); } while (lexer->lookahead == ' ' || lexer->lookahead == '\t');
    int32_t c = lexer->lookahead;
    bool starts_name = ascii_letter(c) || c == '-' || c == '_' || c >= 0x80;
    bool complete_value;
    if (scan_to_rule_block(lexer, &complete_value)) {
        lexer->result_symbol = DETACHED_PSEUDO_CLASS_COLON;
        return starts_name;
    }
    lexer->result_symbol = EOF_DECLARATION_COLON;
    return allow_eof_declaration && complete_value;
}

// A glued Less merge suffix is a property only when its declaration colon
// follows. Do not lex the '+' in an adjacent-sibling selector as a suffix.
static bool scan_less_merge_property_name(TSLexer *lexer) {
    int32_t c = lexer->lookahead;
    if (c == '-') {
        advance(lexer);
        c = lexer->lookahead;
    }
    if (!ascii_letter(c) && c != '_' && c != '-' && c < 0x80) return false;
    do { advance(lexer); } while (css_name_character(lexer->lookahead));
    if (lexer->lookahead != '+') return false;
    advance(lexer);
    if (lexer->lookahead == '_') advance(lexer);
    lexer->mark_end(lexer);
    for (;;) {
        while (css_whitespace(lexer->lookahead)) advance(lexer);
        if (lexer->lookahead != '/') break;
        advance(lexer);
        if (lexer->lookahead != '*') return false;
        advance(lexer);
        bool closed = false;
        while (!lexer->eof(lexer)) {
            c = lexer->lookahead;
            advance(lexer);
            if (c == '*' && lexer->lookahead == '/') {
                advance(lexer);
                closed = true;
                break;
            }
        }
        if (!closed) return false;
    }
    if (lexer->lookahead != ':') return false;
    advance(lexer);
    if (scan_to_rule_block(lexer, NULL)) return false;
    lexer->result_symbol = LESS_MERGE_PROPERTY_NAME;
    return true;
}

void *tree_sitter_css_external_scanner_create() { return NULL; }

void tree_sitter_css_external_scanner_destroy(void *payload) {}

unsigned tree_sitter_css_external_scanner_serialize(void *payload, char *buffer) { return 0; }

void tree_sitter_css_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {}

bool tree_sitter_css_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
    if (valid_symbols[ERROR_RECOVERY]) {
        return false;
    }

    if (valid_symbols[BEFORE_ADDITIONAL_IMPORT_SOURCES]) return scan_additional_import_sources(lexer);

    // Do not skip trivia: a name separated from the attribute is a descendant.
    if (valid_symbols[GLUED_ATTRIBUTE_TYPE_NAME] &&
            (ascii_letter(lexer->lookahead) || lexer->lookahead == '_' ||
             lexer->lookahead >= 0x80 || lexer->lookahead == '-')) {
        if (lexer->lookahead == '-') {
            advance(lexer);
            if (!(ascii_letter(lexer->lookahead) || lexer->lookahead == '_' ||
                  lexer->lookahead >= 0x80 || lexer->lookahead == '-')) return false;
        }
        do { advance(lexer); } while (css_name_character(lexer->lookahead));
        if (lexer->lookahead == '\\') return false;
        lexer->mark_end(lexer);
        lexer->result_symbol = GLUED_ATTRIBUTE_TYPE_NAME;
        return true;
    }

    // Keep this whitespace-sensitive opener out of the generated lexer.
    // An immediate token beginning with whitespace changes how that lexer
    // marks the start of ordinary tokens in shared query states.
    if (valid_symbols[DETACHED_IMPORT_SUPPORTS_OPEN] && css_whitespace(lexer->lookahead)) {
        do { advance(lexer); } while (css_whitespace(lexer->lookahead));
        if (lexer->lookahead != '(') return false;
        advance(lexer);
        lexer->mark_end(lexer);
        lexer->result_symbol = DETACHED_IMPORT_SUPPORTS_OPEN;
        return true;
    }

    // Own the whitespace only at a declaration boundary. It may be part of
    // a custom property's value, but must not prevent a following semicolon.
    if (valid_symbols[TRAILING_DECLARATION_SPACE] && css_whitespace(lexer->lookahead)) {
        do { advance(lexer); } while (css_whitespace(lexer->lookahead));
        // This branch sees the gap before the EOF-string scanner does.
        if (valid_symbols[EOF_STRING_VALUE] && !valid_symbols[PRIORITY_GAP] &&
                (lexer->lookahead == '\'' || lexer->lookahead == '"')) {
            return scan_eof_string_value(lexer);
        }
        if (lexer->lookahead != '}' && !lexer->eof(lexer)) {
            // After `!`, the same state can either end a malformed declaration
            // or start a priority. Expose the gap so both tokens can be read.
            if (!valid_symbols[PRIORITY_GAP]) return false;
            lexer->mark_end(lexer);
            lexer->result_symbol = PRIORITY_GAP;
            return true;
        }
        lexer->mark_end(lexer);
        lexer->result_symbol = TRAILING_DECLARATION_SPACE;
        return true;
    }

    if (valid_symbols[ESCAPED_IMPORTANT_KEYWORD] || valid_symbols[INVALID_PRIORITY_NAME]) {
        while (css_whitespace(lexer->lookahead)) skip(lexer);
        int32_t c = lexer->lookahead;
        if (ascii_letter(c) || c == '_' || c == '-' || c == '\\' || c >= 0x80) {
            return scan_priority_name(lexer, valid_symbols);
        }
    }

    if (css_whitespace(lexer->lookahead) && valid_symbols[DESCENDANT_OP]) {
        lexer->result_symbol = DESCENDANT_OP;

        skip(lexer);
        while (css_whitespace(lexer->lookahead)) {
            skip(lexer);
        }
        lexer->mark_end(lexer);

        if (lexer->lookahead == '#' || lexer->lookahead == '.' || lexer->lookahead == '[' ||
            lexer->lookahead == '&' || lexer->lookahead == '\\' ||
            lexer->lookahead == '*' || css_name_character(lexer->lookahead)) {
            return true;
        }

        // `|name` starts a selector with an empty namespace; `||` is a
        // combinator and the preceding spaces are not a descendant operator.
        if (lexer->lookahead == '%') {
            advance(lexer);
            int32_t c = lexer->lookahead;
            return ascii_letter(c) || c == '_' || c == '-' || c >= 0x80;
        }

        if (lexer->lookahead == '|') {
            advance(lexer);
            return lexer->lookahead == '*' || lexer->lookahead == '\\' ||
                   css_name_character(lexer->lookahead);
        }

        if (lexer->lookahead == ':') {
            advance(lexer);
            if (css_whitespace(lexer->lookahead)) {
                if (valid_symbols[DETACHED_PSEUDO_CLASS_COLON] &&
                    (lexer->lookahead == ' ' || lexer->lookahead == '\t')) {
                    return scan_detached_pseudo_class_colon(lexer, valid_symbols[EOF_DECLARATION_COLON]);
                }
                return false;
            }
            return scan_to_rule_block(lexer, NULL);
        }
    }

    if (valid_symbols[EOF_AT_KEYWORD_ESCAPE]) {
        while (css_whitespace(lexer->lookahead)) skip(lexer);
        if (lexer->lookahead == '@') return scan_eof_at_keyword_escape(lexer);
    }

    if (valid_symbols[BLOCKLESS_NESTED_PSEUDO_NAME]) {
        while (css_whitespace(lexer->lookahead)) skip(lexer);
        if (lexer->lookahead == '&') return scan_blockless_nested_pseudo_name(lexer);
    }

    if (valid_symbols[EOF_URL_VALUE]) {
        while (css_whitespace(lexer->lookahead)) skip(lexer);
        int32_t c = lexer->lookahead;
        if (c == 'u' || c == 'U' || c == '\\') return scan_eof_url_value(lexer);
    }

    if (valid_symbols[EOF_STRING_VALUE]) {
        while (css_whitespace(lexer->lookahead)) skip(lexer);
        if (lexer->lookahead == '\'' || lexer->lookahead == '"') return scan_eof_string_value(lexer);
    }

    // A terminal backslash consumes EOF, not an authored newline or space.
    if (valid_symbols[EOF_VALUE_BACKSLASH]) {
        while (css_whitespace(lexer->lookahead)) skip(lexer);
        if (lexer->lookahead == '\\') {
            advance(lexer);
            lexer->result_symbol = EOF_VALUE_BACKSLASH;
            return lexer->eof(lexer);
        }
    }

    if (valid_symbols[PSEUDO_CLASS_SELECTOR_COLON] || valid_symbols[EOF_DECLARATION_COLON] ||
        valid_symbols[DETACHED_PSEUDO_CLASS_COLON]) {
        while (css_whitespace(lexer->lookahead)) {
            skip(lexer);
        }
        if (lexer->lookahead == ':') {
            advance(lexer);
            if (valid_symbols[DETACHED_PSEUDO_CLASS_COLON] &&
                (lexer->lookahead == ' ' || lexer->lookahead == '\t')) {
                return scan_detached_pseudo_class_colon(lexer, valid_symbols[EOF_DECLARATION_COLON]);
            }
            bool adjacent_name = !lexer->eof(lexer) && lexer->lookahead != ':' &&
                lexer->lookahead != '#' && !css_whitespace(lexer->lookahead);
            if (!adjacent_name && !valid_symbols[EOF_DECLARATION_COLON]) return false;
            lexer->mark_end(lexer);
            lexer->result_symbol = PSEUDO_CLASS_SELECTOR_COLON;
            bool complete_value;
            if (scan_to_rule_block(lexer, &complete_value)) {
                return adjacent_name && valid_symbols[PSEUDO_CLASS_SELECTOR_COLON];
            }
            if (complete_value && valid_symbols[EOF_DECLARATION_COLON]) {
                lexer->result_symbol = EOF_DECLARATION_COLON;
                return true;
            }

            // If we're at eof, and we happened to *not* find an opening brace to indicate we have a pseudo class
            // selector, we should *still* return one at EOF. This will improve error recovery, and the malformed code
            // can be parsed as an erroneous pseudo-class selector, rather than an erroneous property.
            return adjacent_name && valid_symbols[PSEUDO_CLASS_SELECTOR_COLON] && lexer->eof(lexer);
        }
    }

    // These legacy prefixes can also start selectors. Look past the colon
    // so ID pseudos and relative selectors can keep their block.
    if (valid_symbols[SPACED_STAR_PROPERTY] || valid_symbols[LEGACY_PREFIXED_PROPERTY] ||
        valid_symbols[LESS_MERGE_PROPERTY_NAME]) {
        while (css_whitespace(lexer->lookahead)) skip(lexer);
        int32_t prefix = lexer->lookahead;
        if (valid_symbols[LESS_MERGE_PROPERTY_NAME] &&
            (ascii_letter(prefix) || prefix == '_' || prefix == '-' || prefix >= 0x80)) {
            return scan_less_merge_property_name(lexer);
        }
        if (prefix != '#' && prefix != '+' && prefix != '*') return false;
        advance(lexer);
        bool prefixed = prefix != '*' || lexer->lookahead == '+';
        if (prefixed) {
            if (!valid_symbols[LEGACY_PREFIXED_PROPERTY]) return false;
            if (prefix == '*') advance(lexer);
        } else {
            if (!valid_symbols[SPACED_STAR_PROPERTY] ||
                (lexer->lookahead != ' ' && lexer->lookahead != '\t')) return false;
            do { advance(lexer); } while (lexer->lookahead == ' ' || lexer->lookahead == '\t');
        }
        int32_t c = lexer->lookahead;
        if (!ascii_letter(c) && c != '-' && c != '_') return false;
        do { advance(lexer); } while (lexer->lookahead < 0x80 && css_name_character(lexer->lookahead));
        lexer->mark_end(lexer);
        while (css_whitespace(lexer->lookahead)) advance(lexer);
        if (lexer->lookahead != ':') return false;
        advance(lexer);
        lexer->result_symbol = prefixed ? LEGACY_PREFIXED_PROPERTY : SPACED_STAR_PROPERTY;
        if (scan_to_rule_block(lexer, NULL)) return false;
        // A bare `#id:pseudo` at EOF is still an incomplete selector.
        return !prefixed || !lexer->eof(lexer);
    }

    return false;
}
