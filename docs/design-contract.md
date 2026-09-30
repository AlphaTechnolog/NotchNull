# NotchNull — design contract

## Intent
MacBook notch utility for developers who run Claude Code / Codex. Mode: Operate (glanceable, zero-friction), with one authored focal moment (the notch morph). Primary journeys:
1. Glance: hover the notch → music, agents, stats, up-next, keep awake in one panel.
2. Agents: Claude/Codex usage limits with reset time + pace forecast; live sessions; "needs you" alert that jumps to the exact terminal tab.
3. Ambient events: volume/brightness HUD, charging, AirPods, downloads, screenshots, timers, meeting countdown slide out of the notch as wings.
4. Drop: drag a file toward the notch → Tray / Copy / AirDrop tiles.

## Reference read (inspected 2026-09-28)
- notchview-site.vercel.app film.mp4, claude-mac.mp4 and 13 scene stills.
- Take: pure-black surface continuous with the hardware notch; wings either side of the notch (art left, activity right); header row of icon tabs left + gear right; dashed drop tiles with per-action tint; segmented level bar white→amber; per-feature accent hue; "hello" handwritten line-draw on login; pink "Needs approval" state for Claude.
- Avoid / improve: static card grid; percentages without context (add reset countdown + pace forecast); tabs that pop (morph + blur-replace instead); no session list; no Codex liveness.

## Direction
THESIS: the notch is a living material — every state is the same black body morphing (spring) out of the hardware notch; content condenses from blur, never pops.
OWN-WORLD: #000 body, white text at 3 opacity steps (1.0 / 0.62 / 0.38), inset surfaces white 6% with 10% hairline, per-activity accent that also emits as a soft light along the body's lower edge.
SIGNATURE: the "emission" edge — a 1pt light line along the bottom curve tinted by the active activity (album color, Claude pink, charging green), and a light that chases the full outline when an agent needs you.

## Tokens (source of truth: Sources/NotchNull/Config/Theme.swift, Motion.swift)
- Radii: closed top 6 / bottom 14; open top 19 / bottom 32; inner surfaces 18 (concentric: 32 − 14 padding).
- Type: SF Pro; numbers SF Pro Rounded + monospaced digits; labels 11 semibold; titles 13 semibold; hero numbers 26–30 medium rounded.
- Accents: music = artwork average (fallback #FF5E8A); tray #A78BFA; copy #34D399; airdrop #60A5FA; volume white→#FFB35C; timer #FF9F0A; Claude #D97757; needs-you #FF4FA3; Codex #8FA8FF; battery #30D158; low #FF453A; downloads #0A84FF; clipboard #2DD4BF; calendar #FF6B6B.
- Motion: open spring(response .42, damping .78); close spring(response .32, damping 1) — exits faster; content blur 6→0 + scale .96→1 + opacity; stagger 35 ms, capped 6 items; press scale .96; numeric text transitions for every number; reduced motion → opacity-only 150 ms.

## States (Given / When / Then)
- Closed + no activity: body = hardware notch size, invisible.
- Activity (priority order): needs-you > HUD (volume/brightness) > drop > timer-finished > download > charging > AirPods > screenshot > meeting-soon > claude running > music. Highest shows as wings; transient ones auto-dismiss (HUD 1.4 s, charging 3 s, screenshot 4 s).
- Hover (150 ms dwell) → open panel; leave for 350 ms → close. Two-finger swipe down opens, up closes.
- Drag file near notch → drop panel with three tiles; hovered tile brightens + scales 1.03; release performs action and shows confirmation.
- Permission missing → the affected module shows an inline "Allow" control that opens the right System Settings pane; never a dead control.
- Claude usage: token expired → "Open Claude Code to refresh sign-in" (we never refresh the OAuth token ourselves).

## Acceptance
- A1 build: `scripts/build-app.sh` produces NotchNull.app, launches as agent app (no Dock icon).
- A2 render: `NotchNull.app/Contents/MacOS/NotchNull --snapshots <dir>` renders every panel/activity state to PNG for inspection.
- A3 live: panel opens on hover on the built-in display; screenshots of live states when Screen Recording is permitted.
- A4 data: Claude + Codex usage values equal the endpoint/log values at capture time.
