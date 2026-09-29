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

/**
 * The mark drawn in vector for small sizes, where the raster app icon turns into a dark blur:
 * the white null glyph on a black tile, like the notch itself.
 */
export function BrandMark({ size = 28 }: { size?: number }) {
  return (
    <span
      aria-hidden="true"
      style={{ width: size, height: size, borderRadius: size * 0.3 }}
      className="flex shrink-0 items-center justify-center border border-white/12 bg-black text-white shadow-[inset_0_1px_0_rgb(255_255_255/0.08)]"
    >
      <NullMark size={size * 0.56} />
    </span>
  );
}
