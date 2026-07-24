"use client";

import { useEffect, useState } from "react";
import { Menu, X } from "lucide-react";
import { cta, nav, releaseReady, site } from "@/content";
import { cn } from "@/lib/utils";
import { MenuBarGlyph } from "./brand-icons";
import { ButtonLink } from "./ui/button";

/** Sticky, translucent midnight-blur nav (§5.0). Highlights active section. */
export function Nav() {
  const [active, setActive] = useState<string>("");
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const sections = nav.links
      .map((l) => document.getElementById(l.id))
      .filter((el): el is HTMLElement => el !== null);
    if (sections.length === 0) return;
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) setActive(entry.target.id);
        }
      },
      { rootMargin: "-38% 0px -56% 0px" },
    );
    sections.forEach((s) => io.observe(s));
    return () => io.disconnect();
  }, []);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  const ctaHref = releaseReady ? site.downloadUrl : "#notify";
  const ctaLabel = releaseReady ? cta.download : cta.notify;

  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-panel-500/30 bg-midnight-900/75 backdrop-blur-md">
      <nav
        aria-label="Main"
        className="mx-auto flex h-16 max-w-[1120px] items-center justify-between px-6"
      >
        <a
          href="#top"
          className="flex items-center gap-2.5"
          onClick={() => setOpen(false)}
        >
          <MenuBarGlyph className="h-5 w-5 text-lavender-200" />
          <span className="font-display text-[17px] font-semibold tracking-tight text-ink-100">
            ClipPanel
          </span>
        </a>

        <div className="hidden items-center gap-7 md:flex">
          {nav.links.map((link) => (
            <a
              key={link.id}
              href={link.href}
              className={cn(
                "text-sm transition-colors",
                active === link.id
                  ? "text-ink-100"
                  : "text-ink-400 hover:text-ink-100",
              )}
            >
              {link.label}
            </a>
          ))}
          <ButtonLink size="sm" href={ctaHref}>
            {ctaLabel}
          </ButtonLink>
        </div>

        <button
          type="button"
          className="flex h-10 w-10 items-center justify-center rounded-[9px] text-ink-100 md:hidden"
          aria-expanded={open}
          aria-label={open ? "Close menu" : "Open menu"}
          onClick={() => setOpen((v) => !v)}
        >
          {open ? (
            <X className="h-5 w-5" strokeWidth={2} aria-hidden="true" />
          ) : (
            <Menu className="h-5 w-5" strokeWidth={2} aria-hidden="true" />
          )}
        </button>
      </nav>

      {open ? (
        <div className="border-t border-panel-500/30 bg-midnight-900/95 px-6 pb-6 pt-3 backdrop-blur-md md:hidden">
          <div className="flex flex-col gap-1">
            {nav.links.map((link) => (
              <a
                key={link.id}
                href={link.href}
                onClick={() => setOpen(false)}
                className="rounded-[9px] px-2 py-3 text-[15px] text-ink-100"
              >
                {link.label}
              </a>
            ))}
            <ButtonLink
              className="mt-3"
              href={ctaHref}
              onClick={() => setOpen(false)}
            >
              {ctaLabel}
            </ButtonLink>
          </div>
        </div>
      ) : null}
    </header>
  );
}
