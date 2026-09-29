"use client";

import { useEffect, useRef, useState, type CSSProperties } from "react";
import { Download, Hammer } from "lucide-react";
import { hero, heroSteps, links } from "@/content/site";
import { Screen } from "@/components/Screen";

/** Share of the pinned scroll spent moving the headline away before the steps begin. */
const INTRO_END = 0.14;
/** Scroll distance per step, in viewport heights. */
const STEP_SCROLL_VH = 62;

const clamp = (value: number) => Math.min(1, Math.max(0, value));

function stepAt(progress: number) {
  const local = clamp((progress - INTRO_END) / (1 - INTRO_END));
  return Math.min(heroSteps.length - 1, Math.floor(local * heroSteps.length));
}

function usePrefersReducedMotion() {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const apply = () => setReduced(query.matches);
    apply();
    query.addEventListener("change", apply);
    return () => query.removeEventListener("change", apply);
  }, []);
  return reduced;
}

/**
 * The first viewport is the product: the headline scrolls away, the screen rises into place and the
 * notch walks through its real states while the section is pinned. With reduced motion nothing is
 * pinned and the steps become plain buttons.
 */
export function Hero() {
  const reduced = usePrefersReducedMotion();
  const sectionRef = useRef<HTMLElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const headlineRef = useRef<HTMLDivElement>(null);
  const screenSlotRef = useRef<HTMLDivElement>(null);
  const stepRef = useRef(0);
  const [step, setStep] = useState(0);
  const [previous, setPrevious] = useState<number | null>(null);

  const show = (next: number) => {
    if (next === stepRef.current) return;
    setPrevious(stepRef.current);
    stepRef.current = next;
    setStep(next);
  };

  useEffect(() => {
    const section = sectionRef.current;
    const stage = stageRef.current;
    const headline = headlineRef.current;
    const screenSlot = screenSlotRef.current;
    if (reduced || !section || !stage || !headline || !screenSlot) return;

    const measure = () => {
      // How far the screen starts below its pinned position so it peeks under the headline.
      const headlineBottom = headline.offsetTop + headline.offsetHeight;
      const offset = Math.max(0, headlineBottom + 40 - screenSlot.offsetTop);
      stage.style.setProperty("--rise", `${offset}px`);
    };
    // Scroll events already arrive once per frame, so the update runs directly in the handler.
    const update = () => {
      const travel = section.offsetHeight - window.innerHeight;
      const progress = travel > 0 ? clamp(-section.getBoundingClientRect().top / travel) : 0;
      const intro = clamp(progress / INTRO_END);
      const local = clamp((progress - INTRO_END) / (1 - INTRO_END)) * heroSteps.length;
      stage.style.setProperty("--intro", intro.toFixed(4));
      stage.style.setProperty("--step-fill", clamp(local - Math.floor(local)).toFixed(4));
      headline.inert = intro > 0.6;
      show(stepAt(progress));
    };
    const resize = () => {
      measure();
      update();
    };

    measure();
    update();
    window.addEventListener("scroll", update, { passive: true });
    window.addEventListener("resize", resize);
    return () => {
      window.removeEventListener("scroll", update);
      window.removeEventListener("resize", resize);
    };
  }, [reduced]);

  const jumpTo = (index: number) => {
    const section = sectionRef.current;
    if (reduced || !section) {
      show(index);
      return;
    }
    const travel = section.offsetHeight - window.innerHeight;
    const target = INTRO_END + ((index + 0.5) / heroSteps.length) * (1 - INTRO_END);
    window.scrollTo({ top: section.offsetTop + travel * target, behavior: "smooth" });
  };

  const pinned = !reduced;
  const sectionStyle: CSSProperties | undefined = pinned
    ? { height: `calc(100dvh + ${heroSteps.length * STEP_SCROLL_VH}dvh)` }
    : undefined;

  return (
    <section id="top" ref={sectionRef} style={sectionStyle} className="relative">
      <div
        ref={stageRef}
        className={pinned ? "sticky top-0 h-dvh overflow-hidden [--intro:0] [--rise:0px] [--step-fill:0]" : "pt-28 pb-20"}
      >
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-x-0 top-0 h-[70dvh] bg-[radial-gradient(50%_60%_at_50%_0%,rgb(255_255_255/0.09),transparent)]"
        />

        <div
          ref={headlineRef}
          style={
            pinned
              ? {
                  opacity: "calc(1 - var(--intro) * 1.6)",
                  transform: "translateY(calc(var(--intro) * -56px))",
                  filter: "blur(calc(var(--intro) * 10px))",
                }
              : undefined
          }
          className={`${pinned ? "absolute inset-x-0 top-0 pt-[max(96px,14dvh)]" : "relative"} mx-auto max-w-5xl px-4 text-center sm:px-6`}
        >
          <h1 className="text-balance text-[48px] font-semibold leading-[0.98] tracking-[-0.04em] sm:text-[72px] lg:text-[92px]">
            {hero.title} <span className="text-white/40 sm:block">{hero.titleMuted}</span>
          </h1>
          <p className="mx-auto mt-6 max-w-xl text-pretty text-[17px] leading-relaxed text-muted sm:text-[19px]">{hero.subtitle}</p>
          <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <a
              href={links.download}
              className="flex h-12 items-center gap-2 rounded-full bg-foreground px-6 text-[15px] font-semibold text-background transition-transform duration-150 ease-out active:scale-[0.96] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/70"
            >
              <Download className="size-4" aria-hidden="true" />
              Download for macOS
            </a>
            <a
              href="#build"
              className="flex h-12 items-center gap-2 rounded-full border border-white/15 px-6 text-[15px] font-medium text-foreground transition-[background-color,transform] duration-150 ease-out hover:bg-white/6 active:scale-[0.96] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/70"
            >
              <Hammer className="size-4" aria-hidden="true" />
              See how it builds
            </a>
          </div>
          <p className="mt-5 text-balance text-[13px] text-subtle">{hero.meta}</p>
        </div>

        <div
          ref={screenSlotRef}
          style={
            pinned
              ? {
                  transform: "translateY(calc((1 - var(--intro)) * var(--rise))) scale(calc(0.94 + var(--intro) * 0.06))",
                }
              : undefined
          }
          className={`${pinned ? "absolute inset-x-0 top-[max(76px,calc(50dvh-300px))]" : "relative mt-16"} mx-auto flex max-w-[1120px] origin-top flex-col items-center px-3 sm:px-6`}
        >
          <Screen height="h-[300px] sm:h-[min(38dvh,360px)] sm:min-h-[310px]">
            <StageFrames step={step} previous={previous} />
          </Screen>
          <StepCaption step={step} />
          <StepNav step={step} onSelect={jumpTo} pinned={pinned} />
        </div>
      </div>
    </section>
  );
}

