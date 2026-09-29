type ShotProps = { src: string; width: number; alt: string; className?: string };

/** A real render of the app (exported at 2x), shown at its natural point size. */
export function Shot({ src, width, alt, className = "" }: ShotProps) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={src} alt={alt} loading="lazy" decoding="async" style={{ width }} className={`h-auto max-w-full ${className}`} />
  );
}
