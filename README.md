# Topiary HTML formatter

Native Topiary parsers and queries for HTML, CSS, JavaScript, and JSON. HTML
can format embedded CSS, JavaScript, and JSON. The optional Node wrapper also
supports a verified subset of Flow on standalone JavaScript inputs.

## Install and use with Topiary

Install [Topiary CLI 0.8.0](https://github.com/tweag/topiary/releases/tag/v0.8.0)
and a C compiler. Download the Git configuration and tell Topiary to use it:

```sh
config="$HOME/.config/topiary/topiary-html.ncl"
mkdir -p "$(dirname "$config")"
curl -fsSL https://raw.githubusercontent.com/InnocentZero/topiary-html/main/languages.git.ncl -o "$config"
export TOPIARY_CONFIG_FILE="$config"

printf '%s\n' '<p class=example>Hello</p>' | topiary format -l html
```

Topiary fetches the generated parsers and queries from a pinned Git revision,
then compiles and caches the parsers on first use. No repository checkout,
Tree-sitter CLI, Node.js, or Actions artifact is required. Set
`TOPIARY_CONFIG_FILE` in your editor's formatter environment to use it there.
Use `-l css`, `-l javascript`, or `-l json` for other stdin inputs, or
`topiary format path/to/file.html` to format a file in place by extension.

### Optional: byte preservation and Flow

Use the stdin wrapper to preserve authored HTML/CSS
BOM and edge whitespace, or format supported standalone Flow files. The
wrapper accepts Flow output only when Hermes verifies the AST and comment
placement.

```sh
git clone https://github.com/InnocentZero/topiary-html.git
cd topiary-html
npm ci --ignore-scripts
npm run build:parser
npm run --silent format -- -l html < example.html
npm run --silent format -- -l javascript < example.js
```

This local build uses Node.js 22+, [Tree-sitter CLI 0.27.2](https://github.com/tree-sitter/tree-sitter/releases/tag/v0.27.2),
and a C compiler. It uses `languages.ncl`, the local-library configuration.

## Parser sources

The parser sources are based on [tree-sitter-html v0.23.2](https://github.com/tree-sitter/tree-sitter-html/tree/5a5ca8551a179998360b4a4ca2c0f366a35acc03),
[tree-sitter-css](https://github.com/tree-sitter/tree-sitter-css/tree/6e327db434fec0ee90f006697782e43ec855adf5),
[tree-sitter-javascript](https://github.com/tree-sitter/tree-sitter-javascript/tree/44c892e0be055ac465d5eeddae6d3e194424e7de),
and the pinned JSON and TypeScript grammars. The build generates the native
libraries and the embedded CSS and Flow formatting queries.
