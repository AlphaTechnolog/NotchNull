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
  eyebrow: "Free and open source · macOS 14+",
  title: "Your notch, made useful.",
  subtitle:
    "A live control center that grows out of the MacBook camera notch. Music, your AI agents, devices and system controls — one hover away, every state animated.",
};

/** One real render of the app per step of the hero loop; durations in milliseconds. */
export const stageFrames = [
  { src: "/shots/music.png", width: 292, label: "Now playing", duration: 2400 },
  { src: "/shots/needs-you.png", width: 524, label: "Claude needs you", duration: 3000 },
  { src: "/shots/done.png", width: 524, label: "Agent done", duration: 2800 },
  { src: "/shots/volume.png", width: 388, label: "Volume", duration: 1600 },
  { src: "/shots/serial.png", width: 574, label: "ESP32 plugged in", duration: 2400 },
  { src: "/shots/home.png", width: 592, label: "Home", duration: 3600 },
  { src: "/shots/agents.png", width: 593, label: "Agents", duration: 3600 },
] as const;

export type Feature = {
  icon: string;
  title: string;
  body: string;
  shot?: { src: string; width: number };
};

export const agentFeatures: Feature[] = [
  {
    icon: "Gauge",
    title: "Limits as % left",
    body: "Claude Code and Codex 5-hour and weekly limits, reset times, and a pace forecast that warns before you run out.",
  },
  {
    icon: "BellRing",
    title: "Needs you",
    body: "The notch lights up the moment Claude asks for permission. Click to jump to the exact terminal.",
    shot: { src: "/shots/needs-you.png", width: 524 },
  },
  {
    icon: "CircleCheck",
    title: "Done, with the summary",
    body: "When a turn ends you see the agent's final message and how long it took — no alt-tabbing.",
    shot: { src: "/shots/done.png", width: 524 },
  },
  {
    icon: "Activity",
    title: "Live sessions",
    body: "Every running Claude Code and Codex session, detected from their transcripts. Tokens today, by the hour.",
  },
];

export const features: Feature[] = [
  { icon: "Music", title: "Any player", body: "Spotify, Music, and videos in your browser. Artwork, scrubbing, output volume.", shot: { src: "/shots/music.png", width: 292 } },
  { icon: "Volume2", title: "Volume & brightness", body: "A one-line HUD in the notch that can replace the system one.", shot: { src: "/shots/volume.png", width: 388 } },
  { icon: "Cpu", title: "Dev boards", body: "ESP32, Arduino, CH340 and FTDI boards announce themselves with their serial port.", shot: { src: "/shots/serial.png", width: 574 } },
  { icon: "Headphones", title: "Every device", body: "Bluetooth headphones with AirPods battery, keyboards, mice, controllers, drives, displays, AirDrop.", shot: { src: "/shots/airpods.png", width: 450 } },
  { icon: "BatteryCharging", title: "Power", body: "Charging, unplugged, low battery — and a battery tint that follows Low Power and High Power mode.", shot: { src: "/shots/charging.png", width: 380 } },
  { icon: "Download", title: "Downloads & screenshots", body: "Progress while it downloads, a preview when a screenshot lands, one click to keep it.", shot: { src: "/shots/download.png", width: 369 } },
  { icon: "Timer", title: "Timers & meetings", body: "Countdowns in the wings and your next meeting with a Join button.", shot: { src: "/shots/timer.png", width: 330 } },
  { icon: "Inbox", title: "Drop zone", body: "Drag a file toward the notch to park it in the Tray, copy it or AirDrop it.", shot: { src: "/shots/drop.png", width: 553 } },
  { icon: "ClipboardList", title: "Clipboard history", body: "Encrypted on your Mac, with real previews of images and files.", shot: { src: "/shots/clipboard.png", width: 553 } },
];

export const panels = [
  { id: "home", label: "Home", src: "/shots/home.png", width: 592 },
  { id: "agents", label: "Agents", src: "/shots/agents.png", width: 593 },
  { id: "controls", label: "Controls", src: "/shots/controls.png", width: 593 },
  { id: "clipboard", label: "Clipboard", src: "/shots/clipboard.png", width: 553 },
  { id: "tray", label: "Tray", src: "/shots/tray.png", width: 553 },
] as const;

export const customization = [
  "Notch and panel size",
  "Roundness",
  "Black, tinted or Liquid Glass body",
  "Accent color",
  "Animation speed and bounce",
  "Tab order",
  "Home rows",
  "Which activities appear",
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
  { label: "Agents", href: "#agents" },
  { label: "Panel", href: "#panel" },
  { label: "Features", href: "#features" },
  { label: "Privacy", href: "#privacy" },
];

export const footer = {
  tagline: "The MacBook notch, made useful. Free and open source.",
  columns: [
    {
      title: "Product",
      links: [
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
