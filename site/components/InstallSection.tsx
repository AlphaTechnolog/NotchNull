import { Download } from "lucide-react";
import { install, links } from "@/content/site";
import { CopyCommand } from "@/components/CopyCommand";
import { SectionHeading } from "@/components/SectionHeading";

export function InstallSection() {
  return (
    <section id="install" className="scroll-mt-20 py-16 sm:py-24">
      <div className="mx-auto max-w-2xl px-4 sm:px-6">
        <SectionHeading eyebrow="Install" title="Thirty seconds to a useful notch." />
        <ol className="mt-12 space-y-6">
          {install.steps.map((step, index) => (
            <li key={step} className="flex gap-4">
              <span className="grid size-7 shrink-0 place-items-center rounded-full border border-hairline bg-surface text-[13px] font-semibold tabular-nums text-muted">
                {index + 1}
              </span>
              <div className="min-w-0 flex-1 pt-0.5">
                <p className="text-[16px] leading-relaxed text-foreground/90">{step}</p>
                {index === 1 && (
                  <div className="mt-3">
                    <CopyCommand command={install.command} />
                  </div>
                )}
              </div>
            </li>
          ))}
        </ol>
        <div className="mt-12 flex flex-col items-center gap-3">
          <a
            href={links.download}
            className="flex h-12 items-center gap-2 rounded-full bg-foreground px-6 text-[15px] font-semibold text-background transition-transform active:scale-[0.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet"
          >
            <Download className="size-4" aria-hidden="true" />
            Download NotchNull
          </a>
          <p className="text-[13px] text-subtle">macOS 14 or later · Apple silicon and Intel · Free, GPL-3.0</p>
        </div>
      </div>
    </section>
  );
}
