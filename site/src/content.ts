/**
 * content.ts — the single home of every string on the page.
 *
 * All marketing copy is verbatim from `../landing-page-site-guide.md`
 * (ClipPanel — Brand, Vision & Landing Page Content, v1.0). Do not
 * rephrase here; if the brand doc changes, change the doc first.
 *
 * `npm run check:copy` diffs these strings against the brand doc.
 */

export const releaseReady = process.env.NEXT_PUBLIC_RELEASE_READY === "true";

export const site = {
  name: "ClipPanel",
  url: "https://clippanel.app",
  email: "hello@clippanel.app",
  // TODO: replace with the real download artifact when the binary ships.
  downloadUrl: "/download/ClipPanel.dmg",
  meta: {
    title: "ClipPanel — Clipboard history for macOS, one keystroke away",
    description:
      "A quiet, local-first clipboard history for macOS. Press a shortcut, search, hit Return — anything you copied is pasted back. Nothing leaves your Mac.",
    keywords: [
      "clipboard history macOS",
      "clipboard manager Mac alternative",
      "paste history Mac",
      "menu bar clipboard",
    ],
  },
  /** Elevator paragraph — §3, reusable everywhere. */
  elevator:
    "ClipPanel is a quiet, local-first clipboard history for macOS. Press a shortcut, type a few letters, hit Return — whatever you copied is back and pasted where you're working. Text, images, links, files. Nothing leaves your Mac.",
} as const;

export const cta = {
  download: "Download for macOS",
  notify: "Get notified at launch",
  /** Pre-release sub-text — §6, honored literally. */
  notifySubtext: "No spam — one email when it ships, then the list is deleted.",
  /** Shown when the placeholder endpoint fails. Never fake success. */
  notifyFailure: "Couldn't submit — email hello@clippanel.app instead.",
  comingSoon: "coming soon",
} as const;

export const nav = {
  links: [
    { label: "How it works", href: "#how-it-works", id: "how-it-works" },
    { label: "Privacy", href: "#privacy", id: "privacy" },
    { label: "FAQ", href: "#faq", id: "faq" },
  ],
} as const;

export const hero = {
  eyebrow: "For macOS 14+ · Free during beta",
  h1: "Everything you copied. One keystroke away.",
  sub: "ClipPanel keeps a quiet, searchable history of your clipboard — text, links, images, files — and pastes any of it back exactly where you're working. Local-first. Keyboard-first. Native.",
  ctaSubtext: "Free beta · Apple Silicon & Intel · No account",
  secondaryCta: "See how it works ↓",
  secondaryHref: "#how-it-works",
} as const;

export const problem = {
  h2: "Your Mac remembers one thing. You copy fifty.",
  body: "Every copy overwrites the last. The API key you grabbed before the error message. The paragraph you cut and meant to paste elsewhere. The screenshot from twenty minutes ago. Gone — unless something was quietly keeping track.",
} as const;

export const howItWorks = {
  h2: "Recall in three keys.",
  steps: [
    {
      keys: ["⌃Q"],
      title: "Summon",
      body: "Press your shortcut anywhere. The panel opens next to your pointer, search focused, most recent copy selected.",
    },
    {
      keys: ["a…z"],
      title: "Search",
      body: "Type a few letters. ClipPanel filters as you type — matching content, source app, even file names. Pinned items stay on top.",
    },
    {
      keys: ["⏎"],
      title: "Paste",
      body: "Return pastes straight into the app you came from. Shift-Return pastes plain text. Escape, and it's like the panel was never there.",
    },
  ],
} as const;

