"use client";

import { useState } from "react";
import { customization, panels } from "@/content/site";
import { Screen } from "@/components/Screen";
import { SectionHeading } from "@/components/SectionHeading";
import { Shot } from "@/components/Shot";

/** Hover the notch and it opens into a panel; this lets visitors flip through the tabs. */
export function PanelTabs() {
  const [active, setActive] = useState<(typeof panels)[number]["id"]>("home");
  const panel = panels.find((item) => item.id === active) ?? panels[0];

  return (
    <section id="panel" className="scroll-mt-20 py-16 sm:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <SectionHeading
          eyebrow="Hover to open"
          title="One panel. Everything you reach for."
          body="Home, your agents, Control Center, a file tray and clipboard history — and you decide how it looks."
        />
        <div className="mt-10 flex justify-center">
          <div className="flex gap-1 rounded-full border border-hairline bg-surface p-1" role="tablist" aria-label="Panel tabs">
            {panels.map((item) => {
              const selected = item.id === active;
              return (
                <button
                  key={item.id}
                  type="button"
                  role="tab"
                  aria-selected={selected}
                  onClick={() => setActive(item.id)}
                  className={`rounded-full px-3.5 py-1.5 text-[13px] font-medium transition-colors duration-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/70 sm:px-4 ${
                    selected ? "bg-white/12 text-foreground" : "text-subtle hover:text-muted"
                  }`}
                >
                  {item.label}
                </button>
              );
            })}
          </div>
        </div>
        <div className="mt-8">
          <Screen height="h-[280px] sm:h-[300px]">
            <div key={panel.id} className="animate-condense">
              <Shot src={panel.src} width={panel.width} alt={`The ${panel.label} tab of the NotchNull panel`} />
            </div>
          </Screen>
        </div>
        <ul className="mx-auto mt-10 flex max-w-3xl flex-wrap justify-center gap-2" aria-label="What you can customize">
          {customization.map((item) => (
            <li key={item} className="rounded-full border border-hairline bg-surface px-3.5 py-1.5 text-[13px] text-muted">
              {item}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
