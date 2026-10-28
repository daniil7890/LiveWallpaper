#!/bin/bash
# Сборка LiveWallpaper.app и установка в ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/LiveWallpaper.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/LiveWallpaper "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"

pkill -x LiveWallpaper 2>/dev/null && sleep 1.5 || true
mkdir -p ~/Applications
rm -rf ~/Applications/LiveWallpaper.app
cp -R "$APP" ~/Applications/
open ~/Applications/LiveWallpaper.app
echo "Готово: ~/Applications/LiveWallpaper.app"
