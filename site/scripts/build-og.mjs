// Builds the OG image (brand doc §7): dark midnight canvas, app icon left,
// tagline right in Inter Tight, keycap row ⌃Q → ⏎ beneath. 1200×630.
// Text is converted to vector paths (text-to-svg) so rendering never
// depends on system fonts. Output: public/og.png (committed).
import { readFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import TextToSVG from "text-to-svg";
import sharp from "sharp";
import { fetchFontTtf } from "./lib/fonts.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = join(root, "..");

const W = 1200;
const H = 630;

// Brand palette (§4.1)
const C = {
  midnight900: "#0D0F20",
  midnight700: "#20244A",
  panel500: "#3B4080",
  lavender200: "#CFCBFF",
  ink100: "#F4F4FA",
  ink400: "#9A9DBE",
};

const interTightPath = await fetchFontTtf("Inter+Tight:wght@600", "inter-tight-600");
const jetBrainsPath = await fetchFontTtf("JetBrains+Mono:wght@500", "jetbrains-mono-500");
const interTight = TextToSVG.loadSync(interTightPath);
const jetBrains = TextToSVG.loadSync(jetBrainsPath);

const textPath = (tts, text, x, y, fontSize, fill) =>
  `<path d="${tts.getD(text, { x, y, fontSize, anchor: "left top", kerning: true })}" fill="${fill}"/>`;

// App icon (master SVG from the app bundle), scaled to 340px.
const appIconSvg = readFileSync(
  join(repoRoot, "ClipPanel/Assets.xcassets/AppIcon.appiconset/ClipPanelIcon.svg"),
  "utf8",
);
const iconInner = appIconSvg
  .replace(/<\?xml[^>]*>/, "")
  .replace(/<svg[^>]*>/, "")
  .replace(/<\/svg>\s*$/, "");
const iconScale = 340 / 1024;
const iconG = `<g transform="translate(110,145) scale(${iconScale})">${iconInner}</g>`;

// Tagline, two lines, Inter Tight SemiBold.
const line1 = textPath(interTight, "Everything you copied.", 520, 196, 62, C.ink100);
const line2 = textPath(interTight, "One keystroke away.", 520, 274, 62, C.ink100);

// Keycap: rounded rect + glyphs (hand-drawn symbol strokes + JetBrains Mono).
function keycap(x, y, w, h, inner) {
  return `<g>
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="14"
      fill="${C.midnight700}" stroke="${C.panel500}" stroke-width="2"/>
    <rect x="${x + 3}" y="${y + h - 5}" width="${w - 6}" height="2" rx="1"
      fill="${C.midnight900}" fill-opacity="0.9"/>
    ${inner}
  </g>`;
}

const stroke = (d) =>
  `<path d="${d}" fill="none" stroke="${C.lavender200}" stroke-width="4.5"
    stroke-linecap="round" stroke-linejoin="round"/>`;

// ⌃Q keycap (104×64): chevron + Q
const kc1 = keycap(
  520,
  392,
  104,
  64,
  stroke("M545 428 L557 416 L569 428") +
    textPath(jetBrains, "Q", 582, 408, 33, C.lavender200),
);
// arrow between
const arrow = stroke("M648 424 H692 M680 412 L692 424 L680 436");
// ⏎ keycap (64×64)
const kc2 = keycap(
  716,
  392,
  64,
  64,
  stroke("M770 406 V428 Q770 430 768 430 H744 M754 420 L744 430 L754 440"),
);

const urlText = textPath(jetBrains, "clippanel.app", 968, 546, 21, C.ink400);

const svg = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="og-glow" cx="0.28" cy="0.2" r="0.75">
      <stop offset="0" stop-color="${C.lavender200}" stop-opacity="0.09"/>
      <stop offset="1" stop-color="${C.lavender200}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="${W}" height="${H}" fill="${C.midnight900}"/>
  <rect width="${W}" height="${H}" fill="url(#og-glow)"/>
  ${iconG}
  ${line1}
  ${line2}
  ${kc1}
  ${arrow}
  ${kc2}
  ${urlText}
</svg>`;

mkdirSync(join(root, "public"), { recursive: true });
const out = join(root, "public", "og.png");
await sharp(Buffer.from(svg)).png().toFile(out);
console.log(`og.png written (${W}×${H})`);
