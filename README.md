# Topiary HTML formatter

Native Topiary parsers and queries for HTML, CSS, JavaScript, and JSON. HTML
can format embedded CSS, JavaScript, and JSON. The optional Node wrapper also
supports a verified subset of Flow on standalone JavaScript inputs.

## Install and use with Topiary

Install [Topiary CLI 0.8.0](https://github.com/tweag/topiary/releases/tag/v0.8.0),
[Tree-sitter CLI 0.27.2](https://github.com/tree-sitter/tree-sitter/releases/tag/v0.27.2),
Node.js 22 or later (with npm), and a C compiler. Make sure `topiary` and
`tree-sitter` are on your `PATH`. Clone the repository and build the parsers once:

```sh
git clone https://github.com/InnocentZero/topiary-html.git
cd topiary-html
npm ci --ignore-scripts
npm run build:parser
```

Use these environment variables to run `topiary` directly, either in your
shell or in the environment your editor passes to the formatter. Set them
from the repository root so they hold absolute paths:

```sh
export TOPIARY_CONFIG_FILE="$PWD/languages.ncl"
export TOPIARY_LANGUAGE_DIR="$PWD/queries"

# Preview to stdout. For stdin, use -l css, javascript, or json as needed.
printf '%s\n' '<p class=example>Hello</p>' | topiary format -l html
```

Run `topiary format path/to/example.html` to write in place and select the
language by extension. Keep the config, queries, and compiled libraries together.
The native CLI does not need Node.js or a compiler after setup.

Topiary can fetch and compile a Git-hosted grammar when the configuration uses
`grammar.source.git` and the Git revision contains generated Tree-sitter C
sources. This repository instead ships grammar definitions and uses
`grammar.source.path` to load local libraries. `topiary prefetch` checks those
paths but does not run `npm run build:parser` or generate the injection queries.

### Optional: byte preservation and Flow

From the repository root, use the stdin wrapper to preserve authored HTML/CSS
BOM and edge whitespace, or format supported standalone Flow files. The
wrapper accepts Flow output only when Hermes verifies the AST and comment
placement.

```sh
npm run --silent format -- -l html < example.html
npm run --silent format -- -l javascript < example.js
```

## Parser sources

The parser sources are based on [tree-sitter-html v0.23.2](https://github.com/tree-sitter/tree-sitter-html/tree/5a5ca8551a179998360b4a4ca2c0f366a35acc03),
[tree-sitter-css](https://github.com/tree-sitter/tree-sitter-css/tree/6e327db434fec0ee90f006697782e43ec855adf5),
[tree-sitter-javascript](https://github.com/tree-sitter/tree-sitter-javascript/tree/44c892e0be055ac465d5eeddae6d3e194424e7de),
and the pinned JSON and TypeScript grammars. The build generates the native
libraries and the embedded CSS and Flow formatting queries.
