"use client";

import { useEffect, useRef, useState } from "react";
import { Check, Copy, X } from "lucide-react";
import { install } from "@/content";
import { Keycap } from "./keycap";
import { Button } from "./ui/button";

/**
 * Install steps dialog — shown after a download click opens GitHub Releases
 * in a new tab. Quiet modal: dim overlay (no blur), hairline frame, 150ms
 * summon-style entrance, Esc/backdrop close, focus trapped and restored.
 */
export function InstallDialog({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const dialogRef = useRef<HTMLDivElement>(null);
  const restoreRef = useRef<Element | null>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!open) return;
    restoreRef.current = document.activeElement;
    setCopied(false);
    const dialog = dialogRef.current;
    dialog?.focus();

    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
        return;
      }
      if (e.key !== "Tab" || !dialog) return;
      const focusables = dialog.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])',
      );
      if (focusables.length === 0) return;
      const first = focusables[0];
      const last = focusables[focusables.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };

    document.addEventListener("keydown", onKey);
    const prevOverflow = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.documentElement.style.overflow = prevOverflow;
      if (restoreRef.current instanceof HTMLElement) restoreRef.current.focus();
    };
  }, [open, onClose]);

  if (!open) return null;

  const copyCommand = async () => {
    try {
      await navigator.clipboard.writeText(install.command);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1600);
    } catch {
      // Clipboard unavailable — the command stays selectable for manual copy.
    }
  };

  return (
    <div
      className="overlay-enter fixed inset-0 z-[60] flex items-center justify-center bg-midnight-900/80 p-4"
      onClick={onClose}
    >
      <div
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="install-dialog-title"
        tabIndex={-1}
        onClick={(e) => e.stopPropagation()}
        className="dialog-enter w-full max-w-md rounded-2xl border border-panel-500/60 bg-midnight-800 p-6 shadow-panel outline-none md:p-7"
      >
        <div className="flex items-start justify-between gap-4">
          <h2
            id="install-dialog-title"
            className="font-display text-[22px] font-semibold tracking-tight text-ink-100"
          >
            {install.title}
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="-mr-1 -mt-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-[8px] text-ink-400 transition-colors hover:text-ink-100"
          >
            <X className="h-4 w-4" strokeWidth={2} aria-hidden="true" />
          </button>
        </div>

        <p className="mt-2 text-[15px] leading-relaxed text-ink-400">
          {install.intro}
        </p>

        <ol className="mt-5 space-y-4">
          {install.steps.map((step, i) => (
            <li key={step.id} className="flex gap-3">
              <span
                aria-hidden="true"
                className="mt-px shrink-0 font-mono text-[13px] leading-relaxed text-ink-400"
              >
                {i + 1}.
              </span>
              <div className="min-w-0">
                <p className="text-[15px] leading-relaxed text-ink-100">
                  {step.text}
                  {"keycap" in step && step.keycap ? (
                    <>
                      <Keycap size="sm" className="mx-0.5 align-[-2px]">
                        {step.keycap}
                      </Keycap>
                      {"textAfter" in step ? step.textAfter : null}
                    </>
                  ) : null}
                </p>
                {step.id === "quarantine" ? (
                  <div className="mt-2.5 flex items-center gap-2 rounded-[9px] border border-panel-500/50 bg-midnight-900 py-2 pl-3 pr-2">
                    <code className="flex-1 select-all overflow-x-auto whitespace-nowrap font-mono text-[12.5px] text-lavender-200">
                      {install.command}
                    </code>
                    <button
                      type="button"
                      onClick={copyCommand}
                      className="flex h-7 shrink-0 items-center gap-1.5 rounded-[7px] border border-panel-500/60 px-2 font-mono text-[11px] text-ink-400 transition-colors hover:text-ink-100"
                    >
                      {copied ? (
                        <Check className="h-3 w-3 text-lavender-200" strokeWidth={2} aria-hidden="true" />
                      ) : (
                        <Copy className="h-3 w-3" strokeWidth={2} aria-hidden="true" />
                      )}
                      {copied ? install.copiedCommand : install.copyCommand}
                    </button>
                  </div>
                ) : null}
              </div>
            </li>
          ))}
        </ol>

        <div className="mt-6 flex items-center justify-between gap-4">
          <p className="text-[13px] text-ink-400">{install.footnote}</p>
          <Button type="button" size="sm" onClick={onClose}>
            {install.close}
          </Button>
        </div>
      </div>
    </div>
  );
}
