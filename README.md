# Topiary HTML formatter

Native Topiary parsers and queries for HTML, CSS, JavaScript, and JSON. HTML
can format embedded CSS, JavaScript, and JSON. The optional Node wrapper also
supports a verified subset of Flow on standalone JavaScript inputs.

## Install with Topiary

Install [Topiary CLI 0.8.0](https://github.com/tweag/topiary/releases/tag/v0.8.0)
and put `topiary` on your `PATH`. Open **Actions → Build Topiary parsers → a
successful run** and download the artifact for your platform: `macos-arm64`,
`macos-x86_64`, `linux-arm64`, or `linux-x86_64` (glibc Linux). Unzip the
download to get the `.tar.gz`, then extract it into a fresh directory:

```sh
bundle="$HOME/.local/share/topiary-parsers"
mkdir -p "$bundle"
tar -xzf topiary-parsers-macos-arm64.tar.gz -C "$bundle"

# Format to stdout. Use -l css, javascript, or json for other stdin inputs.
TOPIARY_LANGUAGE_DIR="$bundle/queries" \
  topiary -C "$bundle/languages.ncl" format -l html < example.html
```

Use `format example.html` to write in place and select the language by extension.
For editors, set `TOPIARY_CONFIG_FILE` to `$bundle/languages.ncl` and
`TOPIARY_LANGUAGE_DIR` to `$bundle/queries`. Keep the libraries, queries, and
config together. The native CLI requires no Node.js, compiler, or grammar download.

Use the bundled stdin wrapper with Node.js 22+ to preserve authored HTML/CSS
BOM and edge whitespace, or format supported Flow syntax. The wrapper accepts
Flow output only when Hermes verifies the AST and comment placement.

```sh
node "$bundle/scripts/format.mjs" -l html < example.html
node "$bundle/scripts/format.mjs" -l javascript < example.js
```

## Build from source

With Node.js 22+, npm, a C compiler, and Tree-sitter CLI 0.27.2 on your `PATH`:

```sh
npm ci --ignore-scripts
npm run build:parser
bash scripts/package-parser-bundle.sh topiary-parsers.tar.gz
```

The parser sources are based on [tree-sitter-html v0.23.2](https://github.com/tree-sitter/tree-sitter-html/tree/5a5ca8551a179998360b4a4ca2c0f366a35acc03),
[tree-sitter-css](https://github.com/tree-sitter/tree-sitter-css/tree/6e327db434fec0ee90f006697782e43ec855adf5),
[tree-sitter-javascript](https://github.com/tree-sitter/tree-sitter-javascript/tree/44c892e0be055ac465d5eeddae6d3e194424e7de),
and the pinned JSON and TypeScript grammars. The build generates the native
libraries and the embedded CSS and Flow formatting queries.
