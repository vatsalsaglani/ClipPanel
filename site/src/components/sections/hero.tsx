import { cta, hero, releaseReady } from "@/content";
import { PanelDemo } from "../panel-demo";
import { NotifyForm } from "../notify-form";
import { DownloadCta } from "../download-cta";
import { Eyebrow } from "../section";

/** §5.1 Hero — demonstration over persuasion. */
export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden">
      <div className="mx-auto grid min-h-[100dvh] max-w-[1120px] grid-cols-[minmax(0,1fr)] items-center gap-16 px-6 pb-24 pt-36 lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)] lg:pb-16 lg:pt-28">
        <div className="min-w-0">
          <Eyebrow>{hero.eyebrow}</Eyebrow>
          <h1 className="mt-5 max-w-[12ch] font-display text-[44px] font-semibold leading-[1.04] tracking-[-0.025em] text-ink-100 md:text-[58px]">
            {hero.h1}
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-ink-400">
            {hero.sub}
          </p>

          <div className="mt-9">
            {releaseReady ? (
              <>
                <DownloadCta size="lg" />
                <p className="mt-3 text-sm text-ink-400">{hero.ctaSubtext}</p>
              </>
            ) : (
              <div id="notify" className="scroll-mt-28">
                <NotifyForm id="notify-email" subtext={cta.notifySubtext} />
              </div>
            )}
          </div>

          <a
            href={hero.secondaryHref}
            className="mt-6 inline-flex items-center gap-1.5 text-[15px] text-recall-400 transition-colors hover:text-lavender-100"
          >
            {hero.secondaryCta}
          </a>
        </div>

        <div className="w-full min-w-0">
          <PanelDemo />
        </div>
      </div>
    </section>
  );
}
