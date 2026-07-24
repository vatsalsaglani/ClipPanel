# ClipPanel landing page

Single-page, dark-first marketing site for ClipPanel — a native macOS
clipboard history utility. Demonstration over persuasion: the hero is a
pixel-faithful, scripted recreation of the real panel (SPEC §3.2).

Built with Next.js (App Router, static export) + Tailwind CSS v4. All copy
lives in `src/content.ts` and is verbatim from `../landing-page-site-guide.md`
(brand doc §5); `npm run check:copy` diffs the two.

## Commands

```sh
npm install          # install dependencies
npm run dev          # local dev server
npm run build        # static export → out/
npm run serve        # preview the export (npx serve out)

npm run assets       # regenerate public/og.png + src/app/apple-icon.png
npm run check:copy   # verify all copy is verbatim from the brand doc
npm run verify       # build checks against out/ (see below)
npm run audit        # Lighthouse (mobile, simulated throttling)
```

A clean-checkout build needs only `npm install && npm run build`. The export
is fully static — no server runtime, no API routes, no middleware.

## What `npm run verify` checks (15/15 at ship time)

- Zero third-party requests — every network request stays first-party. There
  is no analytics, no tag manager, no third-party script of any kind; fonts
  are self-hosted subsets via `next/font` (latin), emitted under
  `/_next/static/media/`. This is a brand commitment (brand doc §1, §9).
- No horizontal scroll at 360 / 768 / 1440 px.
- The hero demo loops (panel opens, `inv` types, rows filter to 3, toast
  `Pasted to Xcode` appears), churns while visible, and pauses off-viewport
  (IntersectionObserver).
- `prefers-reduced-motion`: a single static final-state frame (panel open,
  `inv` typed, first row selected), no loop, no toast.
- FAQ deep-linking: `/#faq-storage` opens that item.
- The notify form fails gracefully (`Couldn't submit — email
  hello@clippanel.app instead.`) and never fakes success.
- Keyboard focus reaches interactive elements with a visible focus ring.
- Semantic HTML (`header/main/footer`, one `h1`, `SoftwareApplication`
  JSON-LD) and complete title/description/canonical/OG/Twitter meta.

## Gates at ship time

- **JS ≤ 120 KB gzipped:** 116.7 KiB first load (measured by gzipping every
  script referenced from `out/index.html`; nomodule polyfills excluded — they
  are only fetched by legacy browsers).
- **Lighthouse (mobile, simulated throttling, against the export served with
  gzip/brotli — see `scripts/lib/static-server.mjs`):** Performance 97,
  Accessibility 100, Best Practices 100, SEO 100. Observed (unthrottled) LCP
  is ~0.2 s; the simulated number is dominated by Lantern's 4G model.
- **Copy diff:** `npm run check:copy` — 74 user-facing strings compared
  against the brand doc, all verbatim; the allowlist (demo sample data,
  placeholder URLs, and the one added FAQ heading, "Frequently asked
  questions") is printed by the script.

## Release flag

The beta ships through GitHub Releases, so the default build is the
**release state**: every `Download for macOS` button is a real
`target="_blank" rel="noopener noreferrer"` anchor to
`https://github.com/vatsalsaglani/ClipPanel/releases` and additionally opens
the install-steps dialog (`src/components/install-dialog.tsx` — move to
Applications, `xattr -dr com.apple.quarantine /Applications/ClipPanel.app`
once in Terminal because the beta is not notarized, then launch). Build with
`NEXT_PUBLIC_RELEASE_READY=false` to preview the pre-release state (inline
`Get notified at launch` email form, wired to a placeholder endpoint marked
`// TODO: point at real endpoint` in `src/components/notify-form.tsx`).

## Known placeholders (intentional)

- `https://clippanel.app` and `hello@clippanel.app` — replace in
  `src/content.ts` when real.
- The install-dialog copy is new (the brand doc has no install steps yet);
  it is allowlisted in `scripts/check-copy.mjs`.
- The §5.6 visual is the panel recreation standing in for a real screenshot;
  swap 1:1 when app captures exist (brand doc §8).
- Changelog, Roadmap, License render tasteful inline "coming soon" notes
  instead of dead links.
