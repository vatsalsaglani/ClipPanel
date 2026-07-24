type ClassValue = string | false | null | undefined;

/**
 * Tiny className joiner — no dependencies. Call sites never rely on
 * conflict resolution; overrides are done by passing distinct classes.
 */
export function cn(...inputs: ClassValue[]) {
  return inputs.filter(Boolean).join(" ");
}
