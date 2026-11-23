#include "tag.h"
#include "tree_sitter/parser.h"

enum TokenType {
    START_TAG_NAME,
    SCRIPT_START_TAG_NAME,
    STYLE_START_TAG_NAME,
    TEXT_START_TAG_NAME,
    END_TAG_NAME,
    ERRONEOUS_END_TAG_NAME,
    SELF_CLOSING_TAG_DELIMITER,
    IMPLICIT_END_TAG,
    RAW_TEXT,
    COMMENT,
    LITERAL_LESS_THAN,
    CDATA,
    HTML_TAG_NAME,
    BOGUS_COMMENT,
    VOID_TAG_NAME,
    VOID_TAG_CLOSE,
    MISSING_ATTRIBUTE_VALUE,
    ATTRIBUTE_STRAY_SOLIDUS,
    TEXT_ELEMENT_EOF,
    FLOW_CONTAINER_NAME,
    LIST_CONTAINER_NAME,
    FLOW_ITEM_NAME,
    LIST_ITEM_NAME,
    FLOW_VOID_NAME,
    DOCUMENT_CONTAINER_NAME,
    BODY_NAME,
    OPAQUE_STYLE_TEXT,
    OPAQUE_SCRIPT_TEXT,
    RAW_START_SOLIDUS_CLOSE,
};

typedef struct {
    Array(Tag) tags;
} Scanner;

#define MAX(a, b) ((a) > (b) ? (a) : (b))

static inline void advance(TSLexer *lexer) { lexer->advance(lexer, false); }

static inline void skip(TSLexer *lexer) { lexer->advance(lexer, true); }

static unsigned serialize(Scanner *scanner, char *buffer) {
    uint16_t tag_count = scanner->tags.size > UINT16_MAX ? UINT16_MAX : scanner->tags.size;
    uint16_t serialized_tag_count = 0;

    unsigned size = sizeof(tag_count);
    memcpy(&buffer[size], &tag_count, sizeof(tag_count));
    size += sizeof(tag_count);

    for (; serialized_tag_count < tag_count; serialized_tag_count++) {
        Tag tag = scanner->tags.contents[serialized_tag_count];
        if (tag.type == CUSTOM) {
            unsigned name_length = tag.custom_tag_name.size;
            if (name_length > UINT8_MAX) {
                name_length = UINT8_MAX;
            }
            if (size + 2 + name_length >= TREE_SITTER_SERIALIZATION_BUFFER_SIZE) {
                break;
            }
            buffer[size++] = (char)tag.type;
            buffer[size++] = (char)name_length;
            strncpy(&buffer[size], tag.custom_tag_name.contents, name_length);
            size += name_length;
        } else {
            if (size + 1 >= TREE_SITTER_SERIALIZATION_BUFFER_SIZE) {
                break;
            }
            buffer[size++] = (char)tag.type;
        }
    }

    memcpy(&buffer[0], &serialized_tag_count, sizeof(serialized_tag_count));
    return size;
}

static void deserialize(Scanner *scanner, const char *buffer, unsigned length) {
    for (unsigned i = 0; i < scanner->tags.size; i++) {
        tag_free(&scanner->tags.contents[i]);
    }
    array_clear(&scanner->tags);

    if (length > 0) {
        unsigned size = 0;
        uint16_t tag_count = 0;
        uint16_t serialized_tag_count = 0;

        memcpy(&serialized_tag_count, &buffer[size], sizeof(serialized_tag_count));
        size += sizeof(serialized_tag_count);

        memcpy(&tag_count, &buffer[size], sizeof(tag_count));
        size += sizeof(tag_count);

        array_reserve(&scanner->tags, tag_count);
        if (tag_count > 0) {
            unsigned iter = 0;
            for (iter = 0; iter < serialized_tag_count; iter++) {
                Tag tag = tag_new();
                tag.type = (TagType)(uint8_t)buffer[size++];
                if (tag.type == CUSTOM) {
                    uint16_t name_length = (uint8_t)buffer[size++];
                    array_reserve(&tag.custom_tag_name, name_length);
                    tag.custom_tag_name.size = name_length;
                    memcpy(tag.custom_tag_name.contents, &buffer[size], name_length);
                    size += name_length;
                }
                array_push(&scanner->tags, tag);
            }
            // add zero tags if we didn't read enough, this is because the
            // buffer had no more room but we held more tags.
            for (; iter < tag_count; iter++) {
                array_push(&scanner->tags, tag_new());
            }
        }
    }
}

static int32_t ascii_upper(int32_t c) {
    return c >= 'a' && c <= 'z' ? c - ('a' - 'A') : c;
}

static void append_name_codepoint(String *name, int32_t c) {
    // Scanner lookahead is a code point; the saved tag name is a byte array.
    if (c < 0x80) {
        array_push(name, ascii_upper(c));
        return;
    }
    if (c < 0x800) {
        array_push(name, 0xC0 | (c >> 6));
    } else if (c < 0x10000) {
        array_push(name, 0xE0 | (c >> 12));
        array_push(name, 0x80 | ((c >> 6) & 0x3F));
    } else {
        array_push(name, 0xF0 | (c >> 18));
        array_push(name, 0x80 | ((c >> 12) & 0x3F));
        array_push(name, 0x80 | ((c >> 6) & 0x3F));
    }
    array_push(name, 0x80 | (c & 0x3F));
}

