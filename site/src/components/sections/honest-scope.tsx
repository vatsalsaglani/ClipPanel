import { scope } from "@/content";
import { Section, SectionTitle } from "../section";
import { Reveal } from "../reveal";

/** §5.8 Honest scope — the differentiator, deadpan allowed. */
export function HonestScope() {
  return (
    <Section id="scope" className="py-24 md:py-32">
      <Reveal className="max-w-3xl">
        <SectionTitle>{scope.h2}</SectionTitle>
        <p className="mt-6 text-lg leading-relaxed text-ink-400">{scope.body}</p>
      </Reveal>
    </Section>
  );
}
