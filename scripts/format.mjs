import { readFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { topiary } from "./formatters.mjs";

const { values } = parseArgs({ options: {
  language: { type: "string", short: "l", default: "html" },
} });
const result = await topiary(readFileSync(0), false, values.language);
if (result.reason) {
  console.error(`Formatting failed: ${result.reason}`);
  process.exitCode = 1;
} else {
  process.stdout.write(result.bytes);
}
