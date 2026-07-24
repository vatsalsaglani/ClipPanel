// Section close-ups for design review.
import { mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";
import { startStaticServer } from "./lib/static-server.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = join(root, "out");
const shotsDir = join(root, "verification");
mkdirSync(shotsDir, { recursive: true });
const server = await startStaticServer(outDir, 4197);

const browser = await puppeteer.launch({ executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", headless: "shell", args: ["--no-sandbox"] });
const page = await browser.newPage();
await page.setViewport({ width: 1440, height: 960, deviceScaleFactor: 1.5 });
await page.goto("http://127.0.0.1:4197/", { waitUntil: "networkidle0" });

// trigger all reveals
await page.evaluate(async () => {
  const step = window.innerHeight * 0.8;
  for (let y = 0; y < document.body.scrollHeight; y += step) {
    window.scrollTo(0, y);
    await new Promise((r) => setTimeout(r, 120));
  }
});
await new Promise((r) => setTimeout(r, 500));

const targets = process.argv[2]
  ? process.argv[2].split(",")
  : ["how-it-works", "features", "privacy", "keyboard", "download"];

for (const id of targets) {
  const el = await page.$(`#${id}`);
  if (!el) { console.log(`missing #${id}`); continue; }
  await page.evaluate((sel) => document.querySelector(sel)?.scrollIntoView({ block: "start" }), `#${id}`);
  await new Promise((r) => setTimeout(r, 400));
  await el.screenshot({ path: join(shotsDir, `section-${id}.png`) });
  console.log(`section-${id}.png`);
}

await browser.close();
server.close();
