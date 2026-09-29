import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  metadataBase: new URL("https://notchnull.vercel.app"),
  title: "NotchNull — any notch you want, built by your agent",
  description:
    "A free, open-source MacBook notch you rebuild by asking. The Claude Code or Codex on your Mac changes its widgets, look, animations, tabs, Settings page and source, and checks its work with a rendered PNG. Start from Minimal, Balanced or Complete.",
  openGraph: {
    title: "NotchNull",
    description: "Any notch you want. Just ask your agent. Free and open source.",
    type: "website",
  },
  twitter: { card: "summary_large_image" },
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
      <body className="min-h-dvh font-sans">{children}</body>
    </html>
  );
}
