import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const [directory] = process.argv.slice(2);
if (!directory) throw new Error("Usage: node scripts/smoke-parser-bundle.mjs BUNDLE_DIRECTORY");
const bundle = resolve(directory);
const cwd = mkdtempSync(join(tmpdir(), "topiary-bundle-smoke-"));
const env = {
  ...process.env,
  XDG_CACHE_HOME: join(cwd, "cache"),
  TOPIARY_LANGUAGE_DIR: join(bundle, "queries"),
};
const run = (command, args, input) =>
  execFileSync(command, args, { cwd, env, input, encoding: "utf8", timeout: 30_000 });
const native = (language, input) =>
  run("topiary", ["-C", join(bundle, "languages.ncl"), "format", "-l", language], input);
const wrapper = (language, input) =>
  run(process.execPath, [join(bundle, "scripts/format.mjs"), "-l", language], input);

try {
  const cases = [
    ["html", '<style>a{color:red}</style>\n<script>const n=1</script>\n<script type="application/json">{"n":1}</script>', [
      /color: red;/, /const n = 1;/, /"n": 1/,
    ]],
    ["css", "a{color:red}", [/color: red;/]],
    ["javascript", "const n=1", [/^const n = 1;/]],
    ["json", '{"n":1}', [/"n": 1/]],
  ];
  for (const [language, input, patterns] of cases) {
    const output = native(language, input);
    for (const pattern of patterns) assert.match(output, pattern, language);
    assert.equal(native(language, input), output, `${language} fresh replay`);
    assert.equal(native(language, output), output, `${language} idempotence`);
  }
  for (const [language, input] of [["html", "\uFEFF<p>x</p>"], ["css", "\uFEFFa{color:red}"]]) {
    const output = wrapper(language, input);
    assert.ok(output.startsWith("\uFEFF") && !output.endsWith("\n"), `${language} document edges`);
    assert.equal(wrapper(language, output), output);
  }
  const flow = "// @flow\ntype Props={+name:string};";
  const output = wrapper("javascript", flow);
  assert.match(output, /\+name: string/);
  assert.equal(wrapper("javascript", flow), output, "Flow fresh replay");
  assert.equal(wrapper("javascript", output), output, "Flow idempotence");
  console.log("Native parser and host formatter bundle smoke tests passed.");
} finally {
  rmSync(cwd, { recursive: true, force: true });
}
