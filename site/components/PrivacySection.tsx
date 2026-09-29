import { ArrowUpRight } from "lucide-react";
import { links, privacy } from "@/content/site";
import { SectionHeading } from "@/components/SectionHeading";

export function PrivacySection() {
  return (
    <section id="privacy" className="scroll-mt-20 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          title="It reads your agents. So you can read it."
          body="NotchNull looks at your transcripts, your clipboard and your Claude login. That is exactly why it is open source."
        />
        <dl className="mt-14 grid gap-x-10 gap-y-8 sm:mt-20 sm:grid-cols-2 lg:grid-cols-4">
          {privacy.map((item) => (
            <div key={item.title} className="border-t border-hairline pt-5">
              <dt className="text-[17px] font-semibold tracking-[-0.01em]">{item.title}</dt>
              <dd className="mt-2 text-[15px] leading-relaxed text-muted">{item.body}</dd>
            </div>
          ))}
        </dl>
        <a
          href={links.privacy}
          className="group mt-10 inline-flex items-center gap-1.5 text-[15px] font-medium text-foreground underline decoration-white/25 underline-offset-4 transition-[text-decoration-color] duration-150 hover:decoration-white/70 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white/70"
        >
          See every file it reads and writes
          <ArrowUpRight className="size-4 text-muted transition-colors group-hover:text-foreground" aria-hidden="true" />
        </a>
      </div>
    </section>
  );
}
