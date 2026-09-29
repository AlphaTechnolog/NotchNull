type SectionHeadingProps = { eyebrow: string; title: string; body?: string };

export function SectionHeading({ eyebrow, title, body }: SectionHeadingProps) {
  return (
    <div className="mx-auto max-w-2xl text-center">
      <p className="text-[13px] font-semibold uppercase tracking-[0.14em] text-violet">{eyebrow}</p>
      <h2 className="mt-3 text-balance text-[32px] font-semibold leading-[1.08] tracking-[-0.03em] sm:text-[44px]">{title}</h2>
      {body && <p className="mt-4 text-pretty text-[17px] leading-relaxed text-muted">{body}</p>}
    </div>
  );
}
