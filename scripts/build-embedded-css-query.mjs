import { mkdir, readFile, writeFile } from "node:fs/promises";

const source = new URL("../queries/css/formatting.scm", import.meta.url);
const embedded = new URL("../queries/embedded-css/", import.meta.url);

// The HTML scanner has already excluded styles with multiline fallback
// arguments. Otherwise use the same query as the standalone formatter.
const query = (await readFile(source, "utf8")).replace(/^.* ; standalone-only\r?\n/gm, "");
await mkdir(embedded, { recursive: true });
await writeFile(new URL("formatting.scm", embedded), `; Generated from queries/css/formatting.scm.\n${query}`);
