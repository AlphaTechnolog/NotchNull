"use client";

import { useEffect, useState } from "react";
import { CodeXml, Download, Menu, X } from "lucide-react";
import { links, navLinks } from "@/content/site";
import { BrandMark } from "@/components/NullMark";

const SCROLL_THRESHOLD = 24;

/** Tracks whether the page has scrolled past the top and which section is on screen. */
function useNavState() {
  const [scrolled, setScrolled] = useState(false);
  const [active, setActive] = useState<string | null>(null);

  useEffect(() => {
    const update = () => setScrolled(window.scrollY > SCROLL_THRESHOLD);
    update();
    window.addEventListener("scroll", update, { passive: true });
    return () => window.removeEventListener("scroll", update);
  }, []);

  useEffect(() => {
    const sections = navLinks
      .map((link) => document.querySelector(link.href))
      .filter((section): section is Element => section !== null);
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) setActive(`#${entry.target.id}`);
        }
      },
      { rootMargin: "-45% 0px -50% 0px" },
    );
    sections.forEach((section) => observer.observe(section));
    return () => observer.disconnect();
  }, []);

  return { scrolled, active: scrolled ? active : null };
}

/**
 * The header is the notch: full width and transparent at the top of the page, then it condenses
 * into a black capsule that hangs from the top edge once you scroll.
 */
export function Nav() {
  const { scrolled, active } = useNavState();
  const [open, setOpen] = useState(false);
  const condensed = scrolled || open;

  useEffect(() => {
    if (!open) return;
    const close = (event: KeyboardEvent) => event.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, [open]);

  return (
    <header className="pointer-events-none sticky top-0 z-40 -mb-14 flex justify-center px-2 sm:px-4">
      <nav
        aria-label="Main"
        className={`pointer-events-auto relative flex h-14 w-full items-center justify-between rounded-b-[22px] border-x border-b transition-[max-width,background-color,border-color,box-shadow,padding] duration-500 ease-[cubic-bezier(0.16,1,0.3,1)] ${
          condensed
            ? "max-w-[820px] border-white/10 bg-black/85 pr-2 pl-4 shadow-[0_18px_50px_-18px_rgb(0_0_0/0.9)] backdrop-blur-xl"
            : "max-w-6xl border-transparent bg-transparent px-2"
        }`}
      >
        <a
          href="#top"
          onClick={() => setOpen(false)}
          className="flex items-center gap-2.5 rounded-lg text-[15px] font-semibold tracking-tight focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-violet"
        >
          <BrandMark size={28} />
          NotchNull
        </a>

        <ul className="absolute left-1/2 hidden -translate-x-1/2 items-center gap-0.5 text-[13.5px] md:flex">
          {navLinks.map((link) => {
            const current = active === link.href;
            return (
              <li key={link.href}>
                <a
                  href={link.href}
                  aria-current={current ? "location" : undefined}
                  className={`rounded-full px-3 py-1.5 transition-colors duration-200 focus-visible:outline-2 focus-visible:outline-violet ${
                    current ? "bg-white/10 text-foreground" : "text-muted hover:text-foreground"
                  }`}
                >
                  {link.label}
                </a>
              </li>
            );
          })}
        </ul>

        <div className="flex items-center gap-1">
          <a
            href={links.repo}
            aria-label="NotchNull source code on GitHub"
            className="hidden items-center gap-1.5 rounded-full px-3 py-1.5 text-[13.5px] text-muted transition-colors hover:text-foreground focus-visible:outline-2 focus-visible:outline-violet sm:flex"
          >
            <CodeXml className="size-4" aria-hidden="true" />
            Source
          </a>
          <a
            href={links.download}
            className="flex h-9 items-center gap-1.5 rounded-full bg-foreground px-4 text-[13px] font-semibold text-background transition-transform active:scale-[0.97] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet"
          >
            <Download className="size-3.5" aria-hidden="true" />
            Download
          </a>
          <button
            type="button"
            onClick={() => setOpen((value) => !value)}
            aria-expanded={open}
            aria-controls="mobile-nav"
            aria-label={open ? "Close menu" : "Open menu"}
            className="flex size-9 items-center justify-center rounded-full text-muted transition-colors hover:bg-white/8 hover:text-foreground focus-visible:outline-2 focus-visible:outline-violet md:hidden"
          >
            {open ? <X className="size-5" aria-hidden="true" /> : <Menu className="size-5" aria-hidden="true" />}
          </button>
        </div>

        {open && (
          <div
            id="mobile-nav"
            className="animate-condense absolute inset-x-0 top-full mt-2 rounded-[22px] border border-white/10 bg-black p-2 shadow-[0_18px_50px_-18px_rgb(0_0_0/0.9)] md:hidden"
          >
            <ul className="flex flex-col">
              {[...navLinks, { label: "Source code", href: links.repo }].map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    onClick={() => setOpen(false)}
                    className="flex h-11 items-center rounded-2xl px-4 text-[15px] text-muted transition-colors hover:bg-white/6 hover:text-foreground"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        )}
      </nav>
    </header>
  );
}
