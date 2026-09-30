"use client";

import { useLayoutEffect, useRef, useState } from "react";
import { customization, panels } from "@/content/site";
import { Screen } from "@/components/Screen";
import { SectionHeading } from "@/components/SectionHeading";
import { Shot } from "@/components/Shot";

type PanelId = (typeof panels)[number]["id"];

/** Hover the notch and it opens into a panel; this lets visitors flip through the tabs. */
export function PanelTabs() {
  const [active, setActive] = useState<PanelId>("home");
  const panel = panels.find((item) => item.id === active) ?? panels[0];

  return (
    <section id="panel" className="scroll-mt-20 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          title="One panel. Everything you reach for."
          body="Hover the notch and it opens: Home, your agents, Control Center, your widgets, downloads counting down, a file tray and clipboard history."
        />
        {/* On narrow screens the tabs scroll sideways instead of clipping at both edges. */}
        <div className="-mx-4 mt-14 overflow-x-auto px-4 [scrollbar-width:none] sm:mx-0 sm:mt-20 sm:px-0">
          <div className="mx-auto w-max">
            <SegmentedTabs active={active} onSelect={setActive} />
          </div>
        </div>
        <div className="mt-8">
          <Screen height="h-[300px] sm:h-[340px]">
            <div key={panel.id} className="animate-condense">
              <Shot src={panel.src} width={panel.width} height={panel.height} alt={`The ${panel.label} tab of the NotchNull panel`} />
            </div>
          </Screen>
        </div>
        <p className="mx-auto mt-10 max-w-3xl text-pretty text-center text-[16px] leading-relaxed text-muted">
          <span className="font-semibold text-foreground">Make it yours:</span> {customization.join(", ")}.
        </p>
      </div>
    </section>
  );
}

/** Tabs with a white thumb that slides to the selected tab instead of each tab repainting on its own. */
function SegmentedTabs({ active, onSelect }: { active: PanelId; onSelect: (id: PanelId) => void }) {
  const listRef = useRef<HTMLDivElement>(null);
  const [thumb, setThumb] = useState<{ left: number; width: number } | null>(null);

  useLayoutEffect(() => {
    const place = () => {
      const button = listRef.current?.querySelector<HTMLButtonElement>(`[data-tab="${active}"]`);
      if (button) setThumb({ left: button.offsetLeft, width: button.offsetWidth });
    };
    place();
    window.addEventListener("resize", place);
    return () => window.removeEventListener("resize", place);
  }, [active]);

  return (
    <div ref={listRef} role="tablist" aria-label="Panel tabs" className="relative flex rounded-full bg-white/[0.07] p-1">
      {thumb && (
        <span
          aria-hidden="true"
          className="absolute top-1 bottom-1 rounded-full bg-foreground transition-[translate,width] duration-300 ease-out-strong motion-reduce:transition-none"
          style={{ translate: `${thumb.left}px 0`, width: thumb.width, left: 0 }}
        />
      )}
      {panels.map((item) => {
        const selected = item.id === active;
        return (
          <button
            key={item.id}
            data-tab={item.id}
            type="button"
            role="tab"
            aria-selected={selected}
            onClick={() => onSelect(item.id)}
            className={`relative z-10 rounded-full px-3.5 py-2 text-[13px] font-medium transition-colors duration-150 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/70 sm:px-5 sm:text-[14px] ${
              selected ? "text-background" : "text-muted hover:text-foreground"
            }`}
          >
            {item.label}
          </button>
        );
      })}
    </div>
  );
}