static bool html_space(int32_t c);

static String scan_tag_name(TSLexer *lexer, bool is_closing_tag) {
    String tag_name = array_new();
    for (;;) {
        int32_t c = lexer->lookahead;
        int32_t upper = ascii_upper(c);
        // These characters can occur after a tag name has started. Do not
        // turn a suffix such as @v into a synthetic attribute.
        bool suffix_character = c == '_' || c == '.' || c == '@' ||
                                c == '+' || c == '%' || c == '!' ||
                                c == '?' || c == ',' || c == ';' || c >= 0x80;
        if (!((upper >= 'A' && upper <= 'Z') || (c >= '0' && c <= '9') ||
              c == '-' || c == ':' || (tag_name.size > 0 && suffix_character))) {
            break;
        }
        append_name_codepoint(&tag_name, c);
        advance(lexer);
    }
    // A `<` immediately after an end-tag name belongs to that name, not
    // to its attributes. In particular, `</td</tr>` does not close a td.
    if (is_closing_tag && tag_name.size > 0 && lexer->lookahead == '<') {
        while (!lexer->eof(lexer) && lexer->lookahead != '>' &&
               lexer->lookahead != '/' && !html_space(lexer->lookahead)) {
            append_name_codepoint(&tag_name, lexer->lookahead);
            advance(lexer);
        }
    }
    return tag_name;
}

static bool renderer_whitespace(int32_t c);

static bool scan_bogus_comment(TSLexer *lexer) {
    int32_t previous = 0, last = 0;
    while (!lexer->eof(lexer)) {
        int32_t c = lexer->lookahead;
        previous = last;
        last = c;
        advance(lexer);
        if (c == '>') {
            lexer->mark_end(lexer);
            lexer->result_symbol = BOGUS_COMMENT;
            return true;
        }
    }
    if (last == '\n' && !renderer_whitespace(previous)) {
        lexer->mark_end(lexer);
        lexer->result_symbol = BOGUS_COMMENT;
        return true;
    }
    return false;
}

static bool scan_comment(TSLexer *lexer, bool allow_bogus) {
    if (lexer->lookahead != '-') {
        return false;
    }
    advance(lexer);
    if (lexer->lookahead != '-') {
        return allow_bogus && scan_bogus_comment(lexer);
    }
    advance(lexer);

    bool start = true, end_bang = false;
    unsigned dashes = 0;
    int32_t previous = '-', last = '-';
    while (!lexer->eof(lexer)) {
        int32_t c = lexer->lookahead;
        previous = last;
        last = c;
        advance(lexer);
        // HTML also ends a comment at <!-->, <!--->, or --!>.
        if (c == '>' && (start || dashes == 2 || end_bang)) {
            lexer->result_symbol = COMMENT;
            lexer->mark_end(lexer);
            return true;
        }
        start = start && c == '-' && dashes == 0;
        end_bang = c == '!' && dashes == 2;
        dashes = c == '-' ? (dashes < 2 ? dashes + 1 : 2) : 0;
    }
    // At EOF the comment is emitted without a closer. Topiary always strips
    // trailing whitespace and adds LF, so accept only a byte-stable ending.
    if (last == '\n' && !renderer_whitespace(previous)) {
        lexer->result_symbol = COMMENT;
        lexer->mark_end(lexer);
        return true;
    }
    return false;
}

static bool scan_cdata(TSLexer *lexer, bool allow_bogus, bool foreign) {
    for (const char *prefix = "[CDATA["; *prefix; prefix++) {
        if (lexer->lookahead != *prefix) {
            // No delimiter can have been consumed while matching the prefix.
            return allow_bogus && scan_bogus_comment(lexer);
        }
        advance(lexer);
    }
    unsigned brackets = 0;
    bool marked_bogus_end = false;
    int32_t previous = 'A', last = '[';
    while (!lexer->eof(lexer)) {
        int32_t c = lexer->lookahead;
        previous = last;
        last = c;
        advance(lexer);
        if (c == '>' && brackets == 2) {
            lexer->mark_end(lexer);
            lexer->result_symbol = CDATA;
            return true;
        }
        // Keep complete XML-style CDATA sections opaque, but if there is
        // no XML terminator the HTML bogus comment ends at the first `>`.
        if (!foreign && allow_bogus && c == '>' && !marked_bogus_end) {
            lexer->mark_end(lexer);
            marked_bogus_end = true;
        }
        brackets = c == ']' ? (brackets < 2 ? brackets + 1 : 2) : 0;
    }
    if (marked_bogus_end) {
        lexer->result_symbol = BOGUS_COMMENT;
        return true;
    }
    if ((foreign || allow_bogus) && last == '\n' && !renderer_whitespace(previous)) {
        lexer->mark_end(lexer);
        lexer->result_symbol = foreign ? CDATA : BOGUS_COMMENT;
        return true;
    }
    return false;
}

static const char *raw_end_delimiter(TagType type) {
    switch (type) {
        case SCRIPT: return "</SCRIPT";
        case STYLE: return "</STYLE";
        case TITLE: return "</TITLE";
        case TEXTAREA: return "</TEXTAREA";
        case IFRAME: return "</IFRAME";
        case XMP: return "</XMP";
        case NOEMBED: return "</NOEMBED";
        case NOFRAMES: return "</NOFRAMES";
        default: return NULL;
    }
}

static void pop_tag(Scanner *scanner);

