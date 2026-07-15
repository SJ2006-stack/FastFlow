# Distribution — Mac `.dmg` (slim)

FastFlow ships as a normal Mac installer disk image: open the DMG, drag **FastFlow** into **Applications**. Speech models are **not** inside the DMG.

## One-click download (Safari)

After a release is published:

**https://github.com/SJ2006-stack/FastFlow/releases/latest/download/FastFlow.dmg**

That URL starts a direct download in Safari (same pattern as most Mac apps on GitHub).

Releases page: [github.com/SJ2006-stack/FastFlow/releases](https://github.com/SJ2006-stack/FastFlow/releases)

## Install vibe

1. Click the `.dmg` link → Safari downloads `FastFlow.dmg`
2. Open the DMG
3. Drag **FastFlow** → **Applications**
4. Eject the disk image
5. Launch from Applications (first launch: right-click → **Open** if Gatekeeper blocks ad-hoc builds)
6. Grant Microphone + Accessibility
7. Optional: menu → **Download Speech Model…** (~500–600 MB once)

## Why slim

| Package | Approx size | First-launch RAM |
|---|---|---|
| `FastFlow.dmg` (app only) | typically a few MB (target **&lt; 30 MB**) | ~20–40 MB (stub) |
| Parakeet models | ~500–600 MB **after** install | ~250–400 MB while dictating |

## Build locally

```bash
./scripts/make-slim-release.sh release
# → dist/FastFlow.dmg
open dist/FastFlow.dmg
```

Requires full Xcode. Never copy FluidAudio / Hugging Face caches into the `.app`.

## CI

`.github/workflows/release-slim.yml` builds `FastFlow.dmg` on tag `v*` and attaches it as the primary release asset.

## Gatekeeper note

Ad-hoc signed CI builds may still show “unidentified developer.” Users right-click → Open once. Full **Developer ID + notarization** removes that friction for public ship.

## Never ship inside the DMG

- `*.mlmodelc` / `*.mlpackage`
- Hugging Face / FluidAudio caches
- Python environments