function StageFrames({ step, previous }: { step: number; previous: number | null }) {
  const frame = heroSteps[step];
  const leaving = previous === null ? null : heroSteps[previous];
  return (
    <div className="relative flex h-full w-full justify-center [--shot-scale:1] lg:[--shot-scale:1.15]">
      {leaving && (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          key={`out-${previous}-${step}`}
          src={leaving.src}
          width={leaving.width}
          height={leaving.height}
          alt=""
          aria-hidden="true"
          style={{ width: `calc(${leaving.width}px * var(--shot-scale))` }}
          className="animate-dissolve absolute top-0 h-auto max-w-[calc(100%-12px)]"
        />
      )}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        key={`in-${step}`}
        src={frame.src}
        width={frame.width}
        height={frame.height}
        alt={`NotchNull: ${frame.body}`}
        style={{ width: `calc(${frame.width}px * var(--shot-scale))` }}
        className="animate-condense absolute top-0 h-auto max-w-[calc(100%-12px)]"
      />
    </div>
  );
}

function StepCaption({ step }: { step: number }) {
  const frame = heroSteps[step];
  return (
    <div className="mt-7 min-h-[92px] max-w-xl px-2 text-center" aria-live="polite">
      <div key={step} className="animate-condense">
        <p className="text-balance text-[22px] font-semibold tracking-[-0.02em] sm:text-[26px]">
          “{frame.prompt}”
        </p>
        <p className="mt-2 text-pretty text-[15px] leading-relaxed text-muted sm:text-[16px]">{frame.body}</p>
      </div>
    </div>
  );
}

function StepNav({ step, onSelect, pinned }: { step: number; onSelect: (index: number) => void; pinned: boolean }) {
  return (
    <nav aria-label="Notch states" className="mt-5 w-full max-w-2xl">
      <ol className="grid gap-2 sm:gap-3" style={{ gridTemplateColumns: `repeat(${heroSteps.length}, minmax(0, 1fr))` }}>
        {heroSteps.map((frame, index) => {
          const done = index < step;
          const current = index === step;
          return (
            <li key={frame.label}>
              <button
                type="button"
                onClick={() => onSelect(index)}
                aria-current={current ? "step" : undefined}
                className="group w-full rounded-md pt-2 text-left focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white/70"
              >
                <span className="relative block h-[2px] overflow-hidden rounded-full bg-white/12">
                  <span
                    className="absolute inset-0 origin-left bg-foreground"
                    style={{
                      transform: done
                        ? "scaleX(1)"
                        : current
                          ? pinned
                            ? "scaleX(var(--step-fill))"
                            : "scaleX(1)"
                          : "scaleX(0)",
                    }}
                  />
                </span>
                <span
                  className={`mt-2 block truncate text-[12px] font-medium transition-colors duration-150 sm:text-[13px] ${
                    current ? "text-foreground" : "text-subtle group-hover:text-muted"
                  }`}
                >
                  {frame.label}
                </span>
              </button>
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
