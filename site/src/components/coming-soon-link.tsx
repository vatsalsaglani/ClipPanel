"use client";

import { useState } from "react";
import { cta } from "@/content";
import { cn } from "@/lib/utils";

/**
 * Marked placeholder (Changelog, Roadmap): renders a tasteful inline
 * "coming soon" note instead of leading to a dead page.
 */
export function ComingSoonLink({
  label,
  className,
}: {
  label: string;
  className?: string;
}) {
  const [shown, setShown] = useState(false);
  return (
    <button
      type="button"
      onClick={() => setShown(true)}
      className={cn(
        "cursor-pointer text-left transition-colors hover:text-ink-100",
        className,
      )}
    >
      {label}
      {shown ? (
        <span className="text-ink-400/80"> · {cta.comingSoon}</span>
      ) : null}
    </button>
  );
}