static bool html_space(int32_t c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';
}

// Match the Unicode whitespace that Topiary trims before adding a final LF.
static bool renderer_whitespace(int32_t c) {
    return (c >= '\t' && c <= '\r') || c == ' ' || c == 0x85 ||
        c == 0xa0 || c == 0x1680 || (c >= 0x2000 && c <= 0x200a) ||
        c == 0x2028 || c == 0x2029 || c == 0x202f || c == 0x205f || c == 0x3000;
}

// The HTML renderer indents every line of an injected stylesheet. Determine
// whether that would change an opaque multiline CSS token sequence without
// evaluating the stylesheet.
typedef struct {
    unsigned name, depth, hex_digits, dashed, module_name;
    int32_t escape_value;
    int32_t quote, previous;
    const char *pseudo_suffix, *query_suffix, *conditional_suffix;
    const char *gradient_suffix;
    unsigned query_depth, conditional_depth, gradient_depth;
    char closer[64];
    bool comment, escaped, hex_cr, opaque, pseudo_start;
    bool dashed_gap, dashed_line_break, custom_value, conditional_prelude, after_at;
} StyleScan;

static void scan_style_name(StyleScan *style, int32_t c, bool escaped) {
    int32_t upper = ascii_upper(c);
    bool name_char = escaped || (upper >= 'A' && upper <= 'Z') || (c >= '0' && c <= '9') ||
        c == '-' || c == '_' || c >= 0x80;
    if (!escaped && style->name == 0 && upper == 'R') style->gradient_suffix = "ADIAL-GRADIENT";
    else if (!escaped && style->name == 0 && upper == 'L') style->gradient_suffix = "INEAR-GRADIENT";
    else if (!escaped && style->gradient_suffix && *style->gradient_suffix && *style->gradient_suffix == upper)
        style->gradient_suffix++;
    else style->gradient_suffix = NULL;
    // Recognize literal style() and scroll-state() at a name boundary.
    static const char style_suffix[] = "TYLE";
    if (!escaped && style->name == 0 && upper == 'S') style->query_suffix = style_suffix;
    else if (!escaped && style->query_suffix && *style->query_suffix &&
             upper == *style->query_suffix) style->query_suffix++;
    else if (!escaped && style->query_suffix == style_suffix && upper == 'C') {
        style->query_suffix = "ROLL-STATE";
    } else style->query_suffix = NULL;
    if (upper == 'V' && style->name == 0) style->name = 1;
    else if (upper == 'A' && style->name == 1) style->name = 2;
    else if (upper == 'R' && style->name == 2) style->name = 3;
    else if (upper == 'U' && style->name == 0) style->name = 5;
    else if (upper == 'R' && style->name == 5) style->name = 6;
    else if (upper == 'L' && style->name == 6) style->name = 7;
    else style->name = name_char ? 4 : 0;

    // CSS Modules and ICSS use the exact lower-case names local/global/import.
    // A colon starts this match; a name character beyond the final letter
    // invalidates it, so e.g. :localized() is not caught here.
    static const char module_suffix[] = "localglobalimport";
    if (c == ':' && !escaped) style->module_name = 1;
    else if (style->module_name == 1 && !escaped && c == 'g') style->module_name = 7;
    else if (style->module_name == 1 && !escaped && c == 'i') style->module_name = 13;
    else if (style->module_name >= 1 && style->module_name < sizeof(module_suffix) &&
             style->module_name != 6 && style->module_name != 12 &&
             !escaped && c == module_suffix[style->module_name - 1]) {
        style->module_name++;
    } else style->module_name = 0;

    // These pseudo-elements have opaque selector arguments. Track the name
    // here so the same balanced-block scan also handles nested parentheses.
    if (!escaped && style->pseudo_start && upper == 'C') style->pseudo_suffix = "UE-REGION";
    else if (!escaped && style->pseudo_start && upper == 'P') style->pseudo_suffix = "ART";
    else if (!escaped && style->pseudo_suffix && *style->pseudo_suffix && *style->pseudo_suffix == upper) {
        style->pseudo_suffix++;
    }
    else style->pseudo_suffix = NULL;
    style->pseudo_start = !escaped && c == ':' && style->previous == ':';

    // CSS escapes contribute decoded characters to an identifier. A comment
    // or whitespace can occur between a completed property name and its colon.
    if ((html_space(c) || c == '/') && !escaped && style->dashed == 2) {
        style->dashed_gap = true;
        return;
    }
    if (style->dashed_gap) style->dashed = 0;
    style->dashed_gap = false;
    style->dashed_line_break = false;
    if (!name_char) style->dashed = 0;
    else if (style->dashed < 2) style->dashed = c == '-' ? style->dashed + 1 : 3;
}

