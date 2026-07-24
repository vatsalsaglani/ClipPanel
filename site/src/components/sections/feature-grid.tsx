import { Copy, EyeOff, Layers, PanelTop, Pin, Search } from "lucide-react";
import { features } from "@/content";
import { cn } from "@/lib/utils";
import { Section, SectionTitle } from "../section";
import { Reveal } from "../reveal";

/**
 * §5.4 Feature grid — six items with deliberate hierarchy, not three
 * identical cards: one featured cell, then a 5/4-4-4/12 rhythm.
 */
const icons = [Layers, Pin, Search, EyeOff, Copy, PanelTop] as const;

const spans = [
  "lg:col-span-7",
  "lg:col-span-5",
  "lg:col-span-4",
  "lg:col-span-4",
  "lg:col-span-4",
  "lg:col-span-12",
] as const;

/** Pasteboard type identifiers shown on the featured card. */
const formatChips = [
  "public.utf8-plain-text",
  "public.html",
  "public.png",
  "public.file-url",
] as const;

export function FeatureGrid() {
  return (
    <Section id="features" className="py-24 md:py-32">
      <Reveal>
        <SectionTitle>{features.h2}</SectionTitle>
        <p className="mt-4 max-w-xl text-lg text-ink-400">{features.intro}</p>
      </Reveal>

      <div className="mt-14 grid gap-4 md:grid-cols-2 lg:grid-cols-12">
        {features.items.map((item, i) => {
          const Icon = icons[i];
          const featured = i === 0;
          const wide = i === features.items.length - 1;
          return (
            <Reveal key={item.title} className={cn(spans[i])} delay={i * 40}>
              <div
                className={cn(
                  "h-full rounded-2xl border border-panel-500/40 bg-midnight-800 p-6 md:p-7",
                  wide && "md:flex md:items-center md:gap-6",
                )}
              >
                <Icon
                  className={cn(
                    "h-5 w-5 shrink-0",
                    featured ? "text-lavender-200" : "text-memory-400",
                    wide && "md:mb-0 mb-4",
                    !wide && "mb-4",
                  )}
                  strokeWidth={2}
                  aria-hidden="true"
                />
                <div>
                  <h3 className="font-display text-lg font-semibold tracking-tight text-ink-100">
                    {item.title}
                  </h3>
                  <p className="mt-2 text-[15px] leading-relaxed text-ink-400">
                    {item.body}
                  </p>
                  {featured ? (
                    <div className="mt-5 flex flex-wrap gap-1.5">
                      {formatChips.map((chip) => (
                        <span
                          key={chip}
                          className="rounded-[6px] border border-panel-500/50 px-1.5 py-0.5 font-mono text-[10.5px] text-ink-400"
                        >
                          {chip}
                        </span>
                      ))}
                    </div>
                  ) : null}
                </div>
              </div>
            </Reveal>
          );
        })}
      </div>
    </Section>
  );
}
