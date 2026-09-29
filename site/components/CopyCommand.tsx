"use client";

import { Check, Copy } from "lucide-react";
import { useState } from "react";

/** A shell command with a copy button that confirms in place. */
export function CopyCommand({ command }: { command: string }) {
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(command);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1600);
    } catch {
      setCopied(false);
    }
  };

  return (
    <div className="flex items-center gap-2 rounded-xl border border-hairline bg-black/60 py-1.5 pl-4 pr-1.5">
      <code className="min-w-0 flex-1 overflow-x-auto whitespace-nowrap font-mono text-[13px] text-foreground/90">{command}</code>
      <button
        type="button"
        onClick={copy}
        aria-label={copied ? "Copied" : "Copy command"}
        className="grid size-9 shrink-0 place-items-center rounded-lg text-muted transition-colors hover:bg-white/8 hover:text-foreground focus-visible:outline-2 focus-visible:outline-white/70"
      >
        {copied ? <Check className="size-4 text-success" aria-hidden="true" /> : <Copy className="size-4" aria-hidden="true" />}
      </button>
    </div>
  );
}
