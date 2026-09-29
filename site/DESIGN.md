# NotchNull site — design

## Direction

The page is the notch: pure black like the hardware, white type, and no accent color of its own. The only color comes from real renders of the app (Claude orange, the Needs-you pink, green OK), so the product is what stands out.

- **Signature moment:** the hero is pinned while the notch walks through its real states (music → needs you → done → devices → panel). Scroll position drives the step; the headline blurs away and the screen rises into place. Step buttons jump to their scroll position.
- **Statement:** one paragraph lit word by word by a CSS scroll timeline.
- **Activities:** each render hangs from the top edge of its own sliver of screen and slides out of that edge as it scrolls into view.
- Everything else is still: typographic lists with hairline rules, no cards, no icon tiles, no kickers above headings, no gradient text.

## Tokens (`app/globals.css`)

| Role | Value |
|---|---|
| Background | `#000000` |
| Surface / raised | `#0b0b0c` / `#161618` |
| Hairline | `rgb(255 255 255 / 0.1)` |
| Foreground | `#f5f5f7` |
| Muted / subtle text | `#a1a1a6` / `#86868b` |
| Success (copy confirmation only) | `#30d158` |
| Motion curve | `cubic-bezier(0.23, 1, 0.32, 1)` |

Type is Geist: display 48–96px semibold at -0.04em, section titles 38–56px, body 15–19px. The wallpaper behind every screen is a neutral graphite with a soft light from the notch (`public/brand/wallpaper.jpg`, generated procedurally, no color).

## Motion rules

- Scroll-driven effects live in `@supports (animation-timeline: view())` and `prefers-reduced-motion: no-preference`; content is fully visible otherwise.
- With reduced motion the hero is not pinned and its steps become plain buttons.
- A container that clips an animated child uses `overflow: clip`, not `hidden`: `hidden` makes it the scroll container the view timeline tracks.
- Renders carry their intrinsic width and height. Strip renders load eagerly because they start clipped at their edge, where lazy loading never sees them.