static void scan_style_char(StyleScan *style, int32_t c) {
    if (style->opaque) return;
    if (c == '\r' || c == '\n' || c == '\f') {
        // A newline in a CSS string either belongs to an escape or ends a
        // bad-string token. Host indentation must not change either case.
        if (style->depth || style->custom_value || style->quote) {
            style->opaque = true;
            return;
        }
        if (style->dashed == 2) style->dashed_line_break = true;
    }
    if (style->comment) {
        if (style->previous == '*' && c == '/') {
            style->comment = false;
            c = 0;
        }
        style->previous = c;
        return;
    }
    if (style->quote) {
        if (style->escaped) style->escaped = false;
        else if (c == '\\') style->escaped = true;
        else if (c == style->quote) {
            style->quote = 0;
            style->name = 0;
            style->gradient_suffix = NULL;
        }
        return;
    }
    if (style->hex_cr) {
        style->hex_cr = false;
        if (c == '\n') return;
    }
    if (style->escaped) {
        // CSS takes up to six hex digits and consumes one following space.
        // Non-hex escapes represent the escaped character itself.
        int32_t upper = ascii_upper(c);
        int digit = c >= '0' && c <= '9' ? c - '0' : upper >= 'A' && upper <= 'F' ? upper - 'A' + 10 : -1;
        if (digit >= 0 && style->hex_digits < 6) {
            style->escape_value = style->escape_value * 16 + digit;
            style->hex_digits++;
            return;
        }
        style->escaped = false;
        if (style->hex_digits) {
            scan_style_name(style, style->escape_value, true);
            style->escape_value = 0;
            style->hex_digits = 0;
            if (html_space(c)) {
                style->hex_cr = c == '\r';
                return;
            }
        } else {
            scan_style_name(style, c, true);
            return;
        }
    }
    if (c == '\\') {
        style->escaped = true;
        style->previous = 0;
        return;
    }
    if (style->previous == '/' && c == '*') {
        style->comment = true;
        style->previous = 0;
        return;
    }
    if (style->previous == '/' && style->dashed_gap) {
        style->dashed = 0;
        style->dashed_gap = false;
        style->dashed_line_break = false;
    }
    if (!style->depth) {
        if (c == ':' && style->dashed == 2) {
            style->custom_value = true;
            if (style->dashed_line_break) style->opaque = true;
        } else if (c == ';' || c == '}') {
            style->custom_value = false;
        }
    }
    if (c == '\'' || c == '"') style->quote = c;
    // If a media or supports condition runs to EOF, every remaining byte may belong
    // to its value. Leave that style body out of the host indentation pass.
    if (style->conditional_depth) {
        if (c == '(') style->conditional_depth++;
        else if (c == ')') style->conditional_depth--;
    } else {
        bool name_char = (c >= '0' && c <= '9') || (ascii_upper(c) >= 'A' && ascii_upper(c) <= 'Z') ||
            c == '-' || c == '_' || c == '\\' || c >= 0x80;
        if (style->conditional_suffix && !*style->conditional_suffix && !name_char) style->conditional_prelude = true;
        if (style->after_at && ascii_upper(c) == 'S') style->conditional_suffix = "UPPORTS";
        else if (style->after_at && ascii_upper(c) == 'M') style->conditional_suffix = "EDIA";
        else if (style->conditional_suffix && *style->conditional_suffix == ascii_upper(c)) style->conditional_suffix++;
        else style->conditional_suffix = NULL;
        style->after_at = c == '@';
        if (c == '(' && style->conditional_prelude) style->conditional_depth = 1;
        else if (c == '{' || c == '}' || c == ';') style->conditional_prelude = false;
    }
    if (c == '(' && (style->query_depth || (style->query_suffix && !*style->query_suffix))) {
        style->query_depth++;
    } else if (c == ')' && style->query_depth) style->query_depth--;
    // An unfinished gradient consumes the rest of the stylesheet, including
    // anything that looks like a later declaration. Keep those bytes in HTML.
    if (c == '(' && (style->gradient_depth || (style->gradient_suffix && !*style->gradient_suffix))) {
        style->gradient_depth++;
    } else if (c == ')' && style->gradient_depth) style->gradient_depth--;
    bool module_argument = style->module_name == 6 || style->module_name == 12 || style->module_name == 18;
    // The optional -REGION suffix has not started at the end of ::cue.
    bool pseudo_argument = style->pseudo_suffix &&
        (*style->pseudo_suffix == '\0' || *style->pseudo_suffix == '-');
    // Unquoted URL tokens can be opaque too. Host indentation must not
    // accumulate inside their authored line breaks, even for bad URLs.
    bool opaque_call = style->name == 3 || style->name == 7 || module_argument || pseudo_argument;
    if (style->depth || style->custom_value || (c == '(' && opaque_call)) {
        char close = c == '(' ? ')' : c == '[' ? ']' : c == '{' ? '}' : 0;
        if (close) {
            // On an exceptionally deep fallback, preserve rather than guess.
            if (style->depth == sizeof(style->closer)) style->opaque = true;
            else style->closer[style->depth++] = close;
        } else if (style->depth && c == style->closer[style->depth - 1]) {
            style->depth--;
        }
    }
    scan_style_name(style, c, false);
    style->previous = c;
}

// HTML script data can enter a double-escaped region after <!-- and <script.
// In that region the next </script only exits the region; it is not a tag.
typedef struct {
    enum { SCRIPT_DATA, SCRIPT_LT, SCRIPT_BANG, SCRIPT_BANG_DASH,
        SCRIPT_ESCAPED, SCRIPT_DASH, SCRIPT_DASH_DASH, SCRIPT_ESCAPED_LT,
        SCRIPT_DOUBLE_START, SCRIPT_DOUBLE_END } state;
    unsigned name_index;
    bool doubled, opaque;
} ScriptScan;

