import { agentFeatures } from "@/content/site";
import { Icon } from "@/components/Icon";
import { SectionHeading } from "@/components/SectionHeading";
import { Shot } from "@/components/Shot";
import { Screen } from "@/components/Screen";

/** The reason NotchNull exists: Claude Code and Codex, at a glance. */
export function AgentsSection() {
  return (
    <section id="agents" className="scroll-mt-20 py-16 sm:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          eyebrow="Built for Claude Code and Codex"
          title="Know what your agents are doing without leaving your work."
          body="Limits you can read at a glance, an alert the second Claude needs you, and the final message when a turn ends."
        />
        <div className="mx-auto mt-12 max-w-5xl">
          <Screen height="h-[270px] sm:h-[300px]">
            <Shot src="/shots/agents.png" width={593} alt="The Agents tab: Claude Code and Codex limits as percent left, with live sessions" />
          </Screen>
          <ul className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {agentFeatures.map((feature) => (
              <li key={feature.title} className="rounded-2xl border border-hairline bg-surface p-5">
                <div className="flex items-center gap-3">
                  <span className="grid size-9 place-items-center rounded-xl bg-white/6 text-claude">
                    <Icon name={feature.icon} className="size-[18px]" />
                  </span>
                  <h3 className="text-[16px] font-semibold tracking-tight">{feature.title}</h3>
                </div>
                <p className="mt-2.5 text-[15px] leading-relaxed text-muted">{feature.body}</p>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </section>
  );
}
