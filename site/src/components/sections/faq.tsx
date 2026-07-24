"use client";

import { useEffect, useState } from "react";
import { ChevronDown } from "lucide-react";
import { faq } from "@/content";
import { Section, SectionTitle } from "../section";

/**
 * §5.9 FAQ — native <details>/<summary> disclosure: keyboard-accessible
 * with zero JavaScript (summary is focusable, Enter/Space toggles), and
 * deep-linkable — landing on #faq-storage opens that item. A tiny script
 * adds single-open behavior and hash handling.
 */
export function Faq() {
  const [openId, setOpenId] = useState<string>("");

  useEffect(() => {
    const openFromHash = () => {
      const id = window.location.hash.slice(1);
      if (faq.items.some((item) => item.id === id)) setOpenId(id);
    };
    openFromHash();
    window.addEventListener("hashchange", openFromHash);
    return () => window.removeEventListener("hashchange", openFromHash);
  }, []);

  return (
    <Section id="faq" className="py-24 md:py-32">
      <SectionTitle>{faq.h2}</SectionTitle>
      <div className="mt-12 max-w-3xl">
        {faq.items.map((item) => (
          <details
            key={item.id}
            id={item.id}
            open={openId === item.id}
            onToggle={(e) => {
              if (e.currentTarget.open) setOpenId(item.id);
              else if (openId === item.id) setOpenId("");
            }}
            className="group scroll-mt-24 border-b border-panel-500/40"
          >
            <summary className="flex cursor-pointer list-none items-center justify-between gap-4 py-5 text-left font-display text-[17px] font-medium tracking-tight text-ink-100 transition-colors hover:text-lavender-100 [&::-webkit-details-marker]:hidden">
              {item.q}
              <ChevronDown
                className="h-4 w-4 shrink-0 text-ink-400 transition-transform duration-150 group-open:rotate-180"
                strokeWidth={2}
                aria-hidden="true"
              />
            </summary>
            <p className="pb-6 pr-8 text-[15.5px] leading-relaxed text-ink-400">
              {item.a}
            </p>
          </details>
        ))}
      </div>
    </Section>
  );
}
