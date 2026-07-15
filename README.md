# FastFlow

Private push-to-talk dictation for macOS (Apple Silicon first). Hold **Right Option**, speak, release — transcript pastes at the cursor when focus is verified.

## Slim download (recommended)

The GitHub Release zip is **app-only** — no CoreML models — so it downloads quickly and stays small (target **&lt; 30 MB**).

1. Get `FastFlow-slim-macos-arm64.zip` from [Releases](https://github.com/SJ2006-stack/FastFlow/releases)
2. Open `FastFlow.app` (right-click → Open if Gatekeeper asks)
3. Grant **Microphone** + **Accessibility**
4. Optional: menu → **Download Speech Model…** (~500–600 MB once) for Parakeet
5. Until then, a tiny **stub** engine keeps RAM low so you can still test hotkey / paste

Details: [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)

## Requirements

- macOS 14+
- Apple Silicon recommended
- Xcode 16+ to build from source (full Xcode — CLT-only SPM is broken on some macOS 26 setups)
- Debug MVP: `entitlements/FastFlow.debug.entitlements` (sandbox off) for hotkey/paste
- Ship path: sandboxed main **without** network (`entitlements/FastFlow.entitlements`)

## How to run (from source)

```bash
cd ~/FastFlow

# Default: auto backend (stub until models cached — slim-friendly)
swift build -c release
swift run FastFlow

# Force stub only
FASTFLOW_ASR=stub swift run FastFlow

# Slim zip for distribution
./scripts/make-slim-release.sh release
```

Or open `Package.swift` in Xcode → select the `FastFlow` scheme → Run.

Menu bar app uses `NSApplication.ActivationPolicy.accessory` (no Dock icon).

### First-run model download

Parakeet’s first download needs network. Prefer menu → **Download Speech Model…** (user-initiated).  
Until NetworkPluginHost XPC exists, that path temporarily allows in-process download.  
CLI escape: `FASTFLOW_ALLOW_INPROCESS_NETWORK=1 FASTFLOW_ASR=parakeet swift run FastFlow`

After models are cached, ASR works offline. Models live in Application Support — **never** inside the slim `.app`.

## Permissions checklist

1. System Settings → Privacy & Security → **Microphone** → enable FastFlow  
2. System Settings → Privacy & Security → **Accessibility** → enable FastFlow  
3. If the hotkey never fires: Privacy & Security → **Input Monitoring** → enable FastFlow  
4. Hold **Right Option** in Notes / Slack / a browser text field

## Phase 1 status

| Piece | Status |
|---|---|
| Slim download (no models in zip) | Real |
| Menu bar + icon states | Real |
| Hotkey (Right Option) | Real |
| AVAudioEngine → 16 kHz mono | Real |
| Focus snapshot + InsertionResolver | Real |
| AX / Slack / clipboard insert + confirm UI | Real |
| Paste (clipboard + Cmd+V + restore) | Real (fallback strategy) |
| Plugin protocols + registry | Real |
| Stub ASR (default until model download) | Real |
| Parakeet via FluidAudio | Real (after Download Speech Model…) |
| Other engines (Moonshine, Whisper, VLM, wake word) | Stubs |
| XPC unload | Documented only |

## Docs

- [DISTRIBUTION.md](docs/DISTRIBUTION.md) — **slim zip / smooth download**  
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — process + plugins + future XPC  
- [INSERTION.md](docs/INSERTION.md) — focus verify + never silently guess  
- [MEMORY.md](docs/MEMORY.md) — RSS budgets + Instruments checklist  
- [BENCHMARKS.md](docs/BENCHMARKS.md) — cold-start latency gates + `FastFlowBench`  
- [PRIVACY.md](docs/PRIVACY.md) — OS vs software privacy boundaries  
- [MODEL_ZOO.md](docs/MODEL_ZOO.md) — registered engines  
- [CONTRIBUTING.md](CONTRIBUTING.md) — plugin PR checklist  

## Sandbox / network

| Build | Entitlements | Network |
|---|---|---|
| Ship main app | `entitlements/FastFlow.entitlements` | **Denied** (App Sandbox) |
| Network helper | `entitlements/FastFlowNetworkPluginHost.entitlements` | Allowed |
| Local debug MVP | `entitlements/FastFlow.debug.entitlements` | Unrestricted (sandbox off) |

`requiresNetwork` on plug-ins is advisory for UI. OS sandbox + `PluginCapabilityEnforcer` are the gates. Details: [PRIVACY.md](docs/PRIVACY.md).
