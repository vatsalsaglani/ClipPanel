"use client";

import { useEffect, useState } from "react";
import { Braces, Check, File, FileText, Link2, Search, X } from "lucide-react";
import { demo, type DemoRow } from "@/content";
import { cn } from "@/lib/utils";
import { useFitScale, useInView, usePrefersReducedMotion } from "@/lib/hooks";
import { Keycap } from "./keycap";

/**
 * <PanelDemo /> — pixel-faithful HTML/CSS recreation of the ClipPanel popup
 * (SPEC §3.2): search header, result rows (type icon/thumbnail, preview,
 * source app, relative time), and the keycap hint footer.
 *
 * Scripted loop: ⌃Q depresses → panel scales in (150ms ease-out, 0.98→1) →
 * "inv" types at human cadence, rows filter per keystroke → ↓ selects the
 * second row → ⏎ depresses → panel scales out → toast "Pasted to Xcode" →
 * long idle → reset. Pauses off-viewport; static final frame under
 * prefers-reduced-motion; scales down proportionally at mobile widths.
 */

const DESIGN_W = 640;
const DESIGN_H = 500;

type Pressed = "summon" | "down" | "return" | null;

interface Scene {
  open: boolean;
  query: string;
  selected: number;
  pressed: Pressed;
  toast: boolean;
}

/**
 * Resting state is "panel open, full list" — so the server-rendered frame
 * already shows the panel (early LCP) and hydration continues seamlessly.
 * The loop is the brand beat (§5.1), rotated: idle → "inv" types → rows
 * filter → ↓ selects → ⏎ dismisses → toast → ⌃Q summons the panel again.
 */
const INITIAL: Scene = { open: true, query: "", selected: 0, pressed: null, toast: false };
/** The single static frame rendered for prefers-reduced-motion. */
const FINAL: Scene = { open: true, query: demo.typedQuery, selected: 0, pressed: null, toast: false };

function filterRows(query: string): DemoRow[] {
  const q = query.trim().toLowerCase();
  if (!q) return [...demo.rows];
  return demo.rows.filter((row) => row.haystack.includes(q));
}

const kindIcon: Record<Exclude<DemoRow["kind"], "image">, typeof Link2> = {
  url: Link2,
  code: Braces,
  text: FileText,
  file: File,
};

function RowTile({ row, selected }: { row: DemoRow; selected: boolean }) {
  if (row.kind === "image") {
    // Aspect-fit thumbnail of the "screenshot".
    return (
      <div
        className={cn(
          "h-9 w-12 shrink-0 overflow-hidden rounded-[4px] border",
          selected ? "border-transparent" : "border-panel-500/50",
        )}
      >
        <div className="flex h-full flex-col bg-gradient-to-b from-panel-500/70 to-midnight-700">
          <div className="h-[5px] bg-midnight-900/60" />
          <div className="flex flex-1 flex-col justify-center gap-[3px] px-1.5">
            <div className="h-[2px] w-4/5 rounded-full bg-lavender-200/50" />
            <div className="h-[2px] w-3/5 rounded-full bg-recall-400/60" />
          </div>
        </div>
      </div>
    );
  }
  const Icon = kindIcon[row.kind];
  return (
    <div
      className={cn(
        "flex h-9 w-9 shrink-0 items-center justify-center rounded-[7px] border",
        selected
          ? "border-transparent bg-ink-100/10"
          : "border-panel-500/50 bg-midnight-700",
      )}
    >
      <Icon
        className={cn("h-4 w-4", selected ? "text-ink-100" : "text-memory-400")}
        strokeWidth={2}
        aria-hidden="true"
      />
    </div>
  );
}