static void scan_script_char(ScriptScan *script, int32_t c) {
    static const char name[] = "SCRIPT";
    for (;;) {
        switch (script->state) {
            case SCRIPT_DATA:
                if (c == '<') script->state = SCRIPT_LT;
                return;
            case SCRIPT_LT:
                script->state = c == '!' ? SCRIPT_BANG : SCRIPT_DATA;
                if (c == '!') return;
                break;
            case SCRIPT_BANG:
            case SCRIPT_BANG_DASH:
                if (c == '-') {
                    script->state = script->state == SCRIPT_BANG ? SCRIPT_BANG_DASH : SCRIPT_DASH_DASH;
                    return;
                }
                script->state = SCRIPT_DATA;
                break;
            case SCRIPT_ESCAPED:
            case SCRIPT_DASH:
            case SCRIPT_DASH_DASH:
                if (c == '-') script->state = script->state == SCRIPT_ESCAPED ? SCRIPT_DASH : SCRIPT_DASH_DASH;
                else if (c == '<') script->state = SCRIPT_ESCAPED_LT;
                else if (c == '>' && script->state == SCRIPT_DASH_DASH) {
                    script->state = SCRIPT_DATA;
                    script->doubled = false;
                } else script->state = SCRIPT_ESCAPED;
                return;
            case SCRIPT_ESCAPED_LT:
                if (script->doubled && c == '/') {
                    script->state = SCRIPT_DOUBLE_END;
                    script->name_index = 0;
                    return;
                }
                if (!script->doubled && ascii_upper(c) == name[0]) {
                    script->state = SCRIPT_DOUBLE_START;
                    script->name_index = 1;
                    return;
                }
                script->state = SCRIPT_ESCAPED;
                break;
            case SCRIPT_DOUBLE_START:
            case SCRIPT_DOUBLE_END:
                if (name[script->name_index] && ascii_upper(c) == name[script->name_index]) {
                    script->name_index++;
                    return;
                }
                if (!name[script->name_index] && (c == '>' || c == '/' || html_space(c))) {
                    script->doubled = script->state == SCRIPT_DOUBLE_START;
                    script->opaque |= script->doubled;
                    script->state = SCRIPT_ESCAPED;
                    return;
                }
                script->state = SCRIPT_ESCAPED;
                break;
        }
    }
}

static bool scan_raw_text(Scanner *scanner, TSLexer *lexer, bool allow_text_eof,
                          bool classify_style, bool classify_script) {
    if (scanner->tags.size == 0) {
        return false;
    }

    TagType type = array_back(&scanner->tags)->type;
    const char *end_delimiter = raw_end_delimiter(type);
    if (!end_delimiter && type != PLAINTEXT) {
        return false;
    }
    classify_style = classify_style && type == STYLE;
    classify_script = classify_script && type == SCRIPT;

    lexer->mark_end(lexer);
    bool consumed = false;
    unsigned delimiter_index = 0;
    int32_t previous = 0, last = 0;
    StyleScan style = {0};
    ScriptScan script = {0};
    while (!lexer->eof(lexer)) {
        int32_t c = lexer->lookahead;
        if (end_delimiter && !end_delimiter[delimiter_index]) {
            // A longer name, e.g. </script-example>, is part of the text.
            if (!script.doubled && (c == '>' || c == '/' || html_space(c))) {
                break;
            }
        } else if (end_delimiter && ascii_upper(c) == end_delimiter[delimiter_index]) {
            delimiter_index++;
            previous = last;
            last = c;
            if (classify_style) scan_style_char(&style, c);
            if (classify_script) scan_script_char(&script, c);
            advance(lexer);
            continue;
        }

        if (delimiter_index) {
            // Retry at this character: the second '<' in '<</script>'
            // might start the actual end tag.
            lexer->mark_end(lexer);
            consumed = true;
            delimiter_index = 0;
        } else {
            previous = last;
            last = c;
            if (classify_style) scan_style_char(&style, c);
            if (classify_script) scan_script_char(&script, c);
            advance(lexer);
            lexer->mark_end(lexer);
            consumed = true;
        }
    }
    if (lexer->eof(lexer)) {
        // Only accept an unterminated body if Topiary's mandatory EOF trim
        // and LF leave its text unchanged. Don't let it invent a closing tag.
        if (allow_text_eof && last == '\n' && !renderer_whitespace(previous)) {
            lexer->mark_end(lexer);
            lexer->result_symbol = TEXT_ELEMENT_EOF;
            pop_tag(scanner);
            return true;
        }
        if (type == PLAINTEXT) return false;
        if (delimiter_index) {
            lexer->mark_end(lexer);
            consumed = true;
        }
    }

    // Do not append host whitespace to an unfinished CSS payload.
    // An added newline would turn an EOF-terminated string into a bad string.
    // A custom declaration can consume the style boundary even with a
    // balanced value. Host indentation would add bytes to that value.
    lexer->result_symbol = (style.opaque || style.query_depth || style.conditional_depth || style.gradient_depth ||
                            style.quote || style.custom_value) ?
        OPAQUE_STYLE_TEXT : script.opaque ? OPAQUE_SCRIPT_TEXT : RAW_TEXT;
    return consumed;
}

static void pop_tag(Scanner *scanner) {
    Tag popped_tag = array_pop(&scanner->tags);
    tag_free(&popped_tag);
}

