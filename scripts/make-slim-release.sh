#!/usr/bin/env bash
# Build a slim FastFlow.app inside a classic Mac installer .dmg
# (drag FastFlow → Applications). Models are NEVER bundled.
#
# Target: DMG well under ~30 MB for a one-click Safari download from GitHub Releases.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
DIST="$ROOT/dist"
APP="$DIST/FastFlow.app"
STAGE="$DIST/dmg-root"
DMG="$DIST/FastFlow.dmg"
DMG_RW="$DIST/FastFlow.rw.dmg"

echo "==> Slim Mac installer DMG (config=$CONFIG) — no CoreML models"

rm -rf "$DIST"
mkdir -p "$DIST" "$STAGE"

if [[ -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift build -c "$CONFIG"
BIN="$ROOT/.build/$CONFIG/FastFlow"
test -x "$BIN"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/FastFlow"
if command -v strip >/dev/null; then
  strip -x "$APP/Contents/MacOS/FastFlow" || true
fi

cat > "$APP/Contents/Resources/SLIM_PACKAGE.txt" <<'EOF'
FastFlow slim package
- No ASR / CoreML models are included in this DMG.
- First launch uses a tiny stub engine (low RAM).
- Menu → "Download Speech Model…" for Parakeet (~500–600 MB, one-time).
- Models cache under Application Support — not inside this .app.
EOF

# Simple document icon placeholder isn't required; system will use generic app icon.
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
  <string>0.1.1</string>
  <key>CFBundleVersion</key>
  <string>2</string>
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

# Ad-hoc sign for local/CI MVP (notarization comes later for Gatekeeper-friendly opens).
ENT="$ROOT/entitlements/FastFlow.debug.entitlements"
if [[ -f "$ENT" ]]; then
  codesign --force --deep --sign - --entitlements "$ENT" "$APP" 2>/dev/null || \
    codesign --force --sign - "$APP" 2>/dev/null || true
fi

# Classic installer layout: app + Applications alias.
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/FastFlow.app"
ln -s /Applications "$STAGE/Applications"

# Optional HOW_TO_INSTALL text users see in the Finder window.
cat > "$STAGE/How to Install.txt" <<'EOF'
Install FastFlow

1. Drag FastFlow into the Applications folder.
2. Open Applications → FastFlow (right-click → Open the first time if macOS asks).
3. Grant Microphone and Accessibility when prompted.
4. Hold Right Option to dictate.
5. Optional: menu bar → Download Speech Model… (one-time, ~500–600 MB).

Speech models are not in this DMG — that keeps the download small.
EOF

# Create compressed read-only DMG (Safari / GitHub Releases friendly).
rm -f "$DMG" "$DMG_RW"
hdiutil create \
  -volname "FastFlow" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG"

# Ad-hoc sign the DMG itself (helps a little; full notarization is still required for zero Gatekeeper friction).
codesign --force --sign - "$DMG" 2>/dev/null || true

BYTES=$(wc -c < "$DMG" | tr -d ' ')
MB=$(python3 -c "print(round($BYTES/1024/1024, 2))")
echo ""
echo "Mac installer: $DMG ($MB MB)"
echo "Install vibe: open DMG → drag FastFlow → Applications"
echo "One-click URL (after release): https://github.com/SJ2006-stack/FastFlow/releases/latest/download/FastFlow.dmg"
if python3 -c "import sys; sys.exit(0 if $BYTES > 40*1024*1024 else 1)"; then
  echo "WARNING: DMG is larger than 40 MB — check for bundled models."
fi
