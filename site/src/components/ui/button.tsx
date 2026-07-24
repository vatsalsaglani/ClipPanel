import * as React from "react";
import { cn } from "@/lib/utils";

/**
 * shadcn/ui Button styles, brand-adjusted: recall-400→recall-500 shallow
 * vertical gradient, ink-100 text, sentence case (§4.1, §6). Two real
 * elements instead of Slot — keeps the client bundle smaller.
 */
const variants = {
  primary:
    "bg-cta text-ink-100 shadow-lift transition-[filter] hover:brightness-110 active:brightness-95",
  secondary:
    "border border-panel-500 bg-midnight-800 text-ink-100 transition-colors hover:bg-midnight-700",
  ghost: "text-ink-400 transition-colors hover:text-ink-100",
} as const;

const sizes = {
  sm: "h-9 gap-2 rounded-[9px] px-4 text-sm",
  md: "h-11 gap-2 rounded-[10px] px-5 text-[15px]",
  lg: "h-12 gap-2 rounded-[11px] px-6 text-base",
} as const;

type Variant = keyof typeof variants;
type Size = keyof typeof sizes;

const base =
  "inline-flex items-center justify-center whitespace-nowrap font-medium leading-none";

export function buttonClassName({
  variant = "primary",
  size = "md",
  className,
}: {
  variant?: Variant;
  size?: Size;
  className?: string;
} = {}) {
  return cn(base, variants[variant], sizes[size], className);
}

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
}

export function Button({
  className,
  variant = "primary",
  size = "md",
  type = "button",
  ...props
}: ButtonProps) {
  return (
    <button
      type={type}
      className={buttonClassName({ variant, size, className })}
      {...props}
    />
  );
}

export interface ButtonLinkProps
  extends React.AnchorHTMLAttributes<HTMLAnchorElement> {
  variant?: Variant;
  size?: Size;
}

export function ButtonLink({
  className,
  variant = "primary",
  size = "md",
  ...props
}: ButtonLinkProps) {
  return (
    <a className={buttonClassName({ variant, size, className })} {...props} />
  );
}
