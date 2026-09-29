/** Every link, label and piece of copy on the site lives here. */

export const links = {
  repo: "https://github.com/Obed0101/NotchNull",
  download: "https://github.com/Obed0101/NotchNull/releases/latest/download/NotchNull.zip",
  releases: "https://github.com/Obed0101/NotchNull/releases",
  privacy: "https://github.com/Obed0101/NotchNull/blob/main/PRIVACY.md",
  license: "https://github.com/Obed0101/NotchNull/blob/main/LICENSE",
  contributing: "https://github.com/Obed0101/NotchNull/blob/main/CONTRIBUTING.md",
  issues: "https://github.com/Obed0101/NotchNull/issues",
};

export const hero = {
  title: "Any notch you want.",
  titleMuted: "Just ask your agent.",
  subtitle:
    "NotchNull is the notch you rebuild by asking. Tell Claude Code or Codex, on your own Mac, what it should be: new widgets, colors, animations, tabs, even its Settings page. Your agent edits the files or the source, checks a render, and your notch changes.",
  meta: "Open source · Works with the Claude Code and Codex already on your Mac · macOS 14+",
};

/**
 * The pinned hero walks through these real renders as the visitor scrolls. Each step is something
 * a user asked their agent for and what the agent made; the renders come from those exact files.
 */
export const heroSteps = [
  { src: "/shots/widgets.png", width: 576, height: 226, label: "Widgets", prompt: "A panel with CI, my focus hours and site traffic.", body: "Your agent wrote three JSON files in ~/.notchnull/widgets, each a command and a view. Saved, they are live." },
  { src: "/shots/theme.png", width: 581, height: 216, label: "Look", prompt: "Make it plum, pink and rounder.", body: "Four keys in settings.json. The Settings window moves with it, both ways." },
  { src: "/shots/preset-minimal.png", width: 536, height: 200, label: "Layout", prompt: "Strip it down to music and my day.", body: "It applied the Minimal preset: three tabs, two rows, no bounce. Same app, a different notch." },
  { src: "/shots/ci-wing.png", width: 346, height: 52, label: "Wing", prompt: "Show me when CI fails.", body: "While a check is red, this slides out beside the camera. It leaves when the checks pass." },
  { src: "/shots/deploy.png", width: 450, height: 109, label: "Banner", prompt: "Tell me how the deploy is going.", body: "One notchnull show line in the deploy script: a banner with live progress." },
] as const;

export const statement =
  "Other notch apps ship their notch. NotchNull ships yours. Like Arch Linux, it is a small, fast base you shape into anything, except you never read the wiki: your agent did. Widgets, colors, animations, tabs, the Settings page, the Swift source. Ask, and it is rebuilt.";

/** Setup, on first launch: how much the notch shows. The renders are the presets' own previews. */
export const presets = [
  { id: "minimal", name: "Minimal", src: "/shots/preset-minimal.png", width: 536, height: 200, body: "Music, your widgets and what matters today. Nothing slides out unless it needs you." },
  { id: "balanced", name: "Balanced", src: "/shots/preset-balanced.png", width: 576, height: 216, body: "The everyday set: agents, music, clipboard, downloads that clean themselves, your widgets." },
  { id: "complete", name: "Complete", src: "/shots/preset-complete.png", width: 576, height: 216, body: "Everything NotchNull does, the way it ships: every tab, every activity, Mac stats." },
] as const;

/** Every part of the notch an agent can change, with something a user might actually ask. */
export const changeables = [
  { title: "Widgets", prompt: "A card with today’s Stripe revenue.", body: "A command and a view tree, one file in widgets/." },
  { title: "Wings", prompt: "A red dot by the camera while prod is down.", body: "Beside the notch while a condition holds, gone when it stops." },
  { title: "Look", prompt: "Plum, a pink accent, rounder corners.", body: "Body, tint, accent, Liquid Glass and roundness." },
  { title: "Motion", prompt: "Slower, and no bounce.", body: "Spring speed and bounce, and the light it gives off." },
  { title: "Layout", prompt: "Make it a floating island, and a wider panel.", body: "Notch or island, tabs, Home rows, and any size you type." },
  { title: "Activities", prompt: "Stop showing me when it’s charging.", body: "Which events slide out, one switch each." },
  { title: "Settings page", prompt: "Add a section with my widgets’ options.", body: "The Settings window is SwiftUI in the repo, and the skill shows where." },
  { title: "Anything else", prompt: "A radial gauge, and a tab for my servers.", body: "New views, tabs and integrations: your agent changes the source and rebuilds." },
] as const;

