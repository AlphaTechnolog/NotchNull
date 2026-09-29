import { features } from "@/content/site";
import { SectionHeading } from "@/components/SectionHeading";
import { Shot } from "@/components/Shot";

/** Share of each render's natural size used in the gallery strips. */
const STRIP_SCALE = 0.8;

/**
 * Every ambient activity, each hanging from the top edge of its own sliver of screen. As a strip
 * scrolls into view its activity slides out of that edge, the way it leaves the notch. The strip
 * clips with `overflow: clip` because `hidden` would make it the scroll container the animation's
 * view timeline tracks, freezing it.
 */
export function FeatureGrid() {
  return (
    <section id="features" className="scroll-mt-20 py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <SectionHeading
          title="Things slide out of the notch, then tuck back in."
          body="Every activity is the same black surface morphing out of the hardware. Nothing pops; everything condenses into place."
        />
        <ul className="mt-14 grid gap-x-6 gap-y-12 sm:mt-20 sm:grid-cols-2 lg:grid-cols-3">
          {features.map((feature) => (
            <li key={feature.title} className="group">
              {feature.shot && (
                <div className="relative flex h-[164px] justify-center overflow-clip rounded-[18px] bg-[url(/brand/wallpaper.jpg)] bg-cover bg-[center_top] shadow-[inset_0_1px_0_rgb(255_255_255/0.12),0_0_0_1px_rgb(255_255_255/0.06)] [mask-image:linear-gradient(to_bottom,black_78%,transparent)]">
                  <div className="slide-out-of-notch">
                    <Shot
                      src={feature.shot.src}
                      width={feature.shot.width * STRIP_SCALE}
                      height={feature.shot.height * STRIP_SCALE}
                      alt={`${feature.title} in the notch`}
                      // Each render starts clipped at its strip's top edge, where lazy loading never sees it.
                      loading="eager"
                      className="origin-top transition-transform duration-300 ease-out-strong group-hover:scale-[1.04]"
                    />
                  </div>
                </div>
              )}
              <h3 className="mt-5 text-[18px] font-semibold tracking-[-0.015em]">{feature.title}</h3>
              <p className="mt-1.5 text-[15px] leading-relaxed text-muted">{feature.body}</p>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
