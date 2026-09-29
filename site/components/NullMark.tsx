type NullMarkProps = { size?: number; className?: string };

/** The NotchNull mark: a ring crossed by a slash, matching the app icon. */
export function NullMark({ size = 20, className }: NullMarkProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true" className={className}>
      <circle cx="12" cy="12" r="6.7" stroke="currentColor" strokeWidth="2.4" />
      <path d="M4.4 19.6 19.6 4.4" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
    </svg>
  );
}

const BRAND_GRADIENT_ID = "notchnull-brand-gradient";

/**
 * The mark drawn in vector for small sizes, where the raster app icon turns into a dark blur:
 * the null glyph in the brand gradient on a black tile.
 */
export function BrandMark({ size = 28 }: { size?: number }) {
  return (
    <span
      aria-hidden="true"
      style={{ width: size, height: size, borderRadius: size * 0.3 }}
      className="flex shrink-0 items-center justify-center border border-white/12 bg-black shadow-[inset_0_1px_0_rgb(255_255_255/0.08)]"
    >
      <svg width={size * 0.6} height={size * 0.6} viewBox="0 0 24 24" fill="none">
        <defs>
          <linearGradient id={BRAND_GRADIENT_ID} x1="3" y1="21" x2="21" y2="3" gradientUnits="userSpaceOnUse">
            <stop stopColor="var(--pink)" />
            <stop offset="0.55" stopColor="var(--violet)" />
            <stop offset="1" stopColor="var(--cyan)" />
          </linearGradient>
        </defs>
        <circle cx="12" cy="12" r="6.7" stroke={`url(#${BRAND_GRADIENT_ID})`} strokeWidth="2.6" />
        <path d="M4.4 19.6 19.6 4.4" stroke={`url(#${BRAND_GRADIENT_ID})`} strokeWidth="2.6" strokeLinecap="round" />
      </svg>
    </span>
  );
}
