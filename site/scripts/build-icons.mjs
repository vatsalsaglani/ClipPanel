// Generates PNG icon assets from the master app icon SVG:
//   src/app/apple-icon.png (180×180, Next.js App Router convention)
// Favicons otherwise come from src/app/icon.svg (committed, small variant).
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const repoRoot = join(root, "..");

const svg = readFileSync(
  join(repoRoot, "ClipPanel/Assets.xcassets/AppIcon.appiconset/ClipPanelIcon.svg"),
);

await sharp(svg, { density: 384 })
  .resize(180, 180)
  .png()
  .toFile(join(root, "src", "app", "apple-icon.png"));

console.log("apple-icon.png written (180×180)");