const skillTree = `${links.repo}/tree/main/skills/notchnull`;

/** What ships to start from, in the repo and in Settings. */
export const starters = [
  { path: "SKILL.md", href: `${skillTree}/SKILL.md`, body: "The skill your agent reads: the loop, every file, taste and safety." },
  { path: "examples/", href: `${skillTree}/examples`, body: "Working widgets: CI with a wing, open PRs, disk, a todo list, a world clock." },
  { path: "presets/", href: `${skillTree}/presets`, body: "Minimal, Balanced and Complete, each with its render." },
  { path: "themes/", href: `${skillTree}/themes`, body: "Twelve looks, from Graphite and Plum to Terminal, Frost and Brutal." },
  { path: "references/", href: `${skillTree}/references`, body: "The widget format, every setting, the CLI and API, and a map of the source." },
] as const;

/** The build loop: what the visitor asks, the file the agent writes, the command it checks with. */
export const buildLoop = {
  prompt: "Add a CI widget for this repo, and show a red wing beside the notch while it’s failing.",
  promptSource: "Claude Code, with the notchnull skill",
  file: "~/.notchnull/widgets/ci.json",
  code: `{
  "title": "CI",
  "refresh": 60,
  "command": "gh run list --json … --jq …",
  "view": {
    "type": "value",
    "value": "{{data.failing | count}}",
    "label": "failing workflows"
  },
  "wing": {
    "when": "{{data.failing | count}}",
    "tint": "red",
    "trailingText": "{{data.failing | count}} failing"
  }
}`,
  check: "notchnull render ci.png --wing",
  starterPrompt: "Use the notchnull skill: add a widget with my open pull requests, and show a red wing beside the notch while CI is failing.",
};

export const buildSteps = [
  { title: "You ask", body: "In plain words, in the agent you already use." },
  { title: "It writes a file", body: "A widget, a setting, a wing. Saved, it is live." },
  { title: "It checks the render", body: "The notch drawn to a PNG, so it sees what you will." },
];

export const platform: Feature[] = [
  { title: "Widgets", body: "A shell command and a view tree of values, gauges, lists, sparklines and buttons. Errors show in the card, never a silent blank." },
  { title: "Wings", body: "Anything beside the camera while a condition holds: a failing check, a running deploy. It goes away on its own." },
  { title: "settings.json", body: "Every setting in one file, synced both ways with the Settings window. Unknown keys and bad values are reported." },
  { title: "CLI and local API", body: "notchnull show, open, widget data, settings set. Or POST to 127.0.0.1 with your token." },
  { title: "Render", body: "notchnull render draws the notch with your files, so an agent can judge its own work before telling you it is done." },
  { title: "The source", body: "When files are not enough, the skill shows the agent how to change the Swift app itself and rebuild it. GPL-3.0." },
];

export type Feature = {
  title: string;
  body: string;
  shot?: { src: string; width: number; height: number };
};

export const agentFeatures: Feature[] = [
  {
    title: "Limits as % left",
    body: "Claude Code and Codex 5-hour and weekly limits, reset times, and a pace forecast that warns before you run out.",
  },
  {
    title: "Needs you",
    body: "The notch lights up the moment Claude asks for permission. Click to jump to the exact terminal.",
  },
  {
    title: "Done, with the summary",
    body: "When a turn ends you see the agent's final message and how long it took.",
  },
  {
    title: "Live sessions",
    body: "Every running Claude Code and Codex session, detected from their transcripts. Tokens today, by the hour.",
  },
];

