"use client";

import { useState } from "react";
import { cta } from "@/content";
import { cn } from "@/lib/utils";
import { Button } from "./ui/button";

// TODO: point at real endpoint
const NOTIFY_ENDPOINT = "";

type State = "idle" | "failed" | "done";

/**
 * Pre-release CTA (§6): single inline email field, no modal. Wired to a
 * placeholder endpoint and fails gracefully — never fakes success.
 */
export function NotifyForm({
  id,
  subtext,
  className,
  center = false,
}: {
  id: string;
  subtext: string;
  className?: string;
  center?: boolean;
}) {
  const [email, setEmail] = useState("");
  const [state, setState] = useState<State>("idle");

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!NOTIFY_ENDPOINT) {
      // Placeholder build: no endpoint exists yet, say so honestly.
      setState("failed");
      return;
    }
    try {
      const res = await fetch(NOTIFY_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      setState(res.ok ? "done" : "failed");
    } catch {
      setState("failed");
    }
  }

  return (
    <div className={className}>
      {state === "done" ? (
        <p className="text-[15px] text-ink-100">{cta.notifySubtext}</p>
      ) : (
        <form
          onSubmit={onSubmit}
          className={cn(
            "flex flex-col gap-3 sm:flex-row",
            center && "sm:justify-center",
          )}
          noValidate={false}
        >
          <label htmlFor={id} className="sr-only">
            Email address
          </label>
          <input
            id={id}
            name="email"
            type="email"
            required
            autoComplete="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="h-12 w-full rounded-[11px] border border-panel-500 bg-midnight-800 px-4 text-[15px] text-ink-100 placeholder:text-ink-400/60 focus:border-recall-400 focus:outline-none sm:max-w-[300px]"
          />
          <Button type="submit" size="lg">
            {cta.notify}
          </Button>
        </form>
      )}
      <p
        className={cn(
          "mt-3 text-sm",
          state === "failed" ? "text-recall-400" : "text-ink-400",
        )}
        role={state === "failed" ? "alert" : undefined}
      >
        {state === "failed" ? (
          <>
            {cta.notifyFailure.split("hello@clippanel.app")[0]}
            <a
              href="mailto:hello@clippanel.app"
              className="underline underline-offset-2"
            >
              hello@clippanel.app
            </a>
            {cta.notifyFailure.split("hello@clippanel.app")[1]}
          </>
        ) : (
          subtext
        )}
      </p>
    </div>
  );
}
