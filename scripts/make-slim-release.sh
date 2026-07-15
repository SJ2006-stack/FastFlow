#!/usr/bin/env bash
# Build a slim FastFlow.app + zip for smooth downloads.
# Models are NEVER bundled — users download ASR weights after install (~500–600 MB once).
#
# Target: app zip well under ~30 MB (typically a few MB of executable + resources).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
DIST="$ROOT/dist"
APP="$DIST/FastFlow.app"
ZIP="$DIST/FastFlow-slim-macos-arm64.zip"

echo "==> Slim release (config=$CONFIG) — no CoreML models in package"

rm -rf "$DIST"
mkdir -p "$DIST"

# Prefer full Xcode when present (CLT-only SPM often fails on macOS 26).
if [[ -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift build -c "$CONFIG"
BIN="$ROOT/.build/$CONFIG/FastFlow"
test -x "$BIN"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# Strip local symbols to shrink download size.
if command -v strip >/dev/null; then
  cp "$BIN" "$APP/Contents/MacOS/FastFlow"
  strip -x "$APP/Contents/MacOS/FastFlow" || true
else
  cp "$BIN" "$APP/Contents/MacOS/FastFlow"
fi

# Tiny marker: proves this is a slim package (no models).
cat > "$APP/Contents/Resources/SLIM_PACKAGE.txt" <<'EOF'
FastFlow slim package
- No ASR / CoreML models are included.
- First launch uses a tiny stub engine (low RAM).
- Use menu → "Download Speech Model…" for Parakeet (~500–600 MB, one-time).
- Models cache under Application Support (FluidAudio), not inside this .app.
EOF

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>app.fastflow.macos</string>
  <key>CFBundleName</key>
  <string>FastFlow</string>
  <key>CFBundleDisplayName</key>
  <string>FastFlow</string>
  <key>CFBundleExecutable</key>
  <string>FastFlow</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>FastFlow records audio while you hold the push-to-talk hotkey to transcribe speech locally.</string>
  <key>FastFlowSlimPackage</key>
  <true/>
</dict>
</plist>
PLIST

# Debug entitlements for MVP downloads; ship sandbox is separate.
ENT="$ROOT/entitlements/FastFlow.debug.entitlements"
if [[ -f "$ENT" ]]; then
  codesign --force --deep --sign - --entitlements "$ENT" "$APP" 2>/dev/null || \
    codesign --force --sign - "$APP" 2>/dev/null || true
fi

# Exclude any accidental model caches from the zip.
(
  cd "$DIST"
  ditto -c -k --sequesterRsrc --keepParent FastFlow.app "$(basename "$ZIP")"
)

BYTES=$(wc -c < "$ZIP" | tr -d ' ')
MB=$(echo "scale=2; $BYTES/1024/1024" | bc)
echo ""
echo "Slim artifact: $ZIP ($MB MB)"
echo "Models are NOT included. Users download after install via the menu."
if awk "BEGIN { exit !($MB > 40) }"; then
  echo "WARNING: slim zip is larger than 40 MB — check for bundled models or unstripped deps."
fi
echo "Install: unzip and open FastFlow.app (right-click → Open if Gatekeeper blocks)."