static bool scan_implicit_end_tag(Scanner *scanner, TSLexer *lexer, bool is_closing_tag) {
    Tag *parent = scanner->tags.size == 0 ? NULL : array_back(&scanner->tags);

    String tag_name = scan_tag_name(lexer, is_closing_tag);
    if (tag_name.size == 0) {
        array_delete(&tag_name);
        return false;
    }

    Tag next_tag = tag_for_name(tag_name);

    if (is_closing_tag) {
        // The tag correctly closes the topmost element on the stack
        if (scanner->tags.size > 0 && tag_eq(array_back(&scanner->tags), &next_tag)) {
            tag_free(&next_tag);
            return false;
        }

        // Otherwise, dig deeper and queue implicit end tags (to be nice in
        // the case of malformed HTML)
        for (unsigned i = scanner->tags.size; i > 0; i--) {
            if (tag_eq(&scanner->tags.contents[i - 1], &next_tag)) {
                pop_tag(scanner);
                lexer->result_symbol = IMPLICIT_END_TAG;
                tag_free(&next_tag);
                return true;
            }
        }
    } else if (parent && !tag_can_contain(parent, &next_tag)) {
        pop_tag(scanner);
        lexer->result_symbol = IMPLICIT_END_TAG;
        tag_free(&next_tag);
        return true;
    }

    tag_free(&next_tag);
    return false;
}

// Keep this list in sync with the opaque elements in html/formatting.scm.
// An injection under one of those leaves has no matching atom in Topiary.
static bool inside_opaque_element(const Scanner *scanner) {
    static const char *const custom_names[] = {
        "LISTING",
    };
    for (unsigned i = 0; i < scanner->tags.size; i++) {
        const Tag *tag = &scanner->tags.contents[i];
        switch (tag->type) {
            case PRE: case TEXTAREA: case TITLE: case IFRAME: case NOSCRIPT:
            case XMP: case NOEMBED: case NOFRAMES: case PLAINTEXT:
                return true;
            case CUSTOM:
                for (unsigned j = 0; j < sizeof(custom_names) / sizeof(*custom_names); j++) {
                    const String *name = &tag->custom_tag_name;
                    if (name->size == strlen(custom_names[j]) &&
                        memcmp(name->contents, custom_names[j], name->size) == 0) {
                        return true;
                    }
                }
                break;
            default:
                break;
        }
    }
    return false;
}

static bool inside_foreign_ancestry(const Scanner *scanner, unsigned ancestors) {
    for (unsigned i = 0; i < ancestors; i++) {
        TagType parent = scanner->tags.contents[i].type;
        if (parent == SVG || parent == MATH) {
            return true;
        }
    }
    return false;
}

// A foreignObject remains SVG itself (including its CDATA handling), but
// starts its children in HTML. A nested SVG or MathML starts a new context.
static bool foreign_text_context(const Scanner *scanner, unsigned ancestors) {
    TagType foreign = CUSTOM;
    for (unsigned i = 0; i < ancestors; i++) {
        const Tag *tag = &scanner->tags.contents[i];
        if (foreign == CUSTOM && (tag->type == SVG || tag->type == MATH)) {
            foreign = tag->type;
        } else if (foreign == SVG && tag->type == CUSTOM) {
            static const char name[] = "FOREIGNOBJECT";
            const String *custom = &tag->custom_tag_name;
            if (custom->size == sizeof(name) - 1 &&
                memcmp(custom->contents, name, sizeof(name) - 1) == 0) {
                foreign = CUSTOM;
            }
        }
    }
    return foreign != CUSTOM;
}

static bool known_html_name(const Scanner *scanner, TagType type, unsigned ancestors) {
    switch (type) {
        case CUSTOM: case SCRIPT: case STYLE: case TITLE: case TEXTAREA: case IFRAME:
        case XMP: case NOEMBED: case NOFRAMES: case PLAINTEXT:
            return false;
        default:
            break;
    }
    return !inside_foreign_ancestry(scanner, ancestors);
}

static bool slashable_void(TagType type) {
    switch (type) {
        case AREA: case BASE: case BR: case COL: case EMBED: case HR: case IMG:
        case INPUT: case LINK: case META: case PARAM: case SOURCE: case TRACK: case WBR:
            return true;
        default:
            return false;
    }
}

// Expose the parent categories for the formatter's sibling-sequence queries.
// A text predicate on a regular tag name only runs after the matcher has
// collected the whole sequence, even in an element that cannot use the rule.
static enum TokenType html_start_name(TagType type) {
    switch (type) {
        case HTML: case HEAD:
            return DOCUMENT_CONTAINER_NAME;
        case BODY:
            return BODY_NAME;
        case ARTICLE: case ASIDE: case BLOCKQUOTE: case DIV: case FOOTER:
        case HEADER: case MAIN: case NAV: case SECTION:
            return FLOW_CONTAINER_NAME;
        case UL: case OL: case DL: case TABLE: case THEAD: case TBODY: case TFOOT: case TR:
            return LIST_CONTAINER_NAME;
        case ADDRESS: case DETAILS: case FIELDSET: case FIGURE: case FORM:
        case H1: case H2: case H3: case H4: case H5: case H6: case HGROUP: case P: case PRE:
            return FLOW_ITEM_NAME;
        case LI: case DT: case DD: case CAPTION: case COLGROUP: case TH: case TD:
            return LIST_ITEM_NAME;
        default:
            return HTML_TAG_NAME;
    }
}

