import { native } from "@/content";
import { Section, SectionTitle } from "../section";
import { Reveal } from "../reveal";
import { StaticPanel } from "../panel-demo";

/**
 * §5.6 Native quality — short band. The visual is the pixel-faithful panel
 * recreation standing in for a real screenshot until the app ships
 * (swapped 1:1 when captures exist — see README).
 */
export function NativeQuality() {
  return (
    <Section id="native" className="py-24 md:py-32">
      <div className="grid grid-cols-[minmax(0,1fr)] items-center gap-14 lg:grid-cols-2">
        <Reveal className="min-w-0">
          <SectionTitle>{native.h2}</SectionTitle>
          <p className="mt-6 max-w-lg text-lg leading-relaxed text-ink-400">
            {native.body}
          </p>
        </Reveal>

        <Reveal delay={80} className="min-w-0">
          {/* Outer 24px radius, 12px padding gap → inner 12px (concentric). */}
          <div className="rounded-[24px] border border-panel-500/40 bg-midnight-800 p-3 shadow-lift">
            <div className="flex justify-center rounded-[12px] bg-stage px-2 py-8 sm:px-6">
              <StaticPanel className="w-full max-w-[560px]" />
            </div>
          </div>
        </Reveal>
      </div>
    </Section>
  );
}
