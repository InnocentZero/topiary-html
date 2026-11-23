; Match CSS only in a nonempty <style> body. Anchor the attribute repetition
; at both ends so it cannot hide a type attribute by matching zero attributes.
; The CSS parser rejects legacy star-prefixed declarations. Leave those
; stylesheets untouched; mirror this guard in the host layout query.
; A leading XML CDATA wrapper is not native CSS, JS, or JSON syntax.
; Labeled prose between legacy HTML comment markers is not a CSS comment.
; Preserve it without treating the prose as the start of a selector.
; CSS string continuations and hex escapes can make added indentation
; significant, including inside an unquoted url().
; A final unpaired backslash consumes EOF, not an injected newline.
; Indenting an injected style also changes the text of multiline comments.
; Keep multiline custom-state and transition-type arguments opaque too.
; The parser emits opaque_style_text for multiline var() instead of raw_text.
; WPT GET substitutions can supply declarations inside a stylesheet.
; Phorge's !print selector rules are passed verbatim to its preprocessor.
; A whitespace-only custom value must not acquire host indentation.
; Preserve literal <&> serialization text; it is not a stylesheet.
((style_element
    (start_tag (tag_name) . (attribute (attribute_name) @attr)* .)
    (raw_text) @injection.content)
    (#not-match? @attr "(?i-u)^(type|lang)$")
    (#match? @injection.content "[^ \t\r\n\f]")
    (#not-match? @injection.content "^[ \t\r\n\\x{000C}]*<&>[ \t\r\n\\x{000C}]*$")
   (#not-match? @injection.content "(?i)(^|[;{])[ \t\r\n\f]*\\*[a-z_-][a-z0-9_-]*[ \t\r\n\f]*:")
      (#not-match? @injection.content "^[ \t\r\n\f]*<!\\[CDATA\\[|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\(?:[0-9a-fA-F]{0,6}[\r\n\f]|\\z)")
      (#not-match? @injection.content "^[ \t\r\n\f]*<!--[ \t]*[A-Z][A-Z_ ]+:[^{}]*?-->")
      (#not-match? @injection.content "^[ \t\r\n\f]*\\{\\{[^{}]+\\}\\}[ \t\r\n\f]*$")
      (#not-match? @injection.content "\\{\\{GET\\[[a-zA-Z0-9_.-]+\\]\\}\\}")
     (#not-match? @injection.content "^[ \t\r\n\f]*\\$[A-Za-z_][A-Za-z0-9_.-]*\\$[ \t\r\n\f]*$")
     (#not-match? @injection.content "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
     (#not-match? @injection.content "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?i-u::(?:state|active-view-transition-type))\\((?:\\\\[^\r\n]|[^)\\\\\r\n])*[\r\n]")
   (#not-match? @injection.content "(?:^|[},]|\\*/)[ \t\r\n\f]*!print[ \t\r\n\f]+[^{}]*\\{")
   (#not-match? @injection.content "--[^:;{}\\s]+[ \t\f\r\n]*:[ \t\f]*[\r\n][ \t\f\r\n]*[;}]")
    (#set! injection.language "embedded-css"))

; A src attribute makes the body inert. A lang/language hint may select a
; language we don't implement. Babel script bodies belong to an external
; transpiler, not the browser's classic or module script parser.
; Inspect both sides of an explicit MIME type.
; The host's whole-body indentation must not alter embedded comments. In
; particular, formatting the body on its own can trim a final line comment.
; Preserve template expressions in JavaScript expression positions and control directives.
; XML can encode a logical AND as two entity references. The HTML raw-text
; node still contains the references, not the JavaScript seen by an XML parser.
; Ignore tag spellings in quoted strings and line comments before the first
; ambiguous '<' or slash. After that point, keep the conservative JSX check.
((script_element
    (start_tag (tag_name) . (attribute (attribute_name) @attr)* .)
    (raw_text) @injection.content)
  (#not-match? @attr "(?i-u)^(src|type|lang|language)$")
  (#match? @injection.content "[^ \t\r\n\f]")
  (#not-match? @injection.content "(?:&(?:amp|#0*38|#x0*26);){2}")
  (#not-match? @injection.content "`|/\\*|\\\\[\r\n]|^[ \t\r\n\f]*<!\\[CDATA\\[")
   (#not-match? @injection.content "\\A(?:[^<'\"/]|'(?:[^'\\\\\r\n]|\\\\[^\r\n])*'|\"(?:[^\"\\\\\r\n]|\\\\[^\r\n])*\"|//[^\r\n\\x{2028}\\x{2029}]*(?:[\r\n\\x{2028}\\x{2029}]|\\z))*(?:(?:<|/[^/])[\\s\\S]*|/)?(?:</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>)")
  (#not-match? @injection.content "[=(,][ \t\r\n\f]*\\{\\{|\\{%-?[ \t\r\n\f]*[a-zA-Z]")
  (#not-match? @injection.content "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
  (#not-match? @injection.content "//[^\r\n\\x{2028}\\x{2029}]*[^\\S\r\n\\x{2028}\\x{2029}](?:[\r\n\\x{2028}\\x{2029}]|$)")
  (#not-match? @injection.content "\\bawait[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]")
  (#set! injection.language "javascript"))

((script_element
    (start_tag (tag_name) . (attribute (attribute_name) @other)* .
      (attribute . (attribute_name) @name
        [(attribute_value) (quoted_attribute_value)] @value) .
      (attribute (attribute_name) @other)* .)
    (raw_text) @injection.content)
  (#not-match? @other "(?i-u)^(src|type|lang|language)$")
  (#match? @name "(?i-u)^type$")
  (#match? @value "(?i-u)^['\"]?(application/([a-z0-9.+-]+\\+)?json|importmap|speculationrules)['\"]?$")
   (#match? @injection.content "[^ \t\r\n\f]")
   ; Script raw text does not decode HTML entities. Angular transfer state
   ; also uses its own &q; marker. Keep encoded bodies for their own readers.
   (#not-match? @injection.content "^[ \t\r\n\f]*(<!\\[CDATA\\[|\\{[ \t\r\n\f]*(&q;|&quot;|&#0*34;|&#[xX]0*22;))")
   ; An odd number of backslashes before xNN is a JS-style hex escape,
   ; not JSON. An even number is valid JSON and can still be injected.
   (#not-match? @injection.content "(?:^|[^\\\\])(?:\\\\\\\\)*\\\\x[0-9a-fA-F]{2}")
  (#set! injection.language "json"))
((script_element
    (start_tag (tag_name) . (attribute (attribute_name) @other)* .
      (attribute . (attribute_name) @name
        [(attribute_value) (quoted_attribute_value) (missing_attribute_value)] @value) .
      (attribute (attribute_name) @other)* .)
    (raw_text) @injection.content)
  (#not-match? @other "(?i-u)^(src|type|lang|language)$")
  (#match? @name "(?i-u)^type$")
  ; HTML strips ASCII whitespace for classic MIME matching, not for module.
  (#match? @value "(?i-u)^['\"]?(?:module|[ \t\r\n\\x{000C}]*(?:(?:text|application)/(?:x-)?(?:java|ecma)script|text/(?:javascript1\\.[0-5]|jscript|livescript))[ \t\r\n\\x{000C}]*)?['\"]?$")
  (#match? @injection.content "[^ \t\r\n\f]")
  (#not-match? @injection.content "(?:&(?:amp|#0*38|#x0*26);){2}")
  (#not-match? @injection.content "`|/\\*|\\\\[\r\n]|^[ \t\r\n\f]*<!\\[CDATA\\[")
   (#not-match? @injection.content "\\A(?:[^<'\"/]|'(?:[^'\\\\\r\n]|\\\\[^\r\n])*'|\"(?:[^\"\\\\\r\n]|\\\\[^\r\n])*\"|//[^\r\n\\x{2028}\\x{2029}]*(?:[\r\n\\x{2028}\\x{2029}]|\\z))*(?:(?:<|/[^/])[\\s\\S]*|/)?(?:</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>)")
  (#not-match? @injection.content "[=(,][ \t\r\n\f]*\\{\\{|\\{%-?[ \t\r\n\f]*[a-zA-Z]")
  (#not-match? @injection.content "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
  (#not-match? @injection.content "//[^\r\n\\x{2028}\\x{2029}]*[^\\S\r\n\\x{2028}\\x{2029}](?:[\r\n\\x{2028}\\x{2029}]|$)")
  (#not-match? @injection.content "\\bawait[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]")
  (#set! injection.language "javascript"))

; A bare type attribute is the empty classic-script type.
((script_element
    (start_tag (tag_name) . (attribute (attribute_name) @other)* .
      (attribute . (attribute_name) .) @type .
      (attribute (attribute_name) @other)* .)
    (raw_text) @injection.content)
  (#match? @type "(?i-u)^type$")
  (#not-match? @other "(?i-u)^(src|type|lang|language)$")
  (#match? @injection.content "[^ \t\r\n\f]")
  (#not-match? @injection.content "(?:&(?:amp|#0*38|#x0*26);){2}")
  (#not-match? @injection.content "`|/\\*|\\\\[\r\n]|^[ \t\r\n\f]*<!\\[CDATA\\[")
  (#not-match? @injection.content "\\A(?:[^<'\"/]|'(?:[^'\\\\\r\n]|\\\\[^\r\n])*'|\"(?:[^\"\\\\\r\n]|\\\\[^\r\n])*\"|//[^\r\n\\x{2028}\\x{2029}]*(?:[\r\n\\x{2028}\\x{2029}]|\\z))*(?:(?:<|/[^/])[\\s\\S]*|/)?(?:</(?:[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*)?[ \t\r\n]*>|<[\\p{XID_Start}_$][\\p{XID_Continue}.$:-]*(?:[ \t\r\n](?:\"[^\"]*\"|'[^']*'|[^<\"'])*)?/>)")
  (#not-match? @injection.content "[=(,][ \t\r\n\f]*\\{\\{|\\{%-?[ \t\r\n\f]*[a-zA-Z]")
  (#not-match? @injection.content "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
  (#not-match? @injection.content "//[^\r\n\\x{2028}\\x{2029}]*[^\\S\r\n\\x{2028}\\x{2029}](?:[\r\n\\x{2028}\\x{2029}]|$)")
  (#not-match? @injection.content "\\bawait[\\p{Zs}\t\\x{000B}\\x{000C}\\x{FEFF}]*[\r\n\\x{2028}\\x{2029}]")
  (#set! injection.language "javascript"))

((style_element
    (start_tag (tag_name) . (attribute (attribute_name) @other)* .
      (attribute . (attribute_name) @name
        [(attribute_value) (quoted_attribute_value) (missing_attribute_value)] @value) .
      (attribute (attribute_name) @other)* .)
    (raw_text) @injection.content)
  (#match? @name "(?i-u)^type$")
  (#not-match? @other "(?i-u)^(type|lang)$")
     (#match? @value "(?i-u)^(text/css|'(?:text/css)?'|\"(?:text/css)?\")?$")
    (#match? @injection.content "[^ \t\r\n\f]")
    (#not-match? @injection.content "^[ \t\r\n\\x{000C}]*<&>[ \t\r\n\\x{000C}]*$")
   (#not-match? @injection.content "(?i)(^|[;{])[ \t\r\n\f]*\\*[a-z_-][a-z0-9_-]*[ \t\r\n\f]*:")
      (#not-match? @injection.content "^[ \t\r\n\f]*<!\\[CDATA\\[|(?:^|[^\\\\])(?:\\\\\\\\)*\\\\(?:[0-9a-fA-F]{0,6}[\r\n\f]|\\z)")
      (#not-match? @injection.content "^[ \t\r\n\f]*<!--[ \t]*[A-Z][A-Z_ ]+:[^{}]*?-->")
      (#not-match? @injection.content "^[ \t\r\n\f]*\\{\\{[^{}]+\\}\\}[ \t\r\n\f]*$")
      (#not-match? @injection.content "\\{\\{GET\\[[a-zA-Z0-9_.-]+\\]\\}\\}")
     (#not-match? @injection.content "^[ \t\r\n\f]*\\$[A-Za-z_][A-Za-z0-9_.-]*\\$[ \t\r\n\f]*$")
     (#not-match? @injection.content "(?ms)^[ \t]*\\$if\\([A-Za-z_][A-Za-z0-9_.-]*\\)\\$.*^[ \t]*\\$endif\\$")
     (#not-match? @injection.content "/\\*(?:[^*\r\n]|\\*+[^*/\r\n])*\\**[\r\n]|(?i-u::(?:state|active-view-transition-type))\\((?:\\\\[^\r\n]|[^)\\\\\r\n])*[\r\n]")
   (#not-match? @injection.content "(?:^|[},]|\\*/)[ \t\r\n\f]*!print[ \t\r\n\f]+[^{}]*\\{")
   (#not-match? @injection.content "--[^:;{}\\s]+[ \t\f\r\n]*:[ \t\f]*[\r\n][ \t\f\r\n]*[;}]")
    (#set! injection.language "embedded-css"))
