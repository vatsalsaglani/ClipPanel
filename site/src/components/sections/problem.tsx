import { problem } from "@/content";
import { Section } from "../section";
import { Reveal } from "../reveal";

/** §5.2 The problem — one short band, no cards. */
export function Problem() {
  return (
    <Section id="problem" className="py-24 md:py-32">
      <Reveal className="mx-auto max-w-3xl text-center">
        <h2 className="font-display text-[30px] font-semibold leading-[1.15] tracking-[-0.02em] text-ink-100 md:text-[38px]">
          {problem.h2}
        </h2>
        <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-ink-400">
          {problem.body}
        </p>
      </Reveal>
    </Section>
  );
}
