import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { restoreDocumentEdges } from "./document-edges.mjs";

export const root = fileURLToPath(new URL("../", import.meta.url));
const utf8 = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true });
const noscriptIframeTail = /<noscript[\t\n\f\r ]*>[\t\n\f\r ]*<iframe(?=[\t\n\f\r /])(?:[^"'<>]|"[^"]*"|'[^']*')*\/>[\t\n\f\r ]*<\/noscript[\t\n\f\r ]*>(?:[\t\n\f\r ]*<\/body[\t\n\f\r ]*>)?(?:[\t\n\f\r ]*<\/html[\t\n\f\r ]*>)?$/i;

export async function formatStdin(command, args, input, env = process.env, signal, cwd = root) {
  signal?.throwIfAborted();
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd, env, signal, timeout: 30_000 });
    const output = [];
    const errors = [];
    child.stdout.on("data", (chunk) => output.push(chunk));
    child.stderr.on("data", (chunk) => errors.push(chunk));
    child.on("error", (error) => {
      // Wait for close after abort so the runner doesn't finish with live children.
      if (error.name !== "AbortError") reject(error);
    });
    child.on("close", (code, childSignal) => {
      if (signal?.aborted) return reject(signal.reason);
      if (code === 0) {
        const bytes = Buffer.concat(output);
        try { return resolve({ output: utf8.decode(bytes), bytes }); }
        catch { return resolve({ reason: "non-utf8-output" }); }
      }
      const message = Buffer.concat(errors).toString();
      const reason = childSignal ? `signal ${childSignal}`
        : /idempotence|non-idempotent|not idempotent/i.test(message) ? "idempotence"
        : /parse|parsing/i.test(message) ? "parse"
        : `exit ${code}`;
      resolve({ reason });
    });
    child.stdin.on("error", (error) => {
      if (error.code !== "EPIPE") reject(error);
    });
    child.stdin.end(input);
  });
}

function nativeTopiary(input, singlePass, language, signal, cwd) {
  const args = ["-C", "languages.ncl", "format", "-l", language];
  if (singlePass) args.push("--skip-idempotence");
  return formatStdin("topiary", args, input, {
    ...process.env, TOPIARY_LANGUAGE_DIR: "queries", RUST_LOG: "error",
  }, signal, cwd);
}

export async function topiary(input, singlePass = false, language = "html", signal, cwd = root) {
  if (language === "javascript") {
    async function pass(value, skipIdempotence) {
      const native = await nativeTopiary(value, skipIdempotence, language, signal, cwd);
      if (native.reason !== "parse") return native;
      let source;
      try { source = typeof value === "string" ? value : utf8.decode(value); }
      catch { return native; }
      if (!source.includes("@flow")) return native;
      const { hasFlowPragma, flowTreesMatch } = await import("./flow-syntax.mjs");
      if (!hasFlowPragma(source)) return native;
      const flow = await nativeTopiary(value, true, "flow", signal, cwd);
      if (flow.reason) return flow;
      const output = restoreDocumentEdges(source, flow.output);
      if (output === undefined || !flowTreesMatch(source, output)) return native;
      return { output, bytes: Buffer.from(output), flow: true };
    }
    const first = await pass(input, singlePass);
    if (singlePass || !first.flow) return first;
    const second = await pass(first.bytes, true);
    return second.reason || !second.bytes.equals(first.bytes) ? { reason: "idempotence" } : first;
  }
  if (language !== "html" && language !== "css") return nativeTopiary(input, singlePass, language, signal, cwd);
  async function pass(value) {
    let source;
    try { source = typeof value === "string" ? value : utf8.decode(value); }
    catch { return { reason: "non-utf8-input" }; }
    let result = await nativeTopiary(value, true, language, signal, cwd);
    let protectedTail;
    if (language === "html" && result.reason === "parse" && !/\p{White_Space}$/u.test(source)) {
      // With scripting on this tail is noscript text; with scripting off the
      // iframe ignores the slash and consumes the remaining bytes. Give the
      // native EOF scanner its required LF, but never emit it or alter the tail.
      const tail = noscriptIframeTail.exec(source)?.[0];
      if (tail !== undefined) {
        protectedTail = tail;
        result = await nativeTopiary(`${source}\n`, true, language, signal, cwd);
      }
    }
    if (result.reason) return result;
    const output = restoreDocumentEdges(source, result.output);
    if (output === undefined) return { reason: `unexpected-${language}-renderer-output` };
    if (protectedTail !== undefined && !output.endsWith(protectedTail)) return { reason: "parse" };
    return { output, bytes: Buffer.from(output) };
  }
  const first = await pass(input);
  if (singlePass || first.reason) return first;
  const second = await pass(first.bytes);
  return second.reason || !second.bytes.equals(first.bytes) ? { reason: "idempotence" } : first;
}
