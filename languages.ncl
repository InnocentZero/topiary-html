{
  languages.html = {
    extensions = ["html", "htm"],
    indent = "  ",
    grammar.source.path = "./parser/html.so",
  },
  languages.css = {
    extensions = ["css"],
    indent = "  ",
    grammar.source.path = "./parser/css/css.so",
  },
  languages."embedded-css" = {
    extensions = [],
    indent = "  ",
    grammar.source.path = "./parser/css/css.so",
    grammar.symbol = "tree_sitter_css",
  },
  languages.javascript = {
    extensions = ["js", "mjs", "cjs"],
    indent = "  ",
    grammar.source.path = "./parser/javascript/javascript.so",
  },
  languages.flow = {
    extensions = [],
    indent = "  ",
    grammar.source.path = "./parser/flow.so",
    grammar.symbol = "tree_sitter_tsx",
  },
  languages.json = {
    extensions = ["json"],
    indent = "  ",
    grammar.source.path = "./parser/json.so",
  },
}
