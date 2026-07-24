/**
 * Brand marks from the app's own assets. Never substitute a different
 * clipboard icon for these (brand doc §4.4).
 */

/** Menu bar glyph — ClipPanel/Assets.xcassets/MenuBarIcon.imageset template. */
export function MenuBarGlyph({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 32 32"
      className={className}
      fill="none"
      aria-hidden="true"
      focusable="false"
    >
      <path
        d="M 9.75 21.75 A 4.5 4.5 0 0 1 5.25 17.25 L 5.25 9.75 A 4.5 4.5 0 0 1 9.75 5.25 L 17.25 5.25 A 4.5 4.5 0 0 1 21.75 9.75"
        stroke="currentColor"
        strokeWidth="2.5"
        strokeLinecap="round"
      />
      <rect x="12" y="12" width="14" height="14" rx="4" fill="currentColor" />
    </svg>
  );
}

/**
 * Master app icon — ClipPanel/Assets.xcassets/AppIcon.appiconset/ClipPanelIcon.svg.
 * Rendered once per page (gradient ids are not namespaced).
 */
export function AppIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 1024 1024" className={className} aria-hidden="true" focusable="false">
      <defs>
        <linearGradient id="appicon-bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#20244A" />
          <stop offset="1" stopColor="#12142C" />
        </linearGradient>
        <radialGradient id="appicon-glow" cx="0.5" cy="0.42" r="0.6">
          <stop offset="0" stopColor="#A9A4F5" stopOpacity="0.10" />
          <stop offset="1" stopColor="#A9A4F5" stopOpacity="0" />
        </radialGradient>
        <linearGradient id="appicon-card" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#6487FA" />
          <stop offset="1" stopColor="#4A64E8" />
        </linearGradient>
        <linearGradient id="appicon-tray" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#3B4080" />
          <stop offset="1" stopColor="#2A2E5C" />
        </linearGradient>
      </defs>
      <rect width="1024" height="1024" rx="232" fill="url(#appicon-bg)" />
      <rect width="1024" height="1024" rx="232" fill="url(#appicon-glow)" />
      <rect x="298" y="336" width="212" height="260" rx="32" fill="#464B96" />
      <rect x="338" y="392" width="132" height="16" rx="8" fill="#5C62B4" />
      <rect x="338" y="432" width="96" height="16" rx="8" fill="#5C62B4" />
      <rect x="462" y="244" width="276" height="372" rx="42" fill="url(#appicon-card)" />
      <rect x="510" y="330" width="180" height="18" rx="9" fill="#A9BBFF" />
      <rect x="510" y="376" width="132" height="18" rx="9" fill="#8FA6FE" />
      <rect x="540" y="228" width="120" height="32" rx="16" fill="#CFCBFF" />
      <rect x="230" y="520" width="564" height="274" rx="58" fill="url(#appicon-tray)" />
      <rect x="230" y="520" width="564" height="12" rx="6" fill="#585EAE" />
    </svg>
  );
}
