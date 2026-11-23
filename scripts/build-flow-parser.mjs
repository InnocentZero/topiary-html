import { execFileSync } from "node:child_process";
import { copyFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const upstream = dirname(require.resolve("tree-sitter-typescript/package.json"));
const grammar = resolve("parser/flow/grammar.js");
const src = resolve("parser/flow/src");
const scratch = mkdtempSync(join(tmpdir(), "topiary-flow-parser-"));
try {
  execFileSync("tree-sitter", ["generate", "--abi", "14", "--output", src, grammar], { cwd: scratch, stdio: "inherit" });
} finally {
  rmSync(scratch, { recursive: true, force: true });
}

// Keep the scanner self-contained for Topiary's Git grammar loader.
copyFileSync(join(upstream, "LICENSE"), "parser/flow/LICENSE");
copyFileSync(join(upstream, "common/scanner.h"), join(src, "scanner.h"));
const scanner = readFileSync(join(upstream, "tsx/src/scanner.c"), "utf8");
writeFileSync(join(src, "scanner.c"), scanner.replace('"../../common/scanner.h"', '"scanner.h"'));
execFileSync(process.env.CC || "cc", ["-O2", "-fPIC", "-shared", `-I${src}`,
  join(src, "parser.c"), join(src, "scanner.c"), "-o", "parser/flow.so"], { stdio: "inherit" });

const shared = readFileSync("queries/javascript/formatting.scm", "utf8");
const additions = readFileSync("queries/flow/additions.scm", "utf8");
writeFileSync("queries/flow/formatting.scm", shared.replace(
  /^; javascript-only begin\n[\s\S]*?^; javascript-only end\n/gm, "",
) + "\n" + additions);
