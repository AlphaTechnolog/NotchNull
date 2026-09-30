#!/usr/bin/env python3
"""Renders the pictures for the README and the website from the app's transparent snapshots.

    swift build && python3 scripts/render-images.py

README pictures (docs/images) sit on a real wallpaper with a menu bar. Website shots
(site/public/shots) stay transparent: the site draws its own screen, wallpaper and menu bar
behind them. Needs Pillow (`pip3 install pillow`). The fixture data is the same demo data as
`NotchNull --snapshots`. Wallpaper: "aerial photo of foggy mountains" by Sam Ferrara on
Unsplash (https://unsplash.com/photos/aerial-photo-of-foggy-mountains-1527pjeb6jg),
Unsplash License.
"""
import datetime
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "docs" / "images"
SHOTS = ROOT / "site" / "public" / "shots"
BINARY = ROOT / ".build" / "debug" / "NotchNull"
SCALE = 2
WIDTH, HEIGHT = 1320 * SCALE, 720 * SCALE
MENU_BAR = 32 * SCALE
FONT = "/System/Library/Fonts/SFNS.ttf"


def font(size, weight):
    face = ImageFont.truetype(FONT, size * SCALE)
    face.set_variation_by_name(weight)
    return face


def wallpaper():
    photo = Image.open(IMAGES / "wallpaper.jpg").convert("RGBA")
    height = round(photo.height * WIDTH / photo.width)
    return photo.resize((WIDTH, height), Image.LANCZOS).crop((0, 0, WIDTH, HEIGHT))


