# Distribution — slim download

FastFlow ships as a **slim** macOS app: the download is just the menu-bar binary. Speech models are **not** in the zip.

## Why

| Package | Approx size | RAM on first launch |
|---|---|---|
| Slim `.app` zip | typically a few MB (target **&lt; 30 MB**) | ~20–40 MB (stub engine) |
| Parakeet CoreML models | ~500–600 MB **one-time**, after install | ~250–400 MB while dictating |

Bundling models in the GitHub download would make every install heavy and slow. Lazy download keeps “get FastFlow” smooth; users opt into the model when ready.

## User flow

1. Download `FastFlow-slim-macos-arm64.zip` from [Releases](https://github.com/SJ2006-stack/FastFlow/releases).
2. Unzip → open `FastFlow.app` (Gatekeeper: right-click → Open the first time).
3. Grant Microphone + Accessibility (+ Input Monitoring if the hotkey fails).
4. Dictate immediately with the **stub** engine (path check), **or**
5. Menu → **Download Speech Model…** → Parakeet caches once under Application Support.
6. Later launches stay offline for ASR (no network needed if models are cached).

## Build locally

```bash
./scripts/make-slim-release.sh release
# → dist/FastFlow-slim-macos-arm64.zip
```

Requires full Xcode. Never copy FluidAudio / Hugging Face caches into `FastFlow.app`.

## CI

`.github/workflows/release-slim.yml` builds the slim zip on tag `v*` and attaches it to the GitHub Release.

## What must never ship inside the .app

- `*.mlmodelc` / `*.mlpackage`
- Hugging Face / FluidAudio cache trees
- Python / conda environments
- Unrelated research checkpoints

`scripts/make-slim-release.sh` writes `Contents/Resources/SLIM_PACKAGE.txt` as a marker and warns if the zip exceeds ~40 MB.