static bool scan_start_tag_name(Scanner *scanner, TSLexer *lexer) {
    String tag_name = scan_tag_name(lexer, false);
    if (tag_name.size == 0) {
        array_delete(&tag_name);
        return false;
    }

    Tag tag = tag_for_name(tag_name);
    bool foreign_context = foreign_text_context(scanner, scanner->tags.size);
    bool html_text_element = !foreign_context &&
        (tag.type == TITLE || tag.type == TEXTAREA || tag.type == IFRAME ||
         tag.type == XMP || tag.type == NOEMBED || tag.type == NOFRAMES || tag.type == PLAINTEXT);
    // Foreign script and style contents use different character-data rules.
    // Keep injection eligibility unchanged for the entire foreign subtree.
    bool suppress_injection = (tag.type == SCRIPT || tag.type == STYLE) &&
        (inside_foreign_ancestry(scanner, scanner->tags.size) || inside_opaque_element(scanner));
    bool canonical_name = known_html_name(scanner, tag.type, scanner->tags.size);
    if (canonical_name && slashable_void(tag.type)) {
        array_push(&scanner->tags, tag);
        lexer->result_symbol = tag.type == HR ? FLOW_VOID_NAME : VOID_TAG_NAME;
        return true;
    }
    array_push(&scanner->tags, tag);
    switch (tag.type) {
        case SCRIPT:
            lexer->result_symbol = suppress_injection ? TEXT_START_TAG_NAME : SCRIPT_START_TAG_NAME;
            break;
        case STYLE:
            lexer->result_symbol = suppress_injection ? TEXT_START_TAG_NAME : STYLE_START_TAG_NAME;
            break;
        default:
            lexer->result_symbol = html_text_element ? TEXT_START_TAG_NAME
                : canonical_name ? html_start_name(tag.type) : START_TAG_NAME;
            break;
    }
    return true;
}

static bool scan_end_tag_name(Scanner *scanner, TSLexer *lexer) {
    String tag_name = scan_tag_name(lexer, true);

    if (tag_name.size == 0) {
        array_delete(&tag_name);
        return false;
    }

    Tag tag = tag_for_name(tag_name);
    if (scanner->tags.size > 0 && tag_eq(array_back(&scanner->tags), &tag) &&
        (tag.type != PLAINTEXT || foreign_text_context(scanner, scanner->tags.size - 1))) {
        bool canonical_name = known_html_name(scanner, tag.type, scanner->tags.size - 1);
        pop_tag(scanner);
        lexer->result_symbol = canonical_name ? HTML_TAG_NAME : END_TAG_NAME;
    } else {
        lexer->result_symbol = ERRONEOUS_END_TAG_NAME;
    }

    tag_free(&tag);
    return true;
}

static bool scan_attribute_solidus(Scanner *scanner, TSLexer *lexer, const bool *valid_symbols) {
    advance(lexer);
    if (lexer->lookahead == '>') {
        // HTML ignores the self-closing flag on text-only start tags. Foreign
        // script and style also use the text rule, but can actually self-close.
        if (valid_symbols[RAW_START_SOLIDUS_CLOSE] && scanner->tags.size > 0) {
            TagType type = array_back(&scanner->tags)->type;
            unsigned ancestors = scanner->tags.size - 1;
            bool foreign = type == SCRIPT || type == STYLE
                ? inside_foreign_ancestry(scanner, ancestors)
                : foreign_text_context(scanner, ancestors);
            if (!foreign) {
                advance(lexer);
                lexer->mark_end(lexer);
                lexer->result_symbol = RAW_START_SOLIDUS_CLOSE;
                return true;
            }
        }
        if (!valid_symbols[SELF_CLOSING_TAG_DELIMITER] || scanner->tags.size == 0) return false;
        advance(lexer);
        pop_tag(scanner);
        lexer->result_symbol = SELF_CLOSING_TAG_DELIMITER;
        return true;
    }
    // A slash that does not close the tag is ignored by the browser. Keep
    // the slash in the CST and let the attribute lexer reconsume what follows.
    if (valid_symbols[ATTRIBUTE_STRAY_SOLIDUS]) {
        lexer->result_symbol = ATTRIBUTE_STRAY_SOLIDUS;
        return true;
    }
    return false;
}