export const features = {
  h2: "A utility, not a workspace.",
  intro: "Everything you need from clipboard history. Nothing you don't.",
  items: [
    {
      title: "Rich formats survive",
      body: "Rich text stays rich, images stay images, files stay files. Multi-item copies are preserved intact — nothing silently degrades to plain text.",
    },
    {
      title: "Pin what matters",
      body: "Keep addresses, snippets, and boilerplate pinned above the stream. Pinned items never expire.",
    },
    {
      title: "Search that thinks in fragments",
      body: "Case- and accent-insensitive, ranks exact and word-boundary matches first. Under 50ms across a thousand items.",
    },
    {
      title: "Knows what not to keep",
      body: "Password managers and other apps that mark content as concealed or transient are ignored by default. Add your own ignore list per app.",
    },
    {
      title: "Copy-only fallback",
      body: "No paste permission? ClipPanel still puts your selection on the clipboard and tells you, instead of failing silently.",
    },
    {
      title: "Launches at login, lives in the menu bar",
      body: "No Dock icon, no window clutter. Pause monitoring any time from the menu bar.",
    },
  ],
} as const;

export const privacy = {
  eyebrow: "Privacy by architecture",
  h2: "Your clipboard history never leaves your Mac.",
  body: "Not \"encrypted in transit\". Not \"anonymized\". It simply never leaves. ClipPanel has no network code, no analytics SDK, no accounts, and no sync. History is stored locally in Apple's SwiftData, and you can open the data folder, clear it, or cap its size at any time.",
  proofs: [
    {
      label: "network entitlement",
      body: "none. The app cannot make network requests.",
    },
    {
      label: "analytics",
      body: "none. Not privacy-friendly analytics. None.",
    },
    {
      label: "logging",
      body: "clipboard contents, filenames, and search queries are never written to logs.",
    },
    {
      label: "retention",
      body: "you set the limit. Clear unpinned history in one click.",
    },
  ],
  closing:
    "If a clipboard tool can read everything you copy, you should be able to verify what it does with that. ClipPanel's answer: nothing, verifiably.",
} as const;

export const native = {
  h2: "Built for this Mac, not ported to it.",
  body: "SwiftUI and AppKit where each is strongest. System materials, adaptive light and dark, SF-native typography, full keyboard control, multi-display aware. ClipPanel follows your system appearance and your accent color — it looks like it shipped with macOS.",
} as const;

export const keyboard = {
  h2: "The whole app fits on one row of hints.",
  rows: [
    { keys: ["⏎"], action: "paste" },
    { keys: ["⇧⏎"], action: "paste as plain text" },
    { keys: ["⌥⏎"], action: "copy only" },
    { keys: ["↑", "↓"], action: "select" },
    { keys: ["⌘P"], action: "pin" },
    { keys: ["⌫"], action: "delete" },
    { keys: ["⎋"], action: "dismiss" },
    { keys: ["⌘,"], action: "settings" },
  ],
} as const;

export const scope = {
  h2: "What ClipPanel doesn't do.",
  body: "No cloud sync. No accounts. No AI. No OCR. No scripting engine, plugin system, or snippet workspace. No Windows or Linux version. ClipPanel does one job — remembering your clipboard — and stays out of the way for everything else. If you need more than that, you probably need a different kind of tool, and that's fine.",
} as const;

export const faq = {
  h2: "Frequently asked questions",
  items: [
    {
      id: "faq-free",
      q: "Is it really free?",
      a: "During the beta, yes, fully. After 1.0 the plan is a one-time purchase — never a subscription, and beta users will be treated kindly. There is no account either way.",
    },
    {
      id: "faq-paste-permission",
      q: "Why does it need permission to paste?",
      a: "To press ⌘V into the previous app for you, macOS requires a post-event permission (not full Accessibility access). If you decline, ClipPanel works in copy-only mode.",
    },
    {
      id: "faq-passwords",
      q: "Does it capture passwords?",
      a: "Content marked concealed or transient by apps like password managers is ignored by default. You can also add any app to the ignore list, or pause monitoring entirely.",
    },
    {
      id: "faq-storage",
      q: "Where is my history stored?",
      a: "In a local database in your Library folder, managed by Apple's SwiftData. Settings → About → Open Data Folder shows you exactly where.",
    },
    {
      id: "faq-macs",
      q: "Which Macs does it support?",
      a: "macOS 14 Sonoma or later, Apple Silicon and Intel.",
    },
    {
      id: "faq-launchers",
      q: "How is this different from the clipboard in Raycast or Alfred?",
      a: "Those are excellent launchers with a clipboard feature. ClipPanel is only a clipboard panel — smaller, standalone, and native SwiftUI, with no launcher to adopt.",
    },
  ],
} as const;