function ResultRow({ row, selected }: { row: DemoRow; selected: boolean }) {
  const technical = row.kind === "code" || row.kind === "url";
  return (
    <div
      data-demo-row
      className={cn(
        "flex h-[52px] items-center gap-3 rounded-[9px] px-2.5",
        selected && "bg-recall-500",
      )}
    >
      <RowTile row={row} selected={selected} />
      <div className="min-w-0 flex-1">
        <div
          className={cn(
            "truncate text-[13px] leading-[1.35]",
            technical && "font-mono text-[12px]",
            selected ? "text-ink-100" : "text-ink-100",
          )}
        >
          {row.title}
        </div>
        <div
          className={cn(
            "truncate text-[11px] leading-[1.4]",
            selected ? "text-lavender-100/75" : "text-ink-400",
          )}
        >
          {row.sub}
        </div>
      </div>
      <div
        className={cn(
          "shrink-0 text-[11px] tabular-nums",
          selected ? "text-lavender-100/75" : "text-ink-400",
        )}
      >
        {row.time}
      </div>
    </div>
  );
}

function Panel({ scene, className }: { scene: Scene; className?: string }) {
  const rows = filterRows(scene.query);
  return (
    <div
      data-demo-panel
      className={cn(
        "overflow-hidden rounded-[14px] border border-panel-500/60 bg-midnight-800 shadow-panel transition-[opacity,transform] duration-150 ease-out",
        className,
      )}
      style={{
        opacity: scene.open ? 1 : 0,
        transform: scene.open ? "scale(1)" : "scale(0.98)",
        pointerEvents: "none",
      }}
    >
      {/* Search header */}
      <div className="flex h-12 items-center gap-2.5 border-b border-panel-500/40 px-4">
        <Search className="h-4 w-4 shrink-0 text-ink-400" strokeWidth={2} aria-hidden="true" />
        <div className="flex flex-1 items-center text-[13.5px] leading-none">
          {scene.query ? (
            <span data-demo-query className="font-mono text-[13px] text-ink-100">
              {scene.query}
            </span>
          ) : (
            <span className="text-ink-400/70">{demo.searchPlaceholder}</span>
          )}
          <span className="ml-0.5 inline-block h-[15px] w-[2px] bg-recall-400" />
        </div>
        {scene.query ? (
          <span className="flex h-5 w-5 items-center justify-center rounded-full bg-midnight-700">
            <X className="h-3 w-3 text-ink-400" strokeWidth={2} aria-hidden="true" />
          </span>
        ) : null}
      </div>

      {/* Result list */}
      <div className="p-1.5">
        {rows.map((row, i) => (
          <ResultRow key={row.id} row={row} selected={i === scene.selected} />
        ))}
      </div>

      {/* Hint footer — the same hints the real app shows */}
      <div className="flex min-h-10 flex-wrap items-center justify-center gap-x-4 gap-y-1 border-t border-panel-500/40 px-3 py-1.5">
        {demo.hints.map((hint) => (
          <span key={hint.label} className="flex items-center gap-1.5">
            {hint.keys.map((k) => (
              <Keycap key={k} size="sm">
                {k}
              </Keycap>
            ))}
            <span className="text-[10.5px] text-ink-400">{hint.label}</span>
          </span>
        ))}
      </div>
    </div>
  );
}

/** Static, always-open panel — used where a screenshot would sit (§5.6). */
export function StaticPanel({
  query = "",
  selected = 0,
  className,
}: {
  query?: string;
  selected?: number;
  className?: string;
}) {
  return (
    <Panel
      scene={{ open: true, query, selected, pressed: null, toast: false }}
      className={className}
    />
  );
}

function PressedKeyChip({ scene }: { scene: Scene }) {
  // ⌃Q waits raised whenever the panel is closed; ↓ / ⏎ show while pressed.
  let glyph: string | null = null;
  let depressed = false;
  if (!scene.open && !scene.toast) {
    glyph = "⌃Q";
    depressed = scene.pressed === "summon";
  } else if (scene.pressed === "down") {
    glyph = "↓";
    depressed = true;
  } else if (scene.pressed === "return") {
    glyph = "⏎";
    depressed = true;
  }
  return (
    <div
      className="absolute bottom-6 left-8 transition-opacity duration-100"
      style={{ opacity: glyph ? 1 : 0 }}
    >
      <Keycap size="lg" pressed={depressed}>
        {glyph ?? "⌃Q"}
      </Keycap>
    </div>
  );
}

