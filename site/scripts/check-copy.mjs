// Copy gate: every user-facing string in src/content.ts must appear
// verbatim in ../landing-page-site-guide.md (the brand doc, §5 in
// particular). Strings that legitimately do not come from the brand doc
// (demo sample data, URLs, UI chrome) are allowlisted below with reasons.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const guide = readFileSync(join(root, "..", "landing-page-site-guide.md"), "utf8");
const contentSrc = readFileSync(join(root, "src", "content.ts"), "utf8");

const normalize = (s) =>
  s
    .replace(/[*`]/g, "") // markdown emphasis / code ticks
    .replace(/\s+/g, " ")
    .trim();

const guideText = normalize(guide);

// Non-brand-doc strings, each with a reason. Everything else must match.
const ALLOWLIST = [
  ["https://clippanel.app", "site URL placeholder"],
  ["/download/ClipPanel.dmg", "download artifact placeholder"],
  ["hello@clippanel.app", "contact email placeholder"],
  ["mailto:hello@clippanel.app", "contact email placeholder"],
  ["mailto:hello@clippanel.app?subject=ClipPanel%20issue", "contact email placeholder"],
  ["Couldn't submit — email hello@clippanel.app instead.", "form failure copy (prescribed by the master prompt)"],
  ["coming soon", "placeholder link label"],
  ["Frequently asked questions", "§5.9 has no H2 in the doc; single added heading, flagged in the report"],
  ["Search", "demo search-field placeholder"],
  ["Pasted to Xcode", "demo toast, verbatim from §5.1 hero visual description"],
  ["Paste", "demo hint label, verbatim from §5.1 hero visual description"],
  ["Plain Text", "demo hint label, verbatim from §5.1 hero visual description"],
  ["Copy", "demo hint label, verbatim from §5.1 hero visual description"],
  ["Close", "demo hint label, verbatim from §5.1 hero visual description"],
  ["console.example.dev/invoices/inv_1042", "invented demo sample data (§5.1)"],
  ['await invoiceClient.retry(id: "inv_1042")', "invented demo sample data (§5.1)"],
  ["Screenshot 2026-07-23 at 14.32.png", "invented demo sample data (§5.1)"],
  ["1440 × 900 · 1.2 MB", "invented demo sample data (§5.1)"],
  ["Migration runs Thursday 09:00 UTC — freeze merges after standup.", "invented demo sample data (§5.1)"],
  ["invoice-july.csv", "invented demo sample data (§5.1)"],
  ["3 items · ~/Documents/exports", "invented demo sample data (§5.1)"],
  ["standup: shipped retry backoff, pairing with Riya on webhooks", "invented demo sample data (§5.1)"],
];

// Extract double-quoted string literals from content.ts.
const literals = new Set();
for (const m of contentSrc.matchAll(/"((?:[^"\\]|\\.)*)"/g)) {
  const s = m[1].replace(/\\"/g, '"').replace(/\\'/g, "'");
  if (s.length >= 2 && /[a-zA-Z]/.test(s)) literals.add(s);
}

const isUiChrome = (s) =>
  !s.includes(" ") && (s.length < 12 || /^[#a-z0-9-]+$/i.test(s)); // ids, slugs, hrefs, single words

let checked = 0;
const missing = [];
const allowlisted = [];

for (const raw of literals) {
  const s = normalize(raw);
  if (isUiChrome(s)) continue;
  if (guideText.includes(s)) {
    checked++;
    continue;
  }
  const allowed = ALLOWLIST.find(([a]) => normalize(a) === s);
  if (allowed) {
    allowlisted.push(s);
    continue;
  }
  // Demo haystacks are lowercase search indexes derived from sample data.
  if (raw === raw.toLowerCase() && raw.length > 20) {
    allowlisted.push(`${raw} (demo search haystack)`);
    continue;
  }
  missing.push(s);
}

console.log(`copy check: ${checked} strings compared against the brand doc`);
console.log(`allowlisted (not brand copy): ${allowlisted.length}`);
for (const a of allowlisted) console.log(`   ~ ${a}`);

if (missing.length > 0) {
  console.error(`\nFAIL — ${missing.length} string(s) not found verbatim in the brand doc:`);
  for (const s of missing) console.error(`   ✗ ${s}`);
  process.exit(1);
}
console.log("\nOK — all compared strings are verbatim from the brand doc.");
