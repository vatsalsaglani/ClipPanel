import { keyboard } from "@/content";
import { Keycap } from "../keycap";
import { Section, SectionTitle } from "../section";
import { Reveal } from "../reveal";

/** §5.7 Keyboard reference — compact table, doubles as docs. */
export function KeyboardReference() {
  const half = Math.ceil(keyboard.rows.length / 2);
  const columns = [keyboard.rows.slice(0, half), keyboard.rows.slice(half)];
  return (
    <Section id="keyboard" className="py-24 md:py-32">
      <Reveal>
        <SectionTitle>{keyboard.h2}</SectionTitle>
      </Reveal>
      <Reveal delay={80}>
        <div className="mt-12 grid gap-4 md:grid-cols-2">
          {columns.map((rows, i) => (
            <div
              key={i}
              className="overflow-hidden rounded-2xl border border-panel-500/40 bg-midnight-800"
            >
              <dl className="divide-y divide-panel-500/30">
                {rows.map((row) => (
                  <div
                    key={row.action}
                    className="flex items-center justify-between gap-6 px-5 py-3.5"
                  >
                    <dt className="flex shrink-0 items-center gap-1.5">
                      {row.keys.map((k) => (
                        <Keycap key={k} size="md">
                          {k}
                        </Keycap>
                      ))}
                    </dt>
                    <dd className="text-right text-[15px] text-ink-400">
                      {row.action}
                    </dd>
                  </div>
                ))}
              </dl>
            </div>
          ))}
        </div>
      </Reveal>
    </Section>
  );
}
