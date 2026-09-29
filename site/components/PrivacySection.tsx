import { ShieldCheck } from "lucide-react";
import { links, privacy } from "@/content/site";
import { SectionHeading } from "@/components/SectionHeading";

export function PrivacySection() {
  return (
    <section id="privacy" className="scroll-mt-20 py-16 sm:py-24">
      <div className="mx-auto max-w-5xl px-4 sm:px-6">
        <SectionHeading
          eyebrow="Private by design"
          title="It reads your agents. So you can read it."
          body="NotchNull looks at your transcripts, your clipboard and your Claude login. That is exactly why it is open source."
        />
        <ul className="mt-12 grid gap-3 sm:grid-cols-2">
          {privacy.map((item) => (
            <li key={item.title} className="flex gap-4 rounded-2xl border border-hairline bg-surface p-5">
              <ShieldCheck className="mt-0.5 size-5 shrink-0 text-success" aria-hidden="true" strokeWidth={1.8} />
              <div>
                <h3 className="text-[16px] font-semibold tracking-tight">{item.title}</h3>
                <p className="mt-1.5 text-[15px] leading-relaxed text-muted">{item.body}</p>
              </div>
            </li>
          ))}
        </ul>
        <p className="mt-6 text-center text-[15px] text-muted">
          <a href={links.privacy} className="font-medium text-foreground underline decoration-white/25 underline-offset-4 hover:decoration-white/60">
            See every file it reads and writes
          </a>
        </p>
      </div>
    </section>
  );
}
