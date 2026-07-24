import { cn } from "@/lib/utils";

/**
 * The keycap motif (brand doc §4.3): small rounded rect, 1px panel-500
 * border, midnight-700 fill, lavender-200 glyph, 1px bottom inner shadow.
 * Reused in the hero demo (and its hint footer), §5.3, and §5.7.
 */
const sizes = {
  sm: "min-w-6 h-6 px-1.5 text-[11px] rounded-[6px]",
  md: "min-w-7 h-7 px-2 text-[13px] rounded-[7px]",
  lg: "min-w-11 h-11 px-3 text-[17px] rounded-[9px]",
} as const;

export function Keycap({
  children,
  size = "md",
  pressed = false,
  className,
}: {
  children: React.ReactNode;
  size?: keyof typeof sizes;
  pressed?: boolean;
  className?: string;
}) {
  return (
    <kbd
      aria-hidden="true"
      className={cn(
        "inline-flex select-none items-center justify-center border border-panel-500 bg-midnight-700 font-mono leading-none text-lavender-200",
        "shadow-[inset_0_-1px_0_0_rgb(13_15_32/0.9),inset_0_1px_0_0_rgb(207_203_255/0.06)]",
        "transition-[transform,background-color,border-color] duration-100",
        sizes[size],
        pressed && "translate-y-px scale-[0.94] border-panel-600 bg-panel-600",
        className,
      )}
    >
      {children}
    </kbd>
  );
}