function Toast({ visible }: { visible: boolean }) {
  return (
    <div
      data-demo-toast
      className="absolute bottom-14 left-1/2 transition-[opacity,transform] duration-200 ease-out"
      style={{
        opacity: visible ? 1 : 0,
        transform: `translateX(-50%) translateY(${visible ? 0 : 4}px)`,
      }}
    >
      <div className="flex items-center gap-2 rounded-full border border-panel-500/60 bg-midnight-700 py-2 pl-3 pr-4 shadow-lift">
        <Check className="h-3.5 w-3.5 text-recall-400" strokeWidth={2} aria-hidden="true" />
        <span className="text-[12.5px] text-ink-100">{demo.toast}</span>
      </div>
    </div>
  );
}

export function PanelDemo() {
  const reduced = usePrefersReducedMotion();
  const { ref: viewRef, inView } = useInView<HTMLDivElement>(0.25);
  const { ref: fitRef, scale, height } = useFitScale(DESIGN_W, DESIGN_H);
  const [scene, setScene] = useState<Scene>(INITIAL);

  useEffect(() => {
    if (reduced || !inView) {
      if (!reduced) setScene(INITIAL);
      return;
    }
    let cancelled = false;
    const timers = new Set<number>();
    const wait = (ms: number) =>
      new Promise<void>((resolve) => {
        const t = window.setTimeout(resolve, ms);
        timers.add(t);
      });
    const set = (patch: Partial<Scene>) => {
      if (!cancelled) setScene((s) => ({ ...s, ...patch }));
    };

    (async () => {
      while (!cancelled) {
        // Resting: panel open, full history visible (≥2.6s idle)
        await wait(2600);

        // "inv" types at human cadence; rows filter per keystroke
        for (const [i, ms] of [150, 120, 170].entries()) {
          set({ query: demo.typedQuery.slice(0, i + 1), selected: 0 });
          await wait(ms);
        }
        await wait(650);

        // ↓ highlights the second row
        set({ pressed: "down", selected: 1 });
        await wait(400);
        set({ pressed: null });
        await wait(340);

        // ⏎ depresses → panel scales out → toast "Pasted to Xcode"
        set({ pressed: "return" });
        await wait(300);
        set({ open: false, pressed: null, query: "", selected: 0 });
        await wait(240);
        set({ toast: true });
        await wait(1700);

        // Closed idle, ⌃Q waits raised; then depresses → panel scales in
        // (150ms ease-out, 0.98→1, fade). Combined idle ≥4s per cycle.
        set({ toast: false });
        await wait(1400);
        set({ pressed: "summon" });
        await wait(480);
        set({ open: true, pressed: null });
        await wait(480);
      }
    })();

    return () => {
      cancelled = true;
      timers.forEach((t) => window.clearTimeout(t));
    };
  }, [reduced, inView]);

  const shown = reduced ? FINAL : scene;

  return (
    <div ref={viewRef} className="relative" data-demo-stage>
      <p className="sr-only">
        Demo: pressing Control-Q opens the ClipPanel panel, typing filters the
        clipboard history instantly, arrow keys select a row, and Return pastes
        it into the app you came from.
      </p>
      <div
        ref={fitRef}
        aria-hidden="true"
        className="relative overflow-hidden"
        style={{ height }}
      >
        <div
          className="absolute left-1/2 top-0"
          style={{
            width: DESIGN_W,
            height: DESIGN_H,
            transform: `translateX(-50%) scale(${scale})`,
            transformOrigin: "top center",
          }}
        >
          {/* Faint radial lavender backdrop, ≤10% opacity */}
          <div className="absolute inset-0 bg-stage" />
          <div className="absolute left-1/2 top-5 -translate-x-1/2">
            <Panel scene={shown} className="w-[560px]" />
          </div>
          {!reduced && <PressedKeyChip scene={shown} />}
          {!reduced && <Toast visible={shown.toast} />}
        </div>
      </div>
    </div>
  );
}
