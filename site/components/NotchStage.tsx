"use client";

import { useEffect, useState } from "react";
import { stageFrames } from "@/content/site";
import { Screen } from "@/components/Screen";

/**
 * Loops through real renders of the app hanging from the notch. Each frame condenses out of a
 * blur while the previous one dissolves, like the app's own transitions. With reduced motion
 * the loop stops on the Home panel.
 */
export function NotchStage() {
  const [index, setIndex] = useState(0);
  const [previous, setPrevious] = useState<number | null>(null);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const apply = () => {
      if (!query.matches) return;
      setPaused(true);
      setIndex(stageFrames.findIndex((frame) => frame.label === "Home"));
    };
    apply();
    query.addEventListener("change", apply);
    return () => query.removeEventListener("change", apply);
  }, []);

  useEffect(() => {
    if (paused) return;
    const timer = window.setTimeout(() => {
      setPrevious(index);
      setIndex((index + 1) % stageFrames.length);
    }, stageFrames[index].duration);
    return () => window.clearTimeout(timer);
  }, [index, paused]);

  const select = (next: number) => {
    if (next === index) return;
    setPrevious(index);
    setIndex(next);
  };

  const frame = stageFrames[index];
  const leaving = previous === null ? null : stageFrames[previous];

  return (
    <div className="flex w-full flex-col items-center">
      <Screen height="h-[260px] sm:h-[300px]">
      <div
        className="relative flex h-[260px] w-full justify-center sm:h-[300px]"
        onMouseEnter={() => setPaused(true)}
        onMouseLeave={() => setPaused(window.matchMedia("(prefers-reduced-motion: reduce)").matches)}
      >
        {leaving && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            key={`out-${previous}-${index}`}
            src={leaving.src}
            alt=""
            aria-hidden="true"
            style={{ width: leaving.width }}
            className="animate-dissolve absolute top-0 max-w-[calc(100%-12px)]"
          />
        )}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          key={`in-${index}`}
          src={frame.src}
          alt={`NotchNull: ${frame.label}`}
          style={{ width: frame.width }}
          className="animate-condense absolute top-0 max-w-[calc(100%-12px)]"
        />
      </div>
      </Screen>
      <StageControls index={index} onSelect={select} />
    </div>
  );
}

function StageControls({ index, onSelect }: { index: number; onSelect: (index: number) => void }) {
  return (
    <div className="mt-5 flex flex-wrap items-center justify-center gap-1.5 px-4" role="tablist" aria-label="Notch states">
      {stageFrames.map((frame, i) => {
        const active = i === index;
        return (
          <button
            key={frame.label}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onSelect(i)}
            className={`rounded-full px-3 py-1 text-[12px] font-medium transition-colors duration-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet ${
              active ? "bg-white/12 text-foreground" : "text-subtle hover:bg-white/6 hover:text-muted"
            }`}
          >
            {frame.label}
          </button>
        );
      })}
    </div>
  );
}
