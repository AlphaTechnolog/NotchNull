type SectionHeadingProps = { title: string; body?: string };

/** A large left-set title with its explanation on the right, sharing a baseline on wide screens. */
export function SectionHeading({ title, body }: SectionHeadingProps) {
  return (
    <div className="grid gap-5 lg:grid-cols-[1.25fr_1fr] lg:items-end lg:gap-16">
      <h2 className="max-w-[16ch] text-balance text-[38px] font-semibold leading-[1.02] tracking-[-0.035em] sm:text-[56px]">{title}</h2>
      {body && <p className="max-w-md text-pretty text-[17px] leading-relaxed text-muted sm:text-[18px] lg:pb-2">{body}</p>}
    </div>
  );
}
