(string) @leaf

; Scope follows source newlines for objects, not the length of the result.
((object "{" @append_spaced_scoped_softline
         (pair) "}" @prepend_spaced_scoped_softline) @prepend_begin_scope @append_end_scope
  (#scope_id! "object"))
((object "," @append_spaced_scoped_softline)
  (#scope_id! "object"))
(object "{" @append_indent_start "}" @prepend_indent_end)
(pair ":" @append_space)
(array "," @append_space)
; Preserve the multiline layout of arrays of compound values. Flat scalar
; arrays can still print compactly. Check the parent's source rows rather
; than rescanning its entire text at every comma.
((array "[" @append_hardline @append_indent_start
        [(array) (object)] "]" @prepend_indent_end @prepend_hardline)
  (#multi_line_only!))
((array [(array) (object)] . "," @append_hardline)
  (#multi_line_only!))
((array "," @append_hardline . [(array) (object)])
  (#multi_line_only!))
