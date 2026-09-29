#!/bin/sh
# Builds NotchNull.app into ./build (release, ad-hoc signed).
# Usage: scripts/build-app.sh [--install]   (--install copies it to /Applications)
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
BUILD="$ROOT/build"
APP="$BUILD/NotchNull.app"

cd "$ROOT"
swift build -c release --product NotchNull
BIN="$(swift build -c release --show-bin-path)/NotchNull"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/NotchNull"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Now Playing bridge: a dylib run inside /usr/bin/perl (see MediaBridge/NowPlayingBridge.m).
mkdir -p "$BUILD/bridge"
clang -dynamiclib -fobjc-arc -O2 -mmacosx-version-min=14.0 -Wno-arc-performSelector-leaks \
  -framework Foundation -framework AppKit \
  -o "$BUILD/bridge/NowPlayingBridge.dylib" "$ROOT/MediaBridge/NowPlayingBridge.m"
codesign --force --sign - "$BUILD/bridge/NowPlayingBridge.dylib"
cp "$ROOT/MediaBridge/now-playing.pl" "$BUILD/bridge/now-playing.pl"
cp "$BUILD/bridge/NowPlayingBridge.dylib" "$BUILD/bridge/now-playing.pl" "$APP/Contents/Resources/"

# App icon rendered from AppIconArt.swift.
ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
"$BIN" --icon "$BUILD/icon-1024.png"
for size in 16 32 128 256 512; do
  sips -z $size $size "$BUILD/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double "$BUILD/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  rm -rf "/Applications/NotchNull.app"
  cp -R "$APP" /Applications/
  echo "Installed /Applications/NotchNull.app"
fi
