import { howItWorks } from "@/content";
import { Keycap } from "../keycap";
import { Section, SectionTitle } from "../section";
import { Reveal } from "../reveal";

/** §5.3 How it works — three steps, each headed by a keycap, not a number. */
export function HowItWorks() {
  return (
    <Section id="how-it-works" className="py-24 md:py-32">
      <Reveal>
        <SectionTitle>{howItWorks.h2}</SectionTitle>
      </Reveal>
      <div className="mt-14 grid gap-12 md:grid-cols-3 md:gap-8">
        {howItWorks.steps.map((step, i) => (
          <Reveal key={step.title} delay={i * 60}>
            <div>
              <Keycap size="lg">{step.keys[0]}</Keycap>
              <h3 className="mt-5 font-display text-xl font-semibold tracking-tight text-ink-100">
                {step.title}
              </h3>
              <p className="mt-2.5 leading-relaxed text-ink-400">{step.body}</p>
            </div>
          </Reveal>
        ))}
      </div>
    </Section>
  );
}
