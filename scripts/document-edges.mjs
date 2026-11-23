// Topiary 0.8.0 returns rendered.trim() plus one LF, and Tree-sitter omits
// the initial UTF-8 BOM. Preserve these physical edges in the host formatter.
// White_Space is the set Rust trim() uses (unlike JS \s, it excludes U+FEFF).
const whitespace = /\p{White_Space}/u;

export function restoreDocumentEdges(source, rendered) {
  if (!rendered.endsWith("\n")) return undefined;
  let start = source.startsWith("\uFEFF") ? 1 : 0;
  let end = source.length;
  while (start < end && whitespace.test(source[start])) start++;
  while (end > start && whitespace.test(source[end - 1])) end--;
  return source.slice(0, start) + rendered.slice(0, -1) + source.slice(end);
}
