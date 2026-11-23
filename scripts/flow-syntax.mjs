import { isDeepStrictEqual } from "node:util";
import { parse } from "hermes-parser";

const leadingTrivia = /\s*(?:\/\*[^]*?\*\/|\/\/[^\r\n\u2028\u2029]*)/y;
const pragma = /(?:^|[\s*])@(flow|noflow)(?![\w$-])/g;

export function hasFlowPragma(source) {
  const prefix = /^(?:\uFEFF)?(?:#![^\r\n\u2028\u2029]*)?/.exec(source)[0];
  const trivia = new RegExp(leadingTrivia);
  trivia.lastIndex = prefix.length;
  let match;
  let enabled = false;
  while ((match = trivia.exec(source))) {
    for (const [, marker] of match[0].matchAll(pragma)) {
      if (marker === "noflow") return false;
      enabled = true;
    }
  }
  return enabled;
}

function normalize(value) {
  if (Array.isArray(value)) return value.map(normalize);
  if (value === null || typeof value !== "object" || value instanceof RegExp) return value;
  return Object.fromEntries(Object.keys(value).filter((key) => key !== "loc" && key !== "range")
    .map((key) => [key, normalize(value[key])]));
}

export function flowTree(source) {
  const { tokens, comments, ...ast } = parse(source, { flow: "all", tokens: true });
  // Check comment placement as well as contents. In particular, moving a
  // Flow suppression off the next line can change what it suppresses.
  const anchors = tokens.filter((token) => ![";", ","].includes(token.value));
  let index = 0;
  const trivia = comments.map((comment) => {
    while (index < anchors.length && anchors[index].range[1] <= comment.range[0]) index++;
    const previous = anchors[index - 1], next = anchors[index];
    return [comment.type, comment.value, index,
      previous?.loc.end.line === comment.loc.start.line,
      next && Math.min(2, next.loc.start.line - comment.loc.end.line)];
  });
  return { ast: normalize(ast), trivia };
}

export function flowTreesMatch(before, after) {
  try { return isDeepStrictEqual(flowTree(before), flowTree(after)); }
  catch (error) {
    if (error instanceof SyntaxError || error instanceof RangeError) return false;
    throw error;
  }
}
