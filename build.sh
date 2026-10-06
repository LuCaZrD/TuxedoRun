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
swiftc -O -o "$app/Contents/MacOS/TuxedoRun" *.swift
cp Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
rm -rf TuxedoRun.app
ditto --noextattr --noqtn "$app" TuxedoRun.app
echo "built $(pwd)/TuxedoRun.app"