export const finalCta = {
  h2: "Stop losing what you copied.",
  sub: "One shortcut between you and everything you copied today.",
  ctaSubtext: "macOS 14+ · Free beta · No account, no sync, no telemetry",
  privacyLink: "Read the privacy notes →",
  changelogLink: "View changelog",
} as const;

export const footer = {
  tagline: "ClipPanel is a quiet, local-first clipboard history for macOS.",
  columns: [
    {
      title: "Product",
      links: [
        { label: "Download", href: "#download", kind: "anchor" as const },
        { label: "Changelog", href: "#", kind: "soon" as const },
        { label: "Roadmap", href: "#", kind: "soon" as const },
      ],
    },
    {
      title: "Support",
      links: [
        { label: "FAQ", href: "#faq", kind: "anchor" as const },
        {
          label: "Contact email",
          href: "mailto:hello@clippanel.app",
          kind: "anchor" as const,
        },
        {
          label: "Report an issue",
          href: "mailto:hello@clippanel.app?subject=ClipPanel%20issue",
          kind: "anchor" as const,
        },
      ],
    },
    {
      title: "Legal",
      links: [
        { label: "Privacy", href: "#privacy", kind: "anchor" as const },
        { label: "License", href: "#", kind: "soon" as const },
      ],
    },
  ],
  line: "Made in Bengaluru. Runs only on your Mac.",
} as const;

/* ------------------------------------------------------------------ */
/* Hero demo — invented sample data, nothing branded (§5.1, SPEC §3.2) */
/* ------------------------------------------------------------------ */

export type DemoRowKind = "url" | "code" | "image" | "file" | "text";

export interface DemoRow {
  id: string;
  kind: DemoRowKind;
  /** Primary preview line. */
  title: string;
  /** Secondary line: source app, format details, or path summary. */
  sub: string;
  /** Relative time. */
  time: string;
  /** Haystack used by the demo's filter (content + app + file names). */
  haystack: string;
}

export const demo = {
  typedQuery: "inv",
  toast: "Pasted to Xcode",
  searchPlaceholder: "Search",
  hints: [
    { keys: ["⏎"], label: "Paste" },
    { keys: ["⇧⏎"], label: "Plain Text" },
    { keys: ["⌥⏎"], label: "Copy" },
    { keys: ["⎋"], label: "Close" },
  ],
  rows: [
    {
      id: "r1",
      kind: "url",
      title: "console.example.dev/invoices/inv_1042",
      sub: "Safari",
      time: "14s",
      haystack: "console.example.dev/invoices/inv_1042 safari",
    },
    {
      id: "r2",
      kind: "code",
      title: 'await invoiceClient.retry(id: "inv_1042")',
      sub: "Xcode",
      time: "3m",
      haystack: 'await invoiceclient.retry(id: "inv_1042") xcode',
    },
    {
      id: "r3",
      kind: "image",
      title: "Screenshot 2026-07-23 at 14.32.png",
      sub: "1440 × 900 · 1.2 MB",
      time: "26m",
      haystack: "screenshot 2026-07-23 at 14.32.png image",
    },
    {
      id: "r4",
      kind: "text",
      title: "Migration runs Thursday 09:00 UTC — freeze merges after standup.",
      sub: "Mail",
      time: "41m",
      haystack: "migration runs thursday 09:00 utc — freeze merges after standup. mail",
    },
    {
      id: "r5",
      kind: "file",
      title: "invoice-july.csv",
      sub: "3 items · ~/Documents/exports",
      time: "1h",
      haystack: "invoice-july.csv ~/documents/exports finder",
    },
    {
      id: "r6",
      kind: "text",
      title: "standup: shipped retry backoff, pairing with Riya on webhooks",
      sub: "Notes",
      time: "2h",
      haystack: "standup: shipped retry backoff, pairing with riya on webhooks notes",
    },
  ] satisfies DemoRow[],
} as const;
