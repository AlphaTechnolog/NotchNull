import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // A static site: deploys to Vercel, GitHub Pages or any file host.
  output: "export",
  images: { unoptimized: true },
};

export default nextConfig;
