import { cta, finalCta, releaseReady, site } from "@/content";
import { Section, SectionTitle } from "../section";
import { Reveal } from "../reveal";
import { NotifyForm } from "../notify-form";
import { ComingSoonLink } from "../coming-soon-link";
import { ButtonLink } from "../ui/button";

/** §5.10 Final CTA band. */
export function FinalCta() {
  return (
    <Section id="download" className="py-28 md:py-36">
      <Reveal className="mx-auto max-w-2xl text-center">
        <SectionTitle className="md:text-[44px]">{finalCta.h2}</SectionTitle>
        <p className="mt-4 text-lg text-ink-400">{finalCta.sub}</p>

        <div className="mt-9">
          {releaseReady ? (
            <>
              <ButtonLink size="lg" href={site.downloadUrl}>
                {cta.download}
              </ButtonLink>
              <p className="mt-3 text-sm text-ink-400">{finalCta.ctaSubtext}</p>
            </>
          ) : (
            <NotifyForm
              id="notify-email-final"
              subtext={cta.notifySubtext}
              center
            />
          )}
        </div>

        <div className="mt-8 flex items-center justify-center gap-6 font-mono text-[13px]">
          <a
            href="#privacy"
            className="text-recall-400 transition-colors hover:text-lavender-100"
          >
            {finalCta.privacyLink}
          </a>
          <ComingSoonLink
            label={finalCta.changelogLink}
            className="text-ink-400"
          />
        </div>
      </Reveal>
    </Section>
  );
}
