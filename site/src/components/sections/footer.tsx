import { footer, releaseReady } from "@/content";
import { AppIcon } from "../brand-icons";
import { ComingSoonLink } from "../coming-soon-link";

/** §5.11 Footer — no social icons until real accounts exist. */
export function Footer() {
  return (
    <footer className="border-t border-panel-500/30 py-14">
      <div className="mx-auto max-w-[1120px] px-6">
        <div className="grid gap-12 md:grid-cols-[2fr_1fr_1fr_1fr]">
          <div>
            <div className="flex items-center gap-2.5">
              <AppIcon className="h-7 w-7 rounded-[7px]" />
              <span className="font-display text-[15px] font-semibold tracking-tight text-ink-100">
                ClipPanel
              </span>
            </div>
            <p className="mt-4 max-w-xs text-sm leading-relaxed text-ink-400">
              {footer.tagline}
            </p>
          </div>

          {footer.columns.map((column) => (
            <nav key={column.title} aria-label={column.title}>
              <h3 className="text-[13px] font-medium text-ink-100">
                {column.title}
              </h3>
              <ul className="mt-3.5 space-y-2.5">
                {column.links.map((link) => (
                  <li key={link.label}>
                    {link.kind === "soon" ? (
                      <ComingSoonLink
                        label={link.label}
                        className="text-sm text-ink-400"
                      />
                    ) : (
                      <a
                        href={
                          link.label === "Download" && !releaseReady
                            ? "#notify"
                            : link.href
                        }
                        className="text-sm text-ink-400 transition-colors hover:text-ink-100"
                      >
                        {link.label}
                      </a>
                    )}
                  </li>
                ))}
              </ul>
            </nav>
          ))}
        </div>

        <div className="mt-12 border-t border-panel-500/20 pt-6 text-[13px] text-ink-400/80">
          {footer.line}
        </div>
      </div>
    </footer>
  );
}
