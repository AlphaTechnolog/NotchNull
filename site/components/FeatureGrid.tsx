import { features } from "@/content/site";
import { Icon } from "@/components/Icon";
import { SectionHeading } from "@/components/SectionHeading";
import { Shot } from "@/components/Shot";

/** Everything else the notch does, each with a real render of its wing or panel. */
export function FeatureGrid() {
  return (
    <section id="features" className="scroll-mt-20 py-16 sm:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          eyebrow="Everything else"
          title="Things slide out of the notch, then tuck back in."
          body="Every activity is the same black surface morphing out of the hardware. Nothing pops; everything condenses into place."
        />
        <ul className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature) => (
            <li
              key={feature.title}
              className="group flex flex-col overflow-hidden rounded-3xl border border-hairline bg-surface transition-colors duration-300 hover:border-white/15"
            >
              {feature.shot && (
                <div className="flex h-[128px] items-start justify-center overflow-hidden bg-[url(/brand/wallpaper.jpg)] bg-cover bg-[center_top] px-2">
                  <Shot
                    src={feature.shot.src}
                    width={feature.shot.width * 0.82}
                    alt={`${feature.title} in the notch`}
                    className="transition-transform duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:scale-[1.03] origin-top"
                  />
                </div>
              )}
              <div className="p-5">
                <div className="flex items-center gap-2.5">
                  <Icon name={feature.icon} className="size-[18px] text-violet" />
                  <h3 className="text-[16px] font-semibold tracking-tight">{feature.title}</h3>
                </div>
                <p className="mt-2 text-[15px] leading-relaxed text-muted">{feature.body}</p>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
