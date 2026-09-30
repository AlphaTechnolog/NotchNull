import { ArrowUpRight } from "lucide-react";
import { changeables, presets, shapes, starters } from "@/content/site";
import { SectionHeading } from "@/components/SectionHeading";
import { Screen } from "@/components/Screen";
import { Shot } from "@/components/Shot";

/**
 * Where you start and how far you can go: the three Setup presets as real renders, every part of
 * the notch an agent can change with a prompt for each, and the files that ship to start from.
 */
export function YoursSection() {
  return (
    <section id="yours" className="scroll-mt-20 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          title="Start with a preset. Change everything else."
          body="Setup opens the first time you launch NotchNull: classic notch or floating island, Minimal, Balanced or Complete, and one of twelve looks. None of it is fixed. Each one is a file, and after you pick, your agent can change anything."
        />

        <ul className="mt-14 grid grid-cols-[minmax(0,1fr)] gap-x-6 gap-y-12 sm:mt-20 md:grid-cols-2">
          {shapes.map((shape) => (
            <li key={shape.id} className="rise-on-view flex flex-col">
              <Screen shortMenu height="h-[100px] sm:h-[116px]">
                <div className={shape.top}>
                  <Shot src={shape.src} width={shape.width} height={shape.height} alt={`${shape.name}: ${shape.body}`} />
                </div>
              </Screen>
              <div className="border-t border-hairline pt-5">
                <h3 className="text-[18px] font-semibold tracking-[-0.015em]">{shape.name}</h3>
                <p className="mt-1.5 text-pretty text-[15px] leading-relaxed text-muted">{shape.body}</p>
              </div>
            </li>
          ))}
        </ul>

        <ol className="mt-16 grid grid-cols-[minmax(0,1fr)] gap-x-6 gap-y-12 lg:grid-cols-3">
          {presets.map((preset) => (
            <li key={preset.id} className="rise-on-view flex flex-col">
              <Screen bare height="h-[150px] sm:h-[190px] lg:h-[170px]">
                <div className="px-2">
                  <Shot
                    src={preset.src}
                    width={preset.width}
                    height={preset.height}
                    alt={`The ${preset.name} preset: ${preset.body}`}
                  />
                </div>
              </Screen>
              <div className="border-t border-hairline pt-5">
                <h3 className="text-[18px] font-semibold tracking-[-0.015em]">{preset.name}</h3>
                <p className="mt-1.5 text-pretty text-[15px] leading-relaxed text-muted">{preset.body}</p>
              </div>
            </li>
          ))}
        </ol>

        <h3 className="mt-24 max-w-[22ch] text-balance text-[28px] font-semibold leading-[1.1] tracking-[-0.03em] sm:text-[36px]">
          Then ask for anything. Your agent can change all of it.
        </h3>
        <dl className="mt-10 grid gap-x-10 gap-y-9 sm:grid-cols-2 lg:grid-cols-4">
          {changeables.map((item) => (
            <div key={item.title} className="border-t border-hairline pt-5">
              <dt className="text-[13px] font-medium text-subtle">{item.title}</dt>
              <dd className="mt-2">
                <p className="text-pretty text-[17px] font-medium leading-snug tracking-[-0.01em] text-foreground">“{item.prompt}”</p>
                <p className="mt-2 text-pretty text-[14px] leading-relaxed text-muted">{item.body}</p>
              </dd>
            </div>
          ))}
        </dl>

        <div className="mt-24 grid gap-10 border-t border-hairline pt-8 lg:grid-cols-[1fr_1.4fr] lg:gap-16">
          <div>
            <h3 className="text-balance text-[28px] font-semibold leading-[1.1] tracking-[-0.03em] sm:text-[36px]">An example of everything.</h3>
            <p className="mt-4 max-w-md text-pretty text-[17px] leading-relaxed text-muted">
              The skill ships in the repo and inside the app. In Settings, Setup applies the presets and looks, and Build › Examples adds a widget in one click, as a file you can change.
            </p>
          </div>
          <ul className="divide-y divide-hairline">
            {starters.map((starter) => (
              <li key={starter.path}>
                <a
                  href={starter.href}
                  className="group grid grid-cols-[minmax(0,1fr)_auto] items-baseline gap-x-4 gap-y-1 py-4 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white/70 sm:grid-cols-[9rem_minmax(0,1fr)_auto]"
                >
                  <span className="font-mono text-[13px] text-foreground">{starter.path}</span>
                  <span className="col-span-2 row-start-2 text-pretty text-[15px] leading-relaxed text-muted sm:col-span-1 sm:row-start-auto">
                    {starter.body}
                  </span>
                  <ArrowUpRight
                    className="col-start-2 row-start-1 size-4 text-subtle transition-[color,transform] duration-150 ease-out group-hover:-translate-y-0.5 group-hover:translate-x-0.5 group-hover:text-foreground sm:col-start-3"
                    aria-hidden="true"
                  />
                </a>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
