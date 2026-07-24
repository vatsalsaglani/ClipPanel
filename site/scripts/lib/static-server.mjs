// Static file server for out/ that mimics a real static host:
// brotli/gzip compression for text assets and immutable cache headers
// for hashed /_next/static files. Used by verify and Lighthouse runs.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { extname, join, normalize } from "node:path";
import { brotliCompress, gzip, constants as zc } from "node:zlib";
import { promisify } from "node:util";

const br = promisify(brotliCompress);
const gz = promisify(gzip);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".woff2": "font/woff2",
  ".txt": "text/plain; charset=utf-8",
  ".xml": "application/xml",
  ".json": "application/json",
};
const COMPRESSIBLE = new Set([".html", ".js", ".css", ".svg", ".txt", ".xml", ".json"]);

export async function startStaticServer(outDir, port) {
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, "http://x");
    const pathname = normalize(decodeURIComponent(url.pathname)).replace(
      /^(\.\.[/\\])+/,
      "",
    );
    let file = join(outDir, pathname);
    if (pathname.endsWith("/")) file = join(file, "index.html");
    if (!existsSync(file) && !extname(file)) file = file + "/index.html";

    let data;
    try {
      data = await readFile(file);
    } catch {
      res.writeHead(404);
      res.end("not found");
      return;
    }

    const ext = extname(file);
    const headers = { "content-type": MIME[ext] ?? "application/octet-stream" };
    if (pathname.startsWith("/_next/static/")) {
      headers["cache-control"] = "public, max-age=31536000, immutable";
    } else {
      headers["cache-control"] = "public, max-age=3600";
    }

    const accept = req.headers["accept-encoding"] ?? "";
    if (COMPRESSIBLE.has(ext) && data.length > 1024) {
      if (accept.includes("br")) {
        headers["content-encoding"] = "br";
        data = await br(data, {
          params: { [zc.BROTLI_PARAM_QUALITY]: 4 },
        });
      } else if (accept.includes("gzip")) {
        headers["content-encoding"] = "gzip";
        data = await gz(data);
      }
    }

    res.writeHead(200, headers);
    res.end(data);
  });
  await new Promise((r) => server.listen(port, r));
  return server;
}
