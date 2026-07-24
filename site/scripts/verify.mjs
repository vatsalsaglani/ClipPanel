// Verification harness for the static export. Serves out/ locally and
// drives the installed Chrome via puppeteer-core (dev-only, nothing ships).
//
// Checks: zero third-party requests, no horizontal scroll at 360/768/1440,
// demo loop runs (and pauses), prefers-reduced-motion static frame,
// FAQ deep-linking, notify-form graceful failure, keyboard focus order.
// Screenshots land in verification/.
import { mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer-core";
import { startStaticServer } from "./lib/static-server.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outDir = join(root, "out");
const shotsDir = join(root, "verification");
mkdirSync(shotsDir, { recursive: true });

const server = await startStaticServer(outDir, 4199);

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: "shell",
  args: ["--no-sandbox"],
});

const results = [];
const check = (name, ok, detail = "") => {
  results.push({ name, ok, detail });
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? ` — ${detail}` : ""}`);
};

const page = await browser.newPage();
const thirdParty = [];
page.on("request", (req) => {
  const host = new URL(req.url()).host;
  if (!["127.0.0.1:4199", "localhost:4199"].includes(host)) thirdParty.push(req.url());
});

// ---- desktop load + full-page screenshot
await page.setViewport({ width: 1440, height: 900 });
await page.goto("http://127.0.0.1:4199/", { waitUntil: "networkidle0" });
await new Promise((r) => setTimeout(r, 2500));
await page.screenshot({ path: join(shotsDir, "01-hero-desktop.png") });
// Scroll through the page like a reader, so scroll reveals trigger once,
// then capture the full page from the top.
await page.evaluate(async () => {
  const step = window.innerHeight * 0.8;
  for (let y = 0; y < document.body.scrollHeight; y += step) {
    window.scrollTo(0, y);
    await new Promise((r) => setTimeout(r, 140));
  }
});
await new Promise((r) => setTimeout(r, 500));
await page.evaluate(() => window.scrollTo(0, 0));
await new Promise((r) => setTimeout(r, 300));
await page.screenshot({ path: join(shotsDir, "02-full-desktop.png"), fullPage: true });

check("zero third-party requests", thirdParty.length === 0, thirdParty.join(", ") || "all requests first-party");

// ---- no horizontal scroll at three widths
for (const w of [360, 768, 1440]) {
  await page.setViewport({ width: w, height: 900 });
  await new Promise((r) => setTimeout(r, 500));
  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
  if (overflow > 0) {
    const offenders = await page.evaluate(() => {
      const bad = [];
      document.querySelectorAll("body *").forEach((el) => {
        const r = el.getBoundingClientRect();
        if (r.right > window.innerWidth + 1 && r.width > 4) {
          bad.push(`${el.tagName} ${String(el.className).slice(0, 70)} right=${Math.round(r.right)}`);
        }
      });
      return bad.slice(0, 8);
    });
    console.log("   offenders:", offenders.join(" | "));
  }
  check(`no horizontal scroll @${w}px`, overflow <= 0, `overflow=${overflow}px`);
}
await page.setViewport({ width: 390, height: 844 });
await new Promise((r) => setTimeout(r, 600));
await page.screenshot({ path: join(shotsDir, "03-hero-mobile.png") });
await page.evaluate(async () => {
  const step = window.innerHeight * 0.8;
  for (let y = 0; y < document.body.scrollHeight; y += step) {
    window.scrollTo(0, y);
    await new Promise((r) => setTimeout(r, 120));
  }
});
await new Promise((r) => setTimeout(r, 400));
await page.evaluate(() => window.scrollTo(0, 0));
await new Promise((r) => setTimeout(r, 300));
await page.screenshot({ path: join(shotsDir, "04-full-mobile.png"), fullPage: true });
await page.setViewport({ width: 1440, height: 900 });

// ---- demo loop: visibility-aware state via computed styles + data hooks
const demoState = () =>
  page.evaluate(() => {
    const panel = document.querySelector("[data-demo-panel]");
    const toast = document.querySelector("[data-demo-toast]");
    const query = document.querySelector("[data-demo-query]");
    return {
      panelOpacity: panel ? Number(getComputedStyle(panel).opacity) : 0,
      toastOpacity: toast ? Number(getComputedStyle(toast).opacity) : 0,
      query: query?.textContent ?? "",
      rows: document.querySelectorAll("[data-demo-stage] [data-demo-row]").length,
    };
  });

// ---- demo churns while visible (sample during the active phase, right after load)
let churns = false;
let prev = await demoState();
for (let i = 0; i < 8; i++) {
  await new Promise((r) => setTimeout(r, 400));
  const cur = await demoState();
  if (JSON.stringify(cur) !== JSON.stringify(prev)) churns = true;
  prev = cur;
}

let sawOpen = prev.panelOpacity > 0.9;
let sawTyped = prev.query === "inv";
let sawFiltered = prev.query === "inv" && prev.rows === 3;
let sawToast = prev.toastOpacity > 0.9;
for (let i = 0; i < 30; i++) {
  const s = await demoState();
  sawOpen ||= s.panelOpacity > 0.9;
  sawTyped ||= s.query === "inv";
  sawFiltered ||= s.query === "inv" && s.rows === 3;
  sawToast ||= s.toastOpacity > 0.9;
  if (sawOpen && sawTyped && sawFiltered && sawToast) break;
  await new Promise((r) => setTimeout(r, 450));
}
check("demo loop: panel opens visibly", sawOpen);
check("demo loop: 'inv' types into the field", sawTyped);
check("demo loop: rows filter to 3 per keystroke", sawFiltered);
check("demo loop: toast 'Pasted to Xcode' appears", sawToast);

// ---- demo pauses off-viewport: state froze once scrolled away
await page.evaluate(() => document.querySelector("#privacy")?.scrollIntoView());
await new Promise((r) => setTimeout(r, 700));
const h1 = await demoState();
await new Promise((r) => setTimeout(r, 1600));
const h2 = await demoState();
check(
  "demo pauses off-viewport",
  churns && JSON.stringify(h1) === JSON.stringify(h2),
  `churns=${churns} frozen=${JSON.stringify(h1) === JSON.stringify(h2)}`,
);

// ---- reduced motion: single static final-state frame (fresh page)
const rmPage = await browser.newPage();
await rmPage.setViewport({ width: 1440, height: 900 });
await rmPage.emulateMediaFeatures([{ name: "prefers-reduced-motion", value: "reduce" }]);
await rmPage.goto("http://127.0.0.1:4199/", { waitUntil: "networkidle0" });
await new Promise((r) => setTimeout(r, 900));
const rm = await rmPage.evaluate(() => {
  const panel = document.querySelector("[data-demo-panel]");
  const toast = document.querySelector("[data-demo-toast]");
  const query = document.querySelector("[data-demo-query]");
  return {
    reduceMq: window.matchMedia("(prefers-reduced-motion: reduce)").matches,
    panelOpacity: panel ? Number(getComputedStyle(panel).opacity) : 0,
    query: query?.textContent ?? "",
    toastPresent: !!toast,
  };
});
await rmPage.screenshot({ path: join(shotsDir, "05-hero-reduced-motion.png") });
check(
  "reduced motion: static final frame (open, 'inv', no toast, no loop)",
  rm.reduceMq && rm.panelOpacity > 0.9 && rm.query === "inv" && !rm.toastPresent,
  JSON.stringify(rm),
);
await rmPage.close();

// ---- FAQ deep-link (fresh page, real-world scenario)
const faqPage = await browser.newPage();
await faqPage.goto("http://127.0.0.1:4199/#faq-storage", { waitUntil: "networkidle0" });
await new Promise((r) => setTimeout(r, 800));
const faqOpen = await faqPage.evaluate(
  () => document.querySelector("#faq-storage")?.hasAttribute("open") ?? false,
);
check("FAQ deep-link opens #faq-storage", faqOpen);
await faqPage.close();

// ---- notify form fails gracefully, never fake success
await page.goto("http://127.0.0.1:4199/", { waitUntil: "networkidle0" });
await new Promise((r) => setTimeout(r, 600));
await page.type("#notify-email", "test@example.com");
await page.keyboard.press("Enter");
await new Promise((r) => setTimeout(r, 500));
const formMsg = await page.evaluate(
  () => document.querySelector("#notify [role=alert]")?.textContent || "",
);
check(
  "notify form: graceful failure shown",
  formMsg.includes("Couldn't submit") && formMsg.includes("hello@clippanel.app"),
  formMsg.slice(0, 80),
);

// ---- keyboard: tab from top reaches nav links with visible focus
await page.keyboard.press("Tab");
const first = await page.evaluate(() => ({
  tag: document.activeElement?.tagName,
  text: document.activeElement?.textContent?.trim().slice(0, 20),
  outline: getComputedStyle(document.activeElement).outlineStyle,
}));
check("keyboard: first tab stops on a link/button", ["A", "BUTTON", "INPUT", "SUMMARY"].includes(first.tag), `${first.tag} "${first.text}" outline=${first.outline}`);

// ---- semantic structure
const semantics = await page.evaluate(() => ({
  h1: document.querySelectorAll("h1").length,
  header: !!document.querySelector("header"),
  main: !!document.querySelector("main"),
  footer: !!document.querySelector("footer"),
  jsonLd: !!document.querySelector('script[type="application/ld+json"]'),
}));
check(
  "semantic HTML: one h1, header/main/footer, JSON-LD",
  semantics.h1 === 1 && semantics.header && semantics.main && semantics.footer && semantics.jsonLd,
  JSON.stringify(semantics),
);

// ---- SEO / social meta
const meta = await page.evaluate(() => ({
  title: document.title,
  description: document.querySelector('meta[name="description"]')?.getAttribute("content") ?? "",
  canonical: document.querySelector('link[rel="canonical"]')?.getAttribute("href") ?? "",
  ogImage: document.querySelector('meta[property="og:image"]')?.getAttribute("content") ?? "",
  twitter: document.querySelector('meta[name="twitter:card"]')?.getAttribute("content") ?? "",
}));
check(
  "meta: title, description, canonical, OG image, twitter card",
  meta.title.length > 10 &&
    meta.description.length > 50 &&
    meta.canonical.length > 0 &&
    meta.ogImage.includes("og.png") &&
    meta.twitter === "summary_large_image",
  meta.title,
);

await browser.close();
server.close();

const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
process.exit(failed.length ? 1 : 0);
