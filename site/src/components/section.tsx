import { cn } from "@/lib/utils";

/** Shared section shell: 1120px content width, scroll margin under the nav. */
export function Section({
  id,
  className,
  children,
}: {
  id: string;
  className?: string;
  children: React.ReactNode;
}) {
  return (
    <section id={id} className={cn("scroll-mt-20", className)}>
      <div className="mx-auto max-w-[1120px] px-6">{children}</div>
    </section>
  );
}

export function Eyebrow({ children }: { children: React.ReactNode }) {
  return (
    <p className="text-xs font-medium tracking-[0.14em] text-ink-400">
      {children}
    </p>
  );
}

export function SectionTitle({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <h2
      className={cn(
        "font-display text-[32px] font-semibold leading-[1.12] tracking-[-0.02em] text-ink-100 md:text-[40px]",
        className,
      )}
    >
      {children}
    </h2>
  );
}
