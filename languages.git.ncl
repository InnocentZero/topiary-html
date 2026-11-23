let pinned_repository = {
  git = "https://github.com/InnocentZero/topiary-html.git",
  rev = "772ee939ef5fdf10d26b5b2aa0e007a2ea72f9c1",
} in
let grammar_source = fun directory => pinned_repository & { subdir = directory } in
let query = fun file => { source = { git = pinned_repository, path = file } } in
let language = fun name => fun suffixes => fun directory => {
  extensions = suffixes,
  indent = "  ",
  grammar.source.git = grammar_source directory,
  queries.formatting = query "queries/%{name}/formatting.scm",
} in
{
  languages = {
    html = language "html" ["html", "htm"] "parser" & {
      queries.injections = query "queries/html/injections.scm",
    },
    css = language "css" ["css"] "parser/css",
    "embedded-css" = language "embedded-css" [] "parser/css" & {
      grammar.symbol = "tree_sitter_css",
    },
    javascript = language "javascript" ["js", "mjs", "cjs"] "parser/javascript",
    flow = language "flow" [] "parser/flow" & {
      grammar.symbol = "tree_sitter_tsx",
    },
    json = language "json" ["json"] "parser/json",
  },
}