def menu_bar(canvas):
    """A translucent menu bar with an app menu and a clock matching the island pill's."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rectangle([0, 0, WIDTH, MENU_BAR], fill=(0, 0, 0, 56))
    y = MENU_BAR // 2
    x = 20 * SCALE
    for index, title in enumerate(["Terminal", "Shell", "Edit"]):
        face = font(13, "Bold" if index == 0 else "Medium")
        draw.text((x, y), title, font=face, fill=(255, 255, 255, 240), anchor="lm")
        x += draw.textlength(title, font=face) + 18 * SCALE
    clock = datetime.datetime.now().strftime("%a %-I:%M %p")
    draw.text((WIDTH - 20 * SCALE, y), clock, font=font(13, "Medium"), fill=(255, 255, 255, 240), anchor="rm")
    canvas.alpha_composite(layer)


def scene(snapshots, name):
    canvas = wallpaper()
    menu_bar(canvas)
    canvas.alpha_composite(Image.open(snapshots / f"{name}.png").convert("RGBA"))
    return canvas, Image.open(snapshots / f"{name}.png").getchannel("A")


def body_bottom(alpha):
    """Lowest row of the opaque body (its soft shadow is left out)."""
    box = alpha.point(lambda value: 255 if value > 200 else 0).getbbox()
    return box[3] if box else 0


def crop(snapshots, name, width=WIDTH, height=None, margin=110, left=None, floor=160):
    canvas, alpha = scene(snapshots, name)
    bottom = height or max(body_bottom(alpha) + margin, floor)
    x = (WIDTH - width) // 2 if left is None else left
    return canvas.crop((x, 0, x + width, bottom))


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.width - 1, image.height - 1], radius, fill=255)
    image.putalpha(mask)
    return image


def label(image, text):
    ImageDraw.Draw(image).text((20 * SCALE, image.height - 20 * SCALE), text, font=font(15, "Semibold"),
                               fill=(255, 255, 255, 240), anchor="ls")
    return image


def save(image, name, radius=28):
    rounded(image, radius).save(IMAGES / f"{name}.png", optimize=True)
    print(f"docs/images/{name}.png  {image.width}x{image.height}")


def site_shot(snapshots, name, output, side, bottom, tight=False):
    """A transparent render centered on the notch, the way `notchnull render --transparent` crops:
    panels keep room for their shadow, wings and banners hug the body and its glow."""
    image = Image.open(snapshots / f"{name}.png").convert("RGBA")
    alpha = image.getchannel("A")
    if tight:
        box = alpha.getbbox()
    else:
        body = alpha.point(lambda value: 255 if value > 200 else 0).getbbox()
        glow = alpha.point(lambda value: 255 if value > 8 else 0).getbbox()
        half = max(WIDTH // 2 - body[0], body[2] - WIDTH // 2) + side
        height = max(body[3] + bottom, glow[3])
        # Whole points, so the site's declared sizes stay exact.
        box = (WIDTH // 2 - half, 0, WIDTH // 2 + half, height + height % SCALE)
    shot = image.crop(box)
    shot.save(SHOTS / f"{output}.png", optimize=True)
    print(f"site/public/shots/{output}.png  {shot.width // SCALE}x{shot.height // SCALE} pt")


def website(snapshots):
    panels = [("10-open-home", "home"), ("11-open-agents", "agents"), ("15-open-controls", "controls"),
              ("17-open-widgets", "widgets"), ("16-open-downloads", "downloads"), ("13-open-clipboard", "clipboard"),
              ("12-open-tray", "tray"), ("18-open-recent", "recent"), ("20-drop", "drop")]
    for name, output in panels:
        site_shot(snapshots, name, output, side=40 * SCALE, bottom=36 * SCALE)
    # The Agents section shows the roomier panel, where every provider and session fits.
    site_shot(snapshots, "51-large-agents", "agents-large", side=40 * SCALE, bottom=36 * SCALE)
    wings = [("308-activity-downloadKeep", "keep"), ("306-activity-custom", "deploy"), ("307-activity-agentDone", "done"),
             ("301-activity-needsYou", "needs-you"), ("300-activity-hello", "hello"), ("316-activity-meetingSoon", "meeting"),
             ("314-activity-screenshot", "screenshot"), ("305-activity-usageWarning", "usage-warning"),
             ("317-activity-download", "download"), ("313-activity-accessory", "airpods"), ("311-activity-charging", "charging"),
             ("320-activity-agentRunning", "running"), ("319-activity-timer", "timer"), ("321-activity-music", "music"),
             ("302-activity-volume", "volume"), ("70-device-serial", "serial"), ("74-widget-wing", "ci-wing"),
             ("321-activity-music", "classic")]
    for name, output in wings:
        site_shot(snapshots, name, output, side=7 * SCALE, bottom=2)
    site_shot(snapshots, "90-island-closed", "island", side=0, bottom=0, tight=True)


def main():
    with tempfile.TemporaryDirectory() as directory:
        snapshots = Path(directory)
        subprocess.run([str(BINARY), "--snapshots", str(snapshots), "--transparent"], check=True)
        website(snapshots)
        # Hero: the classic notch and the island, each opened on Home.
        save(crop(snapshots, "50-large-home"), "hero-classic")
        save(crop(snapshots, "94-island-open-home"), "hero-island")
        # The two shapes at rest.
        save(label(crop(snapshots, "321-activity-music", width=1500, height=230), "Classic notch"), "shape-classic")
        save(label(crop(snapshots, "90-island-closed", width=1500, height=230), "Island"), "shape-island")
        # The island's satellites grown into their cards.
        save(crop(snapshots, "98-island-media-card", width=1160, height=340, left=372), "island-media")
        save(crop(snapshots, "99-island-controls-card", width=1120, height=380, left=1160), "island-controls")
        # The roomier panel, so Agents and Controls show everything without scrolling.
        for name, output in [("51-large-agents", "agents"), ("52-large-controls", "controls")]:
            save(crop(snapshots, name, width=1480, margin=70), output, radius=24)
        for name, output in [("18-open-recent", "recent"), ("308-activity-downloadKeep", "downloads-keep"),
                             ("301-activity-needsYou", "wing-needsyou"), ("75-needs-you-stacked", "needs-you-stacked"),
                             ("307-activity-agentDone", "wing-done"), ("70-device-serial", "wing-serial"),
                             ("74-widget-wing", "wing-ci"), ("306-activity-custom", "banner-custom")]:
            save(crop(snapshots, name, width=1240, margin=70), output, radius=24)


if __name__ == "__main__":
    main()
