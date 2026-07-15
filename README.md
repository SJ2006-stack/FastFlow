# FastFlow

Private push-to-talk dictation for macOS. Hold **Right Option**, speak, release — text lands where you’re typing (when focus is verified).

**Hotkey only** — there is no wake word. Dictation starts when you press and hold **Right Option**.

**Local FREE by default** — first launch asks which model to use (FREE on-device vs BYO). Optional cloud / custom endpoints for higher accuracy. Developers treat FastFlow as a **framework interface** and fuse their own `ASREngine`.

## Download for Mac

**[⬇ Download FastFlow.dmg](https://github.com/SJ2006-stack/FastFlow/releases/latest/download/FastFlow.dmg)**

Click → Safari downloads the installer. Then:

1. Open the DMG  
2. Drag **FastFlow** into **Applications**  
3. Open it (right-click → **Open** the first time if macOS asks)  
4. **Choose a model** — FREE local (recommended) or BYO  
5. Grant **Microphone** + **Accessibility**  
6. Hold **Right Option** to dictate  

More: [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) · [docs/FRAMEWORK.md](docs/FRAMEWORK.md) · [Releases](https://github.com/SJ2006-stack/FastFlow/releases)

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
- [FRAMEWORK.md](docs/FRAMEWORK.md) — fuse your own models (BYO / ASREngine)  
- [MODEL_ZOO.md](docs/MODEL_ZOO.md) — FREE vs BYO catalog  
- [PROVIDERS.md](docs/PROVIDERS.md) — Hugging Face / OpenRouter / Gemini keys  
- [CONTRIBUTING.md](CONTRIBUTING.md)  
