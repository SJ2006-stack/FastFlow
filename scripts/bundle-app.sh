#!/usr/bin/env bash
# Wrap the SwiftPM executable in a minimal .app for TCC prompts / menu bar use.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CONFIG="${1:-debug}"
swift build -c "$CONFIG"
BIN="$ROOT/.build/$CONFIG/FastFlow"
APP="$ROOT/.build/FastFlow.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FastFlow"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>local.fastflow.app</string>
  <key>CFBundleName</key>
  <string>FastFlow</string>
  <key>CFBundleExecutable</key>
  <string>FastFlow</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>FastFlow records audio while you hold the push-to-talk hotkey to transcribe speech locally.</string>
</dict>
</plist>
PLIST
codesign --force --sign - --entitlements "$ROOT/entitlements/FastFlow.debug.entitlements" "$APP" 2>/dev/null || true
echo "Built $APP (debug entitlements — sandbox off)"
echo "Ship profile: entitlements/FastFlow.entitlements"
echo "Open with: open $APP"
