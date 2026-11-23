; Whitespace at content boundaries is represented by `text` nodes, not a
; separator to reconstruct. This includes gaps in html, head and body.
; Do not reindent literal content or attribute values.
; Topiary only trims trailing LF bytes from unmarked leaves. The directive
; scans the document's atoms, so don't apply it to leaves it cannot affect.
(([(text) (raw_text) (opaque_style_text) (opaque_script_text) (attribute_value)] @keep_whitespace)
  (#match? @keep_whitespace "\n\\z"))

(html_tag_name) @lower_case

; Global HTML attributes on recognized tags. Do not fold custom element or
; foreign descendant attributes, or arbitrary data-/aria- and event names.
(([(start_tag (tag_name (html_tag_name)) (attribute (attribute_name) @lower_case))
   (void_tag (tag_name (html_tag_name)) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name)) (attribute (attribute_name) @lower_case))])
  (#match? @lower_case "(?i-u)^(accesskey|class|contenteditable|dir|draggable|hidden|id|lang|slot|spellcheck|style|tabindex|title)$"))

((void_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
  (#match? @append_delimiter "(?i-u)^meta$")
  (#match? @lower_case "(?i-u)^(charset|content|http-equiv|name)$")
  (#delimiter! ""))

(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
  (#match? @append_delimiter "(?i-u)^a$")
  (#match? @lower_case "(?i-u)^(download|href|hreflang|ping|referrerpolicy|rel|target|type)$")
  (#delimiter! ""))
((void_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
  (#match? @append_delimiter "(?i-u)^area$")
  (#match? @lower_case "(?i-u)^(alt|coords|download|href|ping|referrerpolicy|rel|shape|target)$")
  (#delimiter! ""))
((void_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (#match? @append_delimiter "(?i-u)^link$")
   (#match? @lower_case "(?i-u)^(as|crossorigin|href|hreflang|imagesizes|imagesrcset|integrity|media|referrerpolicy|rel|sizes|type)$")
   (#delimiter! ""))
((void_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (#match? @append_delimiter "(?i-u)^img$")
   (#match? @lower_case "(?i-u)^(alt|crossorigin|decoding|fetchpriority|height|ismap|loading|referrerpolicy|sizes|src|srcset|usemap|width)$")
   (#delimiter! ""))
((void_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
    (#match? @append_delimiter "(?i-u)^source$")
    (#match? @lower_case "(?i-u)^(height|media|sizes|src|srcset|type|width)$")
    (#delimiter! ""))

((void_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (#match? @append_delimiter "(?i-u)^input$")
   (#match? @lower_case "(?i-u)^(accept|alt|autocomplete|checked|dirname|disabled|form|formaction|formenctype|formmethod|formnovalidate|formtarget|height|list|max|maxlength|min|minlength|multiple|name|pattern|placeholder|readonly|required|size|src|step|type|value|width)$")
   (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^button$")
   (#match? @lower_case "(?i-u)^(disabled|form|formaction|formenctype|formmethod|formnovalidate|formtarget|name|type|value)$")
   (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^form$")
    (#match? @lower_case "(?i-u)^(accept-charset|action|autocomplete|enctype|method|name|novalidate|rel|target)$")
    (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^select$")
   (#match? @lower_case "(?i-u)^(autocomplete|disabled|form|multiple|name|required|size)$")
   (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^(option|optgroup)$")
   (#match? @lower_case "(?i-u)^(disabled|label)$")
   (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^option$")
   (#match? @lower_case "(?i-u)^(selected|value)$")
   (#delimiter! ""))

(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^(audio|video)$")
   (#match? @lower_case "(?i-u)^(autoplay|controls|controlslist|crossorigin|disableremoteplayback|loop|muted|preload|src)$")
   (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^video$")
  (#match? @lower_case "(?i-u)^(disablepictureinpicture|height|playsinline|poster|width)$")
  (#delimiter! ""))

(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^(td|th)$")
   (#match? @lower_case "(?i-u)^(colspan|headers|rowspan)$")
   (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^th$")
   (#match? @lower_case "(?i-u)^(abbr|scope)$")
   (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (void_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^(col|colgroup)$")
    (#match? @lower_case "(?i-u)^span$")
    (#delimiter! ""))

(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^ol$")
   (#match? @lower_case "(?i-u)^(reversed|start|type)$")
   (#delimiter! ""))
(([(start_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))
   (self_closing_tag (tag_name (html_tag_name) @append_delimiter) (attribute (attribute_name) @lower_case))])
   (#match? @append_delimiter "(?i-u)^li$")
   (#match? @lower_case "(?i-u)^value$")
   (#delimiter! ""))

; The host grammar does not distinguish RCDATA or all raw-text element bodies.
; Keep these subtrees opaque so tag-like text in them cannot be rewritten.
; Keep the scanner's inside_opaque_element list in sync with this predicate.
((element (start_tag (tag_name) @do_nothing)) @leaf
  (#match? @do_nothing "(?i-u)^(pre|textarea|title|listing|xmp|iframe|noembed|noframes|noscript|plaintext)$"))

; Separate attributes, but never add whitespace around `=`.
(attribute) @prepend_space
; End-tag attributes are a parse error, but browsers still close the element.
; Do not reformat the ignored attributes or move a `>` out of their quotes.
[(end_tag (end_tag_attributes)) (erroneous_end_tag (end_tag_attributes))] @leaf
; Template directives can supply complete attributes or the whitespace before
; them. Do not insert delimiters inside ordinary tags with these markers.
((element [(start_tag) (void_tag) (self_closing_tag)] @leaf)
  (#match? @leaf "\\{[{%#]"))
; Pandoc conditionals can also attach directly to the element name or value.
((element [(start_tag) (void_tag) (self_closing_tag)] @leaf)
  (#match? @leaf "(?s)\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*\\$endif\\$"))
((attribute (attribute_name) "=" @append_delimiter (missing_attribute_value))
  (#delimiter! "\"\""))

; A stray quote in a bare value is data. Keep the original spelling instead
; of introducing a quoted delimiter that would end the value prematurely.
((attribute (attribute_value) @prepend_delimiter @append_delimiter)
  (#not-match? @append_delimiter "[\"']")
  (#delimiter! "\""))

; Prefer double quotes only if the value does not contain a literal double quote.
((quoted_attribute_value "'" @delete . "'" @delete) @prepend_delimiter
  (#delimiter! "\"\""))
((quoted_attribute_value
    "'" @delete
    (attribute_value) @prepend_delimiter @append_delimiter
    "'" @delete)
  (#match? @append_delimiter "^[^\"]*$")
  (#delimiter! "\""))

; Preserve explicit self-closing syntax (including in foreign content), and
; insert the slash only for HTML void elements with an ordinary start tag.
[(self_closing_tag "/>" @prepend_space) (void_tag "/>" @prepend_space)]
((void_tag ">" @prepend_delimiter)
  (#delimiter! " /"))

; The legacy payload (including public/system IDs) is opaque. For HTML5,
; replace the payload with a single space and a lowercase name.
((doctype (doctype_payload) @do_nothing) @leaf
  (#match? @do_nothing "^[ \t\r\n\f]+$"))
((doctype "doctype" @append_delimiter
    (doctype_payload) @delete)
  (#match? @delete "(?i)^[ \t\r\n\f]*html[ \t\r\n\f]*$")
  (#delimiter! " html"))
; A doctype after the initial one is ignored by HTML parsing, but a spacer
; inserted beside it can become a text node in the implicit head or body.

; Do not insert or reindent whitespace between flow, list or table children.
; It's DOM text, and CSS can make it visible even between block elements.
; Keep malformed list boundaries opaque when a nested `<` can hide a close
; tag from the HTML tokenizer but not from the CST.
((element (start_tag (tag_name (html_tag_name (list_container_name)))) (end_tag)) @leaf
  (#match? @leaf "<[A-Za-z][^>/ \t\r\n\f]*</[A-Za-z]"))

; A single-node ignore can be atomic unless it might contain an injection.
; Topiary needs a separate writable leaf for each injected raw-text body.
((_ (comment) @keep_whitespace . (text)? @allow_blank_line_before . (element) @leaf @keep_whitespace)
  (#any-match? @keep_whitespace "^<!--[ \t\r\n\f]*prettier-ignore[ \t\r\n\f]*-->$")
  (#match? @allow_blank_line_before "^[ \t\r\n\f]*$")
  (#not-match? @leaf "(?i-u:<[ \t\r\n\f]*(script|style))"))

; An injected stylesheet starts at column zero. Indent the whole leaf,
; including continuation lines. Templates with a non-CSS type stay opaque.
((style_element
    (start_tag (tag_name) . (attribute (attribute_name) @keep_whitespace)* .)
    (raw_text) @multi_line_indent_all @prepend_indent_start @prepend_hardline
    (end_tag) @prepend_indent_end @prepend_hardline)
    (#not-match? @keep_whitespace "(?i-u)^(type|lang)$")
    (#match? @multi_line_indent_all "[^ \t\r\n\f]")
    (#not-match? @multi_line_indent_all "^[ \t\r\n\\x{000C}]*<&>[ \t\r\n\\x{000C}]*$")
   (#not-match? @multi_line_indent_all "(?i)(^|[;{])[ \t\r\n\f]*\\*[a-z_-][a-z0-9_-]*[ \t\r\n\f]*:")
      (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*<!\\[CDATA\\[|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\(?:[0-9a-fA-F]{0,6}[\r\n\f]|\\z)")
      (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*<!--[ \t]*[A-Z][A-Z_ ]+:[^{}]*?-->")
     (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*\\{\\{[^{}]+\\}\\}[ \t\r\n\f]*$")
     (#not-match? @multi_line_indent_all "\\{\\{GET\\[[a-zA-Z0-9_.-]+\\]\\}\\}")
    (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*\\$[A-Za-z_][A-Za-z0-9_.-]*\\$[ \t\r\n\f]*$")
    (#not-match? @multi_line_indent_all "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
      (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?i-u::(?:state|active-view-transition-type))\\((?:\\\\[^\r\n]|[^)\\\\\r\n])*[\r\n]")
   (#not-match? @multi_line_indent_all "(?:^|[},]|\\*/)[ \t\r\n\f]*!print[ \t\r\n\f]+[^{}]*\\{")
   (#not-match? @multi_line_indent_all "--[^:;{}\\s]+[ \t\f\r\n]*:[ \t\f]*[\r\n][ \t\f\r\n]*[;}]"))
((style_element
    (start_tag (tag_name) . (attribute (attribute_name) @keep_whitespace)* .
      (attribute . (attribute_name) @lower_case
        [(attribute_value) (quoted_attribute_value) (missing_attribute_value)] @allow_blank_line_before) .
      (attribute (attribute_name) @keep_whitespace)* .)
    (raw_text) @multi_line_indent_all @prepend_indent_start @prepend_hardline
    (end_tag) @prepend_indent_end @prepend_hardline)
  (#match? @lower_case "(?i-u)^type$")
  (#not-match? @keep_whitespace "(?i-u)^(type|lang)$")
      (#match? @allow_blank_line_before "(?i-u)^(text/css|'(?:text/css)?'|\"(?:text/css)?\")?$")
    (#match? @multi_line_indent_all "[^ \t\r\n\f]")
    (#not-match? @multi_line_indent_all "^[ \t\r\n\\x{000C}]*<&>[ \t\r\n\\x{000C}]*$")
   (#not-match? @multi_line_indent_all "(?i)(^|[;{])[ \t\r\n\f]*\\*[a-z_-][a-z0-9_-]*[ \t\r\n\f]*:")
      (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*<!\\[CDATA\\[|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\(?:[0-9a-fA-F]{0,6}[\r\n\f]|\\z)")
      (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*<!--[ \t]*[A-Z][A-Z_ ]+:[^{}]*?-->")
     (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*\\{\\{[^{}]+\\}\\}[ \t\r\n\f]*$")
     (#not-match? @multi_line_indent_all "\\{\\{GET\\[[a-zA-Z0-9_.-]+\\]\\}\\}")
    (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*\\$[A-Za-z_][A-Za-z0-9_.-]*\\$[ \t\r\n\f]*$")
    (#not-match? @multi_line_indent_all "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
      (#not-match? @multi_line_indent_all "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?i-u::(?:state|active-view-transition-type))\\((?:\\\\[^\r\n]|[^)\\\\\r\n])*[\r\n]")
   (#not-match? @multi_line_indent_all "(?:^|[},]|\\*/)[ \t\r\n\f]*!print[ \t\r\n\f]+[^{}]*\\{")
   (#not-match? @multi_line_indent_all "--[^:;{}\\s]+[ \t\f\r\n]*:[ \t\f]*[\r\n][ \t\f\r\n]*[;}]"))

; JS layout mirrors the injection eligibility rules.
((script_element
    (start_tag (tag_name) . (attribute (attribute_name) @keep_whitespace)* .)
    (raw_text) @multi_line_indent_all @prepend_indent_start @prepend_hardline
    (end_tag) @prepend_indent_end @prepend_hardline)
  (#not-match? @keep_whitespace "(?i-u)^(src|type|lang|language)$")
  (#match? @multi_line_indent_all "[^ \t\r\n\f]")
  (#not-match? @multi_line_indent_all "(?:&(?:amp|#0*38|#x0*26);){2}")
     (#not-match? @multi_line_indent_all "`|/\\*|\\\\[\r\n]|^[ \t\r\n\f]*<!\\[CDATA\\[")
      (#not-match? @multi_line_indent_all "\\A(?:[^<'\"/]|'(?:[^'\\\\\r\n]|\\\\[^\r\n])*'|\"(?:[^\"\\\\\r\n]|\\\\[^\r\n])*\"|//[^\r\n\\x{2028}\\x{2029}]*(?:[\r\n\\x{2028}\\x{2029}]|\\z))*(?:(?:<|/[^/])[\\s\\S]*|/)?(?:</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>)")
    (#not-match? @multi_line_indent_all "[=(,][ \t\r\n\f]*\\{\\{|\\{%-?[ \t\r\n\f]*[a-zA-Z]")
    (#not-match? @multi_line_indent_all "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
   (#not-match? @multi_line_indent_all "//[^\r\n\\x{2028}\\x{2029}]*[^\\S\r\n\\x{2028}\\x{2029}](?:[\r\n\\x{2028}\\x{2029}]|$)")
   (#not-match? @multi_line_indent_all "\\bawait[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]"))
((script_element
    (start_tag (tag_name) . (attribute (attribute_name) @keep_whitespace)* .
      (attribute . (attribute_name) @lower_case
        [(attribute_value) (quoted_attribute_value) (missing_attribute_value)] @allow_blank_line_before) .
      (attribute (attribute_name) @keep_whitespace)* .)
    (raw_text) @multi_line_indent_all @prepend_indent_start @prepend_hardline
    (end_tag) @prepend_indent_end @prepend_hardline)
  (#not-match? @keep_whitespace "(?i-u)^(src|type|lang|language)$")
  (#match? @lower_case "(?i-u)^type$")
   (#match? @allow_blank_line_before "(?i-u)^['\"]?(?:module|[ \t\r\n\\x{000C}]*(?:(?:text|application)/(?:x-)?(?:java|ecma)script|text/(?:javascript1\\.[0-5]|jscript|livescript))[ \t\r\n\\x{000C}]*)?['\"]?$")
  (#match? @multi_line_indent_all "[^ \t\r\n\f]")
  (#not-match? @multi_line_indent_all "(?:&(?:amp|#0*38|#x0*26);){2}")
     (#not-match? @multi_line_indent_all "`|/\\*|\\\\[\r\n]|^[ \t\r\n\f]*<!\\[CDATA\\[")
      (#not-match? @multi_line_indent_all "\\A(?:[^<'\"/]|'(?:[^'\\\\\r\n]|\\\\[^\r\n])*'|\"(?:[^\"\\\\\r\n]|\\\\[^\r\n])*\"|//[^\r\n\\x{2028}\\x{2029}]*(?:[\r\n\\x{2028}\\x{2029}]|\\z))*(?:(?:<|/[^/])[\\s\\S]*|/)?(?:</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>)")
    (#not-match? @multi_line_indent_all "[=(,][ \t\r\n\f]*\\{\\{|\\{%-?[ \t\r\n\f]*[a-zA-Z]")
    (#not-match? @multi_line_indent_all "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
   (#not-match? @multi_line_indent_all "//[^\r\n\\x{2028}\\x{2029}]*[^\\S\r\n\\x{2028}\\x{2029}](?:[\r\n\\x{2028}\\x{2029}]|$)")
   (#not-match? @multi_line_indent_all "\\bawait[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]"))

; A bare type attribute is the empty classic-script type.
((script_element
    (start_tag (tag_name) . (attribute (attribute_name) @keep_whitespace)* .
      (attribute . (attribute_name) @lower_case .) @do_nothing .
      (attribute (attribute_name) @keep_whitespace)* .)
    (raw_text) @multi_line_indent_all @prepend_indent_start @prepend_hardline
    (end_tag) @prepend_indent_end @prepend_hardline)
   (#match? @do_nothing "(?i-u)^type$")
   (#not-match? @keep_whitespace "(?i-u)^(src|type|lang|language)$")
   (#match? @multi_line_indent_all "[^ \t\r\n\f]")
   (#not-match? @multi_line_indent_all "(?:&(?:amp|#0*38|#x0*26);){2}")
   (#not-match? @multi_line_indent_all "`|/\\*|\\\\[\r\n]|^[ \t\r\n\f]*<!\\[CDATA\\[")
   (#not-match? @multi_line_indent_all "\\A(?:[^<'\"/]|'(?:[^'\\\\\r\n]|\\\\[^\r\n])*'|\"(?:[^\"\\\\\r\n]|\\\\[^\r\n])*\"|//[^\r\n\\x{2028}\\x{2029}]*(?:[\r\n\\x{2028}\\x{2029}]|\\z))*(?:(?:<|/[^/])[\\s\\S]*|/)?(?:</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>)")
   (#not-match? @multi_line_indent_all "[=(,][ \t\r\n\f]*\\{\\{|\\{%-?[ \t\r\n\f]*[a-zA-Z]")
   (#not-match? @multi_line_indent_all "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
   (#not-match? @multi_line_indent_all "//[^\r\n\\x{2028}\\x{2029}]*[^\\S\r\n\\x{2028}\\x{2029}](?:[\r\n\\x{2028}\\x{2029}]|$)")
   (#not-match? @multi_line_indent_all "\\bawait[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]"))

((script_element
    (start_tag (tag_name) . (attribute (attribute_name) @keep_whitespace)* .
      (attribute . (attribute_name) @lower_case
        [(attribute_value) (quoted_attribute_value)] @allow_blank_line_before) .
      (attribute (attribute_name) @keep_whitespace)* .)
    (raw_text) @multi_line_indent_all @prepend_indent_start @prepend_hardline
    (end_tag) @prepend_indent_end @prepend_hardline)
  (#not-match? @keep_whitespace "(?i-u)^(src|type|lang|language)$")
  (#match? @lower_case "(?i-u)^type$")
   (#match? @allow_blank_line_before "(?i-u)^['\"]?(application/([a-z0-9.+-]+\\+)?json|importmap|speculationrules)['\"]?$")
  (#match? @multi_line_indent_all "[^ \t\r\n\f]")
   (#not-match? @multi_line_indent_all "^[ \t\r\n\f]*(<!\\[CDATA\\[|\\{[ \t\r\n\f]*(&q;|&quot;|&#0*34;|&#[xX]0*22;))")
   (#not-match? @multi_line_indent_all "(?:^|[^\\\\])(?:\\\\\\\\)*\\\\x[0-9a-fA-F]{2}"))
