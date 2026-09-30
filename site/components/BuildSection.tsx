import type { ReactNode } from "react";
import { buildLoop, buildSteps, platform } from "@/content/site";
import { CopyCommand } from "@/components/CopyCommand";
import { SectionHeading } from "@/components/SectionHeading";
import { Screen } from "@/components/Screen";
import { Shot } from "@/components/Shot";

/**
 * What NotchNull is for: the loop an agent runs to change the notch. What you ask, the file it
 * writes, and the render it checks, left to right, each over a hairline like the rest of the page.
 */
export function BuildSection() {
  return (
    <section id="build" className="scroll-mt-20 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          title="Ask for it. Your agent builds it."
          body="The notchnull skill teaches Claude Code and Codex the whole notch: widget files, settings.json, the CLI, and a render command, so the agent checks its own work before it tells you it is done."
        />

        <ol className="mt-14 grid grid-cols-[minmax(0,1fr)] gap-x-6 gap-y-12 sm:mt-20 lg:grid-cols-[minmax(0,1fr)_minmax(0,1.35fr)]">
          <LoopStep index={0}>
            <figure className="rounded-[16px] bg-surface p-6 shadow-[inset_0_1px_0_rgb(255_255_255/0.08),0_0_0_1px_rgb(255_255_255/0.06)]">
              <blockquote className="text-pretty text-[19px] font-medium leading-snug tracking-[-0.015em] text-foreground">
                “{buildLoop.prompt}”
              </blockquote>
              <figcaption className="mt-6 text-[13px] text-subtle">{buildLoop.promptSource}</figcaption>
            </figure>
          </LoopStep>

          <LoopStep index={1}>
            <div className="h-full overflow-clip rounded-[16px] bg-surface shadow-[inset_0_1px_0_rgb(255_255_255/0.08),0_0_0_1px_rgb(255_255_255/0.06)]">
              <p className="border-b border-hairline px-5 py-3 font-mono text-[12px] text-subtle">{buildLoop.file}</p>
              <pre className="overflow-x-auto px-5 py-4 font-mono text-[11.5px] leading-[1.7] sm:text-[12.5px] text-foreground/85">
                <code>{buildLoop.code}</code>
              </pre>
            </div>
          </LoopStep>

          <LoopStep index={2} wide aside={<CopyCommand command={buildLoop.check} />}>
            <Screen height="h-[190px] sm:h-[220px]">
              <div>
                <Shot src="/shots/ci-wing.png" width={346} height={44} alt="The CI wing beside the notch: a red seal and “1 failing”" />
              </div>
            </Screen>
          </LoopStep>
        </ol>

        <dl className="mt-20 grid gap-x-10 gap-y-8 sm:grid-cols-2 lg:grid-cols-3">
          {platform.map((item) => (
            <div key={item.title} className="border-t border-hairline pt-5">
              <dt className="text-[17px] font-semibold tracking-[-0.01em]">{item.title}</dt>
              <dd className="mt-2 text-[15px] leading-relaxed text-muted">{item.body}</dd>
            </div>
          ))}
        </dl>

        <div className="mt-16 grid gap-6 border-t border-hairline pt-8 lg:grid-cols-[1fr_1.2fr] lg:items-center lg:gap-16">
          <p className="max-w-md text-pretty text-[17px] leading-relaxed text-muted">
            <span className="font-semibold text-foreground">Start here.</span> Install the skill from Settings › Build, then paste this into your agent.
          </p>
          <CopyCommand command={buildLoop.starterPrompt} label="Copy prompt" wrap />
        </div>
      </div>
    </section>
  );
}

type LoopStepProps = {
  index: number;
  children: ReactNode;
  /** Spans the whole row, with its heading (and `aside`) beside the artifact on wide screens. */
  wide?: boolean;
  aside?: ReactNode;
};

function LoopStep({ index, children, wide = false, aside }: LoopStepProps) {
  const step = buildSteps[index];
  return (
    <li
      className={`rise-on-view flex flex-col border-t border-hairline pt-5 ${
        wide ? "lg:col-span-2 lg:grid lg:grid-cols-[minmax(0,1fr)_minmax(0,1.35fr)] lg:gap-x-6" : ""
      }`}
    >
      <div className="mb-5">
        <h3 className="text-[18px] font-semibold tracking-[-0.015em]">{step.title}</h3>
        <p className="mt-1.5 text-[15px] leading-relaxed text-muted">{step.body}</p>
        {aside && <div className="mt-5 max-w-md">{aside}</div>}
      </div>
      <div className="flex-1">{children}</div>
    </li>
  );
}
