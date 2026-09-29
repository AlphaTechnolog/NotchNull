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
  title: "NotchNull — your MacBook notch, made useful",
  description:
    "A free, open-source control center that grows out of the MacBook notch: music, Claude Code and Codex usage and alerts, devices, system controls. Every state animated.",
  openGraph: {
    title: "NotchNull",
    description: "Your MacBook notch, made useful. Free and open source.",
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