static bool scan(Scanner *scanner, TSLexer *lexer, const bool *valid_symbols) {
    bool end_tag_name_valid = valid_symbols[END_TAG_NAME] || valid_symbols[ERRONEOUS_END_TAG_NAME];
    if (valid_symbols[RAW_TEXT] && !valid_symbols[START_TAG_NAME] && !valid_symbols[END_TAG_NAME]) {
        return scan_raw_text(scanner, lexer, valid_symbols[TEXT_ELEMENT_EOF],
            valid_symbols[OPAQUE_STYLE_TEXT], valid_symbols[OPAQUE_SCRIPT_TEXT]);
    }

    // Whitespace outside tag syntax belongs to the content text token.
    if (valid_symbols[START_TAG_NAME] || valid_symbols[END_TAG_NAME] ||
        valid_symbols[SELF_CLOSING_TAG_DELIMITER] || valid_symbols[MISSING_ATTRIBUTE_VALUE] ||
        valid_symbols[ATTRIBUTE_STRAY_SOLIDUS] || valid_symbols[RAW_START_SOLIDUS_CLOSE]) {
        while (html_space(lexer->lookahead)) {
            skip(lexer);
        }
    }

    // A void element cannot consume any following text (including spaces).
    if (valid_symbols[IMPLICIT_END_TAG] && scanner->tags.size > 0 &&
        tag_is_void(array_back(&scanner->tags))) {
        lexer->mark_end(lexer);
        pop_tag(scanner);
        lexer->result_symbol = IMPLICIT_END_TAG;
        return true;
    }

    switch (lexer->lookahead) {
        case '>':
            // Only a plain tag close ends an omitted attribute value; slash
            // belongs to an unquoted value. Don't consume the tag close here.
            if (valid_symbols[MISSING_ATTRIBUTE_VALUE] && !valid_symbols[START_TAG_NAME]) {
                lexer->mark_end(lexer);
                lexer->result_symbol = MISSING_ATTRIBUTE_VALUE;
                return true;
            }
            if (valid_symbols[VOID_TAG_CLOSE] && scanner->tags.size > 0 &&
                slashable_void(array_back(&scanner->tags)->type)) {
                advance(lexer);
                pop_tag(scanner);
                lexer->result_symbol = VOID_TAG_CLOSE;
                return true;
            }
            break;

        case '<':
            lexer->mark_end(lexer);
            advance(lexer);

            if (lexer->lookahead == '/') {
                advance(lexer);
                if (valid_symbols[BOGUS_COMMENT] &&
                    !(lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') &&
                    !(lexer->lookahead >= 'a' && lexer->lookahead <= 'z')) {
                    // HTML treats a non-letter after `</` as bogus markup,
                    // not as a close of the currently open element.
                    return scan_bogus_comment(lexer);
                }
                return valid_symbols[IMPLICIT_END_TAG] &&
                    scan_implicit_end_tag(scanner, lexer, true);
            }

            if (valid_symbols[LITERAL_LESS_THAN] && !valid_symbols[START_TAG_NAME] &&
                !valid_symbols[END_TAG_NAME] && lexer->lookahead != '!' &&
                lexer->lookahead != '?' &&
                !(lexer->lookahead >= 'A' && lexer->lookahead <= 'Z') &&
                !(lexer->lookahead >= 'a' && lexer->lookahead <= 'z')) {
                lexer->mark_end(lexer);
                lexer->result_symbol = LITERAL_LESS_THAN;
                return true;
            }

            if (lexer->lookahead == '!') {
                advance(lexer);
                if (valid_symbols[CDATA] && lexer->lookahead == '[') {
                    return scan_cdata(lexer, valid_symbols[BOGUS_COMMENT],
                        inside_foreign_ancestry(scanner, scanner->tags.size));
                }
                if (lexer->lookahead == '-') {
                    return scan_comment(lexer, valid_symbols[BOGUS_COMMENT]);
                }
                if (valid_symbols[BOGUS_COMMENT]) {
                    // Leave real doctypes to the built-in lexer.
                    for (const char *keyword = "DOCTYPE"; *keyword; keyword++) {
                        if (ascii_upper(lexer->lookahead) != *keyword) {
                            return scan_bogus_comment(lexer);
                        }
                        advance(lexer);
                    }
                }
                return false;
            }

            if (valid_symbols[BOGUS_COMMENT] && lexer->lookahead == '?') {
                return scan_bogus_comment(lexer);
            }

            if (valid_symbols[IMPLICIT_END_TAG]) {
                return scan_implicit_end_tag(scanner, lexer, false);
            }
            break;

        case '\0':
            // A missing ordinary end tag at EOF needs no output bytes.
            if (lexer->eof(lexer) && valid_symbols[IMPLICIT_END_TAG] && scanner->tags.size > 0) {
                lexer->mark_end(lexer);
                pop_tag(scanner);
                lexer->result_symbol = IMPLICIT_END_TAG;
                return true;
            }
            break;

        case '/':
            if (valid_symbols[SELF_CLOSING_TAG_DELIMITER] || valid_symbols[ATTRIBUTE_STRAY_SOLIDUS] ||
                valid_symbols[RAW_START_SOLIDUS_CLOSE]) {
                return scan_attribute_solidus(scanner, lexer, valid_symbols);
            }
            break;

        default:
            if ((valid_symbols[START_TAG_NAME] || end_tag_name_valid) && !valid_symbols[RAW_TEXT]) {
                return valid_symbols[START_TAG_NAME] ? scan_start_tag_name(scanner, lexer)
                                                     : scan_end_tag_name(scanner, lexer);
            }
    }

    return false;
}

void *tree_sitter_html_external_scanner_create() {
    Scanner *scanner = (Scanner *)ts_calloc(1, sizeof(Scanner));
    return scanner;
}

bool tree_sitter_html_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
    Scanner *scanner = (Scanner *)payload;
    return scan(scanner, lexer, valid_symbols);
}

unsigned tree_sitter_html_external_scanner_serialize(void *payload, char *buffer) {
    Scanner *scanner = (Scanner *)payload;
    return serialize(scanner, buffer);
}

void tree_sitter_html_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
    Scanner *scanner = (Scanner *)payload;
    deserialize(scanner, buffer, length);
}

void tree_sitter_html_external_scanner_destroy(void *payload) {
    Scanner *scanner = (Scanner *)payload;
    for (unsigned i = 0; i < scanner->tags.size; i++) {
        tag_free(&scanner->tags.contents[i]);
    }
    array_delete(&scanner->tags);
    ts_free(scanner);
}
