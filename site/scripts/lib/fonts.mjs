// Shared helper: download Google Font TTFs (cached in scripts/.cache).
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const cacheDir = join(dirname(fileURLToPath(import.meta.url)), "..", ".cache");

// An old UA makes fonts.googleapis.com return plain TTF URLs.
const TTF_UA = "Mozilla/5.0 (Windows NT 5.1)";

export async function fetchFontTtf(familyCss, fileSlug) {
  mkdirSync(cacheDir, { recursive: true });
  const cached = join(cacheDir, `${fileSlug}.ttf`);
  if (existsSync(cached)) return cached;

  const cssRes = await fetch(
    `https://fonts.googleapis.com/css2?family=${familyCss}&display=swap`,
    { headers: { "User-Agent": TTF_UA } },
  );
  if (!cssRes.ok) throw new Error(`font css fetch failed: ${cssRes.status}`);
  const css = await cssRes.text();
  const url = css.match(/url\((https:[^)]+\.ttf)\)/)?.[1];
  if (!url) throw new Error(`no ttf url for ${familyCss}`);

  const fontRes = await fetch(url);
  if (!fontRes.ok) throw new Error(`font fetch failed: ${fontRes.status}`);
  const buf = Buffer.from(await fontRes.arrayBuffer());
  writeFileSync(cached, buf);
  return cached;
}

export function contentHash(file) {
  return createHash("sha1").update(readFileSync(file)).digest("hex").slice(0, 8);
}
