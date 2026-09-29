import type { CSSProperties } from "react";
import { statement } from "@/content/site";

/** Why NotchNull exists, lit word by word as it scrolls through the viewport. */
export function Statement() {
  const words = statement.split(" ");
  const style = { "--word-step": `${40 / words.length}%` } as CSSProperties;
  return (
    <section aria-label="Why NotchNull" className="py-28 sm:py-40">
      <p
        style={style}
        className="statement mx-auto max-w-5xl px-4 text-[32px] font-semibold leading-[1.12] tracking-[-0.03em] text-pretty sm:px-6 sm:text-[52px]"
      >
        {words.map((word, index) => (
          <span key={index} className="statement-word" style={{ "--word": index } as CSSProperties}>
            {word}{" "}
          </span>
        ))}
      </p>
    </section>
  );
}
