import { Check } from "lucide-react";
import { privacy } from "@/content";
import { Eyebrow, SectionTitle } from "../section";
import { Reveal } from "../reveal";

/**
 * §5.5 Privacy — the trust section: extra breathing room and a panel-500
 * hairline frame, reading as a document within the page.
 */
export function Privacy() {
  return (
    <section id="privacy" className="scroll-mt-20 py-28 md:py-40">
      <div className="mx-auto max-w-[1120px] px-6">
        <Reveal>
          <div className="rounded-[28px] border border-panel-500/60 bg-midnight-800 px-6 py-12 md:px-16 md:py-20">
            <Eyebrow>{privacy.eyebrow}</Eyebrow>
            <SectionTitle className="mt-4">{privacy.h2}</SectionTitle>
            <p className="mt-6 max-w-2xl text-lg leading-relaxed text-ink-400">
              {privacy.body}
            </p>

            <dl className="mt-12 divide-y divide-panel-500/30 border-y border-panel-500/30">
              {privacy.proofs.map((proof) => (
                <div
                  key={proof.label}
                  className="flex flex-col gap-1.5 py-4 sm:flex-row sm:items-baseline sm:gap-6"
                >
                  <dt className="flex shrink-0 items-center gap-2.5 sm:w-56">
                    <Check
                      className="h-4 w-4 shrink-0 text-lavender-200"
                      strokeWidth={2}
                      aria-hidden="true"
                    />
                    <span className="font-mono text-[13px] text-lavender-200">
                      {proof.label}
                    </span>
                  </dt>
                  <dd className="text-[15.5px] leading-relaxed text-ink-400">
                    {proof.body}
                  </dd>
                </div>
              ))}
            </dl>

            <p className="mt-10 max-w-2xl text-[17px] leading-relaxed text-ink-100">
              {privacy.closing}
            </p>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