export const features: Feature[] = [
  { title: "Island mode", body: "No notch on the screen, or a resolution that leaves it out? It floats as an island with a clock, and its satellites grow into music and Control Center on hover.", shot: { src: "/shots/island.png", width: 566, height: 209 } },
  { title: "Downloads that expire", body: "Each new download asks how long to keep it, from 10 minutes to 30 days. Then it goes to the Trash, with Undo.", shot: { src: "/shots/keep.png", width: 530, height: 166 } },
  { title: "Any player", body: "Spotify, Music, and videos in your browser. Artwork, scrubbing, output volume.", shot: { src: "/shots/music.png", width: 292, height: 40 } },
  { title: "Volume & brightness", body: "A one-line HUD in the notch that can replace the system one.", shot: { src: "/shots/volume.png", width: 388, height: 40 } },
  { title: "Dev boards", body: "ESP32, Arduino, CH340 and FTDI boards announce themselves with their serial port.", shot: { src: "/shots/serial.png", width: 574, height: 40 } },
  { title: "Every device", body: "Bluetooth headphones with AirPods battery, keyboards, mice, controllers, drives, displays, AirDrop.", shot: { src: "/shots/airpods.png", width: 450, height: 40 } },
  { title: "Power", body: "Charging, unplugged, low battery — and a battery tint that follows Low Power and High Power mode.", shot: { src: "/shots/charging.png", width: 380, height: 40 } },
  { title: "Downloads & screenshots", body: "Progress while it downloads, a preview when a screenshot lands, one click to keep it.", shot: { src: "/shots/download.png", width: 369, height: 50 } },
  { title: "Timers & meetings", body: "Countdowns in the wings and your next meeting with a Join button.", shot: { src: "/shots/timer.png", width: 330, height: 40 } },
  { title: "Drop zone", body: "Drag a file toward the notch to park it in the Tray, copy it or AirDrop it.", shot: { src: "/shots/drop.png", width: 553, height: 181 } },
  { title: "Clipboard history", body: "Encrypted on your Mac, with real previews of images and files.", shot: { src: "/shots/clipboard.png", width: 553, height: 211 } },
];

export const panels = [
  { id: "home", label: "Home", src: "/shots/home.png", width: 592, height: 235 },
  { id: "agents", label: "Agents", src: "/shots/agents.png", width: 593, height: 235 },
  { id: "controls", label: "Controls", src: "/shots/controls.png", width: 593, height: 235 },
  { id: "widgets", label: "Widgets", src: "/shots/widgets.png", width: 576, height: 226 },
  { id: "downloads", label: "Downloads", src: "/shots/downloads.png", width: 576, height: 226 },
  { id: "clipboard", label: "Clipboard", src: "/shots/clipboard.png", width: 553, height: 211 },
  { id: "tray", label: "Tray", src: "/shots/tray.png", width: 553, height: 211 },
] as const;

export const customization = [
  "notch and panel size",
  "roundness",
  "a black, tinted or Liquid Glass body",
  "accent color",
  "animation speed and bounce",
  "tab order",
  "Home rows",
  "which activities appear",
  "and anything else your agent can write",
];

export const privacy = [
  { title: "No telemetry", body: "No analytics, no accounts, no server." },
  { title: "One request", body: "Your Claude usage, fetched with the login already on your Mac. The token is never refreshed or stored." },
  { title: "Encrypted clipboard", body: "History is sealed with AES-GCM; password managers are skipped." },
  { title: "Read the source", body: "GPL-3.0. Every file NotchNull reads and writes is listed in PRIVACY.md." },
];

export const install = {
  steps: [
    "Download NotchNull.zip and move the app to Applications.",
    "It is not notarized by Apple yet, so right-click it → Open the first time, or run:",
    "Grant only the permissions you want. Every one is optional.",
  ],
  command: "xattr -dr com.apple.quarantine /Applications/NotchNull.app",
};

export const navLinks = [
  { label: "Build", href: "#build" },
  { label: "Make it yours", href: "#yours" },
  { label: "Agents", href: "#agents" },
  { label: "Features", href: "#features" },
];

export const footer = {
  tagline: "Any notch you want. Just ask your agent. Free and open source.",
  columns: [
    {
      title: "Product",
      links: [
        { label: "Build", href: "#build" },
        { label: "Make it yours", href: "#yours" },
        { label: "Agents", href: "#agents" },
        { label: "Features", href: "#features" },
        { label: "Privacy", href: "#privacy" },
        { label: "Install", href: "#install" },
      ],
    },
    {
      title: "Project",
      links: [
        { label: "Source code", href: links.repo },
        { label: "Releases", href: links.releases },
        { label: "Contribute", href: links.contributing },
        { label: "Report a bug", href: links.issues },
      ],
    },
    {
      title: "Legal",
      links: [
        { label: "Privacy policy", href: links.privacy },
        { label: "GPL-3.0 license", href: links.license },
      ],
    },
  ],
  legal: "Free software under GPL-3.0 · No telemetry",
  trademarks:
    "Claude is a trademark of Anthropic. OpenAI and Codex are trademarks of OpenAI. NotchNull is an independent project, not affiliated with either.",
};
