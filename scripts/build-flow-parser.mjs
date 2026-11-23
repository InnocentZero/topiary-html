import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";

const require = createRequire(import.meta.url);
const src = join(dirname(require.resolve("tree-sitter-typescript/package.json")), "tsx/src");
const grammar = resolve("parser/flow/grammar.js");
const scratch = mkdtempSync(join(tmpdir(), "topiary-flow-parser-"));
try {
  const generated = join(scratch, "src");
  execFileSync("tree-sitter", ["generate", "--abi", "14", "--output", generated, grammar], { cwd: scratch, stdio: "inherit" });
  execFileSync(process.env.CC || "cc", ["-O2", "-fPIC", "-shared", `-I${generated}`,
    join(generated, "parser.c"), join(src, "scanner.c"), "-o", "parser/flow.so"], { stdio: "inherit" });
} finally {
  rmSync(scratch, { recursive: true, force: true });
}

const shared = readFileSync("queries/javascript/formatting.scm", "utf8");
const additions = readFileSync("queries/flow/additions.scm", "utf8");
writeFileSync("queries/flow/formatting.scm", shared.replace(
  /^; javascript-only begin\n[\s\S]*?^; javascript-only end\n/gm, "",
) + "\n" + additions);
