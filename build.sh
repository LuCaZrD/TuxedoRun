#!/bin/bash
# Builds TuxedoRun.app next to this script.
set -euo pipefail
cd "$(dirname "$0")"
rm -rf TuxedoRun.app
mkdir -p TuxedoRun.app/Contents/MacOS
swiftc -O -o TuxedoRun.app/Contents/MacOS/TuxedoRun main.swift
cp Info.plist TuxedoRun.app/Contents/Info.plist
codesign --force --sign - TuxedoRun.app
echo "built $(pwd)/TuxedoRun.app"
