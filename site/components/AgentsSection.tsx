import { agentFeatures } from "@/content/site";
import { SectionHeading } from "@/components/SectionHeading";
import { Shot } from "@/components/Shot";
import { Screen } from "@/components/Screen";

/** Built in, apart from building: Claude Code and Codex at a glance while they work. */
export function AgentsSection() {
  return (
    <section id="agents" className="scroll-mt-20 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          title="It also watches your agents."
          body="Built in, before you change a thing: Claude Code and Codex limits at a glance, an alert the second Claude needs you, and the final message when a turn ends."
        />
        <div className="rise-on-view mt-14 sm:mt-20">
          <Screen height="h-[300px] sm:h-[340px]">
            <Shot src="/shots/agents.png" width={593} height={235} alt="The Agents tab: Claude Code and Codex limits as percent left, with live sessions" />
          </Screen>
        </div>
        <dl className="mt-12 grid gap-x-10 gap-y-8 sm:grid-cols-2 lg:grid-cols-4">
          {agentFeatures.map((feature) => (
            <div key={feature.title} className="border-t border-hairline pt-5">
              <dt className="text-[17px] font-semibold tracking-[-0.01em]">{feature.title}</dt>
              <dd className="mt-2 text-[15px] leading-relaxed text-muted">{feature.body}</dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}
