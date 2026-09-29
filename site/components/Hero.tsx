import { Download, Star } from "lucide-react";
import { hero, links } from "@/content/site";
import { NotchStage } from "@/components/NotchStage";

export function Hero() {
  return (
    <section id="top" className="relative overflow-hidden pt-30 sm:pt-38">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-x-0 top-0 -z-10 h-[520px] bg-[radial-gradient(60%_60%_at_50%_0%,rgb(255_255_255/0.07),transparent)]"
      />
      <div className="mx-auto max-w-3xl px-4 text-center sm:px-6">
        <p className="text-[13px] font-medium tracking-wide text-muted">{hero.eyebrow}</p>
        <h1 className="mt-4 text-balance text-[44px] font-semibold leading-[1.02] tracking-[-0.035em] sm:text-[72px]">
          Your notch, <span className="text-white/45">made useful.</span>
        </h1>
        <p className="mx-auto mt-5 max-w-xl text-pretty text-[17px] leading-relaxed text-muted sm:text-[19px]">
          {hero.subtitle}
        </p>
        <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <a
            href={links.download}
            className="flex h-12 items-center gap-2 rounded-full bg-foreground px-6 text-[15px] font-semibold text-background shadow-[0_8px_30px_-6px_rgb(255_255_255/0.35)] transition-transform active:scale-[0.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/70"
          >
            <Download className="size-4" aria-hidden="true" />
            Download for macOS
          </a>
          <a
            href={links.repo}
            className="flex h-12 items-center gap-2 rounded-full border border-white/12 px-6 text-[15px] font-medium text-foreground transition-colors hover:bg-white/5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/70"
          >
            <Star className="size-4" aria-hidden="true" />
            Star on GitHub
          </a>
        </div>
      </div>
      <div className="mx-auto mt-14 max-w-5xl px-2 sm:mt-16 sm:px-6">
        <NotchStage />
      </div>
    </section>
  );
}
