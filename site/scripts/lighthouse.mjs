// Runs Lighthouse (mobile, simulated throttling) against out/ served with
// production-like compression, and prints category scores + key metrics.
import { readFile } from "node:fs/promises";
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { startStaticServer } from "./lib/static-server.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const port = 4193;

const server = await startStaticServer(join(root, "out"), port);

const reportPath = "/tmp/clippanel-lh.json";
const args = [
  "--yes",
  "lighthouse@12",
  `http://127.0.0.1:${port}/`,
  "--only-categories=performance,accessibility,best-practices,seo",
  '--chrome-flags=--headless --no-sandbox --disable-gpu',
  "--output=json",
  `--output-path=${reportPath}`,
  "--quiet",
];

const code = await new Promise((resolve) => {
  const child = spawn("npx", args, { stdio: ["ignore", "inherit", "inherit"], shell: false });
  child.on("close", resolve);
});
server.close();
if (code !== 0) {
  console.error(`lighthouse exited with ${code}`);
  process.exit(code);
}

const r = JSON.parse(await readFile(reportPath, "utf8"));
console.log("\n--- Lighthouse (mobile, simulated throttling) ---");
for (const [k, v] of Object.entries(r.categories)) {
  console.log(`${k}: ${v.score === null ? "n/a" : Math.round(v.score * 100)}`);
}
const a = r.audits;
for (const k of [
  "first-contentful-paint",
  "largest-contentful-paint",
  "total-blocking-time",
  "cumulative-layout-shift",
  "speed-index",
  "interactive",
]) {
  console.log(`  ${k}: ${a[k]?.displayValue} (score ${a[k]?.score})`);
}
