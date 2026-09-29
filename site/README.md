# NotchNull website

The one-page site for NotchNull: Next.js (App Router) with a static export.

```sh
bun install
bun dev          # http://localhost:3000
bun run build    # static site in out/
```

All copy, links and feature lists live in `content/site.ts`. The notch images in `public/shots/` are real renders of the app, exported with a transparent background:

```sh
swift build
.build/debug/NotchNull --snapshots /tmp/snap --transparent
```

Deploys as-is to Vercel (framework preset: Next.js, root directory `site`) or any static host from `out/`.
