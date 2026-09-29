import { Download } from "lucide-react";
import { hero, install, links } from "@/content/site";
import { CopyCommand } from "@/components/CopyCommand";

export function InstallSection() {
  return (
    <section id="install" className="scroll-mt-20 py-24 sm:py-32">
      <div className="mx-auto grid max-w-6xl gap-14 px-4 sm:px-6 lg:grid-cols-[1fr_1.1fr] lg:gap-20">
        <div>
          <h2 className="max-w-[12ch] text-balance text-[44px] font-semibold leading-[1] tracking-[-0.04em] sm:text-[72px]">
            Thirty seconds to a notch of your own.
          </h2>
          <a
            href={links.download}
            className="mt-10 inline-flex h-12 items-center gap-2 rounded-full bg-foreground px-6 text-[15px] font-semibold text-background transition-transform duration-150 ease-out active:scale-[0.96] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/70"
          >
            <Download className="size-4" aria-hidden="true" />
            Download NotchNull
          </a>
          <p className="mt-4 text-[13px] text-subtle">{hero.meta} · GPL-3.0</p>
        </div>
        <ol className="self-end">
          {install.steps.map((step, index) => (
            <li key={step} className="grid grid-cols-[2rem_1fr] gap-x-3 border-t border-hairline py-6 last:border-b">
              <span className="pt-0.5 font-mono text-[13px] tabular-nums text-subtle">{index + 1}</span>
              <div className="min-w-0">
                <p className="text-[17px] leading-relaxed text-foreground/90">{step}</p>
                {index === 1 && (
                  <div className="mt-4">
                    <CopyCommand command={install.command} />
                  </div>
                )}
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}
