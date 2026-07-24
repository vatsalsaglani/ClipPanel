import type { NextConfig } from "next";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

// GitHub Pages serves the site at /<repo>/ until the clippanel.app custom
// domain lands; the deploy workflow passes that prefix as SITE_BASE. Next
// wants basePath without a trailing slash. Unset for local dev.
const siteBase = process.env.SITE_BASE?.replace(/\/+$/, "");

const nextConfig: NextConfig = {
  // Fully static export — no server runtime, no API routes, no middleware.
  output: "export",
  images: { unoptimized: true },
  // Trailing slashes so the exported tree works on any static host.
  trailingSlash: true,
  ...(siteBase ? { basePath: siteBase } : {}),
  outputFileTracingRoot: dirname(fileURLToPath(import.meta.url)),
};

export default nextConfig;
