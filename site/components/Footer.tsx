import { ArrowUpRight, CodeXml, Download } from "lucide-react";
import { footer, links } from "@/content/site";
import { BrandMark, NullMark } from "@/components/NullMark";

function FooterLink({ label, href }: { label: string; href: string }) {
  const external = href.startsWith("http");
  return (
    <a
      href={href}
      className="group inline-flex items-center gap-1 text-[14px] text-muted transition-colors hover:text-foreground focus-visible:outline-2 focus-visible:outline-violet"
    >
      {label}
      {external && (
        <ArrowUpRight
          className="size-3.5 opacity-0 transition-opacity duration-200 group-hover:opacity-60"
          aria-hidden="true"
        />
      )}
    </a>
  );
}

export function Footer() {
  return (
    <footer className="relative mt-8 border-t border-hairline">
      {/* A small notch hanging from the footer's top edge, echoing the header. */}
      <div
        aria-hidden="true"
        className="absolute top-0 left-1/2 flex h-7 w-36 -translate-x-1/2 items-center justify-center rounded-b-[16px] border-x border-b border-white/10 bg-black"
      >
        <NullMark size={13} className="text-white/70" />
      </div>

      <div className="mx-auto grid max-w-6xl grid-cols-2 gap-x-6 gap-y-10 px-4 pt-20 pb-14 sm:px-6 md:grid-cols-[1.6fr_repeat(3,1fr)]">
        <div className="col-span-2 flex flex-col items-start gap-4 md:col-span-1">
          <a
            href="#top"
            className="flex items-center gap-2.5 rounded-lg text-[17px] font-semibold tracking-tight focus-visible:outline-2 focus-visible:outline-violet"
          >
            <BrandMark size={34} />
            NotchNull
          </a>
          <p className="max-w-[30ch] text-[14px] leading-relaxed text-muted">{footer.tagline}</p>
          <div className="mt-1 flex items-center gap-2">
            <a
              href={links.download}
              className="flex h-9 items-center gap-1.5 rounded-full bg-foreground px-4 text-[13px] font-semibold text-background transition-transform active:scale-[0.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet"
            >
              <Download className="size-3.5" aria-hidden="true" />
              Download
            </a>
            <a
              href={links.repo}
              className="flex h-9 items-center gap-1.5 rounded-full border border-hairline px-4 text-[13px] font-medium text-muted transition-colors hover:border-white/20 hover:text-foreground focus-visible:outline-2 focus-visible:outline-violet"
            >
              <CodeXml className="size-3.5" aria-hidden="true" />
              Source
            </a>
          </div>
        </div>

        {footer.columns.map((column) => (
          <nav key={column.title} aria-label={column.title}>
            <h2 className="text-[11px] font-semibold tracking-[0.12em] text-subtle uppercase">{column.title}</h2>
            <ul className="mt-4 flex flex-col gap-2.5">
              {column.links.map((link) => (
                <li key={link.label}>
                  <FooterLink {...link} />
                </li>
              ))}
            </ul>
          </nav>
        ))}
      </div>

      <div className="border-t border-hairline">
        <div className="mx-auto flex max-w-6xl flex-col gap-3 px-4 py-6 text-[12px] leading-relaxed text-subtle sm:px-6 md:flex-row md:items-start md:justify-between md:gap-10">
          <p className="shrink-0">{footer.legal}</p>
          <p className="max-w-2xl md:text-right">{footer.trademarks}</p>
        </div>
      </div>
    </footer>
  );
}
