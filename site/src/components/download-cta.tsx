"use client";

import { useState } from "react";
import { cta, site } from "@/content";
import { buttonClassName } from "./ui/button";
import { InstallDialog } from "./install-dialog";

/**
 * The one primary action (§6): opens GitHub Releases in a new tab — a real
 * anchor, crawlable and functional without JavaScript — and shows the
 * install-steps dialog in this tab.
 */
export function DownloadCta({
  size = "md",
  className,
  onNavigate,
}: {
  size?: "sm" | "md" | "lg";
  className?: string;
  onNavigate?: () => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <a
        href={site.releasesUrl}
        target="_blank"
        rel="noopener noreferrer"
        onClick={() => {
          setOpen(true);
          onNavigate?.();
        }}
        className={buttonClassName({ size, className })}
      >
        {cta.download}
      </a>
      <InstallDialog open={open} onClose={() => setOpen(false)} />
    </>
  );
}
