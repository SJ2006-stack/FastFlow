# FastFlow

Private push-to-talk dictation for macOS. Hold **Right Option**, speak, release — text lands where you’re typing (when focus is verified).

**Hotkey only** — there is no wake word or “Hey FastFlow.” Dictation starts when you press and hold the hotkey.

## Download for Mac

**[⬇ Download FastFlow.dmg](https://github.com/SJ2006-stack/FastFlow/releases/latest/download/FastFlow.dmg)**

Click → Safari downloads the installer. Then:

1. Open the DMG  
2. Drag **FastFlow** into **Applications**  
3. Open it from Applications (right-click → **Open** the first time if macOS asks)  
4. Grant **Microphone** + **Accessibility**  
5. Hold **Right Option** to dictate  

Optional later: menu bar → **Download Speech Model…** (~500–600 MB once). The DMG stays small on purpose — no models inside.

More: [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) · [Releases](https://github.com/SJ2006-stack/FastFlow/releases)

---

## Requirements (from source)

- macOS 14+ / Apple Silicon recommended  
- Xcode 16+ to build (full Xcode — CLT-only SPM breaks on some macOS 26 setups)

## Build from source

```bash
cd ~/FastFlow
swift build -c release && swift run FastFlow

# Classic Mac installer DMG
./scripts/make-slim-release.sh release
open dist/FastFlow.dmg
```

Default backend is **auto**: tiny stub until models are cached (slim-friendly).

## Permissions

1. System Settings → Privacy & Security → **Microphone**  
2. **Accessibility** (and **Input Monitoring** if the hotkey never fires)  
3. Hold **Right Option** in Notes / Slack / a browser field  

## Docs

- [DISTRIBUTION.md](docs/DISTRIBUTION.md) — DMG / Safari download  
- [ARCHITECTURE.md](docs/ARCHITECTURE.md)  
- [INSERTION.md](docs/INSERTION.md)  
- [MEMORY.md](docs/MEMORY.md)  
- [BENCHMARKS.md](docs/BENCHMARKS.md)  
- [PRIVACY.md](docs/PRIVACY.md)  
- [MODEL_ZOO.md](docs/MODEL_ZOO.md)  
- [CONTRIBUTING.md](CONTRIBUTING.md)  
