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
  title: "Your notch,",
  titleMuted: "made useful.",
  subtitle:
    "A live control center that grows out of the MacBook camera notch. Music, your AI agents, devices and system controls — one hover away, every state animated.",
  meta: "Free and open source · macOS 14+ · Apple silicon",
};

/** The pinned hero walks through these real renders as the visitor scrolls. */
export const heroSteps = [
  { src: "/shots/music.png", width: 292, height: 40, label: "Music", title: "Music in the wings.", body: "Spotify, Music or a video in your browser, with artwork and a live level." },
  { src: "/shots/needs-you.png", width: 524, height: 106, label: "Needs you", title: "Claude needs you.", body: "The notch lights up the moment an agent asks for permission. Click to jump to its terminal." },
  { src: "/shots/done.png", width: 524, height: 106, label: "Done", title: "Done, with the summary.", body: "The agent's final message and how long the turn took, without alt-tabbing." },
  { src: "/shots/serial.png", width: 574, height: 40, label: "Devices", title: "Every device announces itself.", body: "Headphones, keyboards, drives, displays — and ESP32 or Arduino boards with their serial port." },
  { src: "/shots/home.png", width: 592, height: 235, label: "Panel", title: "Hover, and it opens.", body: "Now playing, keep awake, your next meeting, a timer and your Mac's load in one panel." },
] as const;

export const statement =
  "The notch is dead space. NotchNull turns it into one black surface that morphs out of the hardware and back. Music, your agents, your devices, one hover away. Every state animates. Nothing pops.";

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
