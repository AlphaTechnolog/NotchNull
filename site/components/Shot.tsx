type ShotProps = {
  src: string;
  width: number;
  height: number;
  alt: string;
  className?: string;
  loading?: "lazy" | "eager";
};

/**
 * A real render of the app (exported at 2x), shown at the given point size. The intrinsic size keeps
 * its box in place before it loads, so lazy loading can see it and nothing shifts when it arrives.
 */
export function Shot({ src, width, height, alt, className = "", loading = "lazy" }: ShotProps) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={src}
      alt={alt}
      width={Math.round(width)}
      height={Math.round(height)}
      loading={loading}
      decoding="async"
      style={{ width }}
      className={`h-auto max-w-full ${className}`}
    />
  );
}
