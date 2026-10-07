#!/bin/bash
# Builds TuxedoRun.app next to this script.
# The bundle is built and signed in a temp folder first, because synced folders such as
# the Desktop add file attributes that codesign rejects.
set -euo pipefail
cd "$(dirname "$0")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
app="$work/TuxedoRun.app"
mkdir -p "$app/Contents/MacOS"
# Universal binary: runs on Apple Silicon and Intel Macs.
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" -o "$work/TuxedoRun-$arch" *.swift
done
lipo -create "$work/TuxedoRun-arm64" "$work/TuxedoRun-x86_64" -output "$app/Contents/MacOS/TuxedoRun"
cp Info.plist "$app/Contents/Info.plist"
# The app icon is drawn from the avatar, so a new pet gets a matching icon.
mkdir -p "$app/Contents/Resources"
"$app/Contents/MacOS/TuxedoRun" --icon "$work/AppIcon.iconset"
iconutil -c icns "$work/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
rm -rf TuxedoRun.app
ditto --noextattr --noqtn "$app" TuxedoRun.app
echo "built $(pwd)/TuxedoRun.app ($(lipo -archs TuxedoRun.app/Contents/MacOS/TuxedoRun))"
