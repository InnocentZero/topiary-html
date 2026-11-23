#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: bash scripts/package-parser-bundle.sh OUTPUT.tar.gz\n' >&2
  exit 2
fi
case "$1" in
  /*) output=$1 ;;
  *) output=$PWD/$1 ;;
esac
cd "$(dirname "$0")/.."
stage=$(mktemp -d)
trap 'rm -r "$stage"' EXIT

mkdir -p "$stage/parser/css" "$stage/parser/javascript" "$stage/queries" "$stage/scripts" "$stage/licenses"
cp languages.ncl package.json package-lock.json "$stage/"
cp parser/{html,flow,json}.so parser/LICENSE "$stage/parser/"
cp parser/css/{css.so,LICENSE} "$stage/parser/css/"
cp parser/javascript/{javascript.so,LICENSE} "$stage/parser/javascript/"
cp parser/json/LICENSE "$stage/licenses/tree-sitter-json.txt"
cp parser/flow/LICENSE "$stage/licenses/tree-sitter-typescript.txt"
for language in html css embedded-css javascript json flow; do
  mkdir "$stage/queries/$language"
  cp queries/"$language"/formatting.scm "$stage/queries/$language/"
done
cp queries/html/injections.scm "$stage/queries/html/"
cp scripts/{format,formatters,document-edges,flow-syntax}.mjs "$stage/scripts/"
(cd "$stage" && npm ci --omit=dev --ignore-scripts --no-audit --no-fund)
COPYFILE_DISABLE=1 tar -czf "$output" -C "$stage" .
