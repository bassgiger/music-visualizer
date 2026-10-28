#!/bin/sh
# Baut „build/Music Visualizer.app“ – ohne Xcode, nur mit den Command Line Tools.
set -eu
cd "$(dirname "$0")/.."

swift build -c release --product MusicVisualizer
BIN="$(swift build -c release --show-bin-path)/MusicVisualizer"
APP="build/Music Visualizer.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/MusicVisualizer"
cp App/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signiert: reicht zum Testen auf diesem Mac, nicht für Weitergabe oder App Store
codesign --force --sign - "$APP"
echo "Fertig: $APP"
