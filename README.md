# FastFlow

Private push-to-talk dictation for macOS (Apple Silicon first). Hold **Right Option**, speak, release — transcript pastes at the cursor. Models are pluggable; Phase 1 ships Parakeet TDT v3 via FluidAudio / CoreML.

## Requirements

- macOS 14+
- Apple Silicon recommended
- Xcode 16+ (full Xcode — CLT-only SPM is broken on some macOS 26 setups)
- Debug MVP: `entitlements/FastFlow.debug.entitlements` (sandbox off) for hotkey/paste
- Ship path: sandboxed main **without** network (`entitlements/FastFlow.entitlements`)
- Permissions: **Microphone**, **Accessibility** (and often **Input Monitoring**)

## How to run

```bash
cd /Users/shrianshjaiswal/FastFlow

# Default: resolve FluidAudio + build Parakeet path
swift build -c release
swift run FastFlow

# Stub ASR only (no CoreML download) — good for hotkey/paste validation
FASTFLOW_USE_FLUIDAUDIO=0 FASTFLOW_ASR=stub swift run FastFlow
```

Or open `Package.swift` in Xcode → select the `FastFlow` scheme → Run.

Menu bar app uses `NSApplication.ActivationPolicy.accessory` (no Dock icon).

### First-run model download

Parakeet’s first download needs network. Under the ship sandbox that is **denied in the main app**. Until NetworkPluginHost XPC exists, use debug profile + escape:

```bash
FASTFLOW_ALLOW_INPROCESS_NETWORK=1 FASTFLOW_ASR=parakeet swift run FastFlow
```

After models are cached, main-app offline activate is allowed for the trusted Parakeet ID. Offline dictation needs no network entitlement.

## Permissions checklist

1. System Settings → Privacy & Security → **Microphone** → enable FastFlow  
2. System Settings → Privacy & Security → **Accessibility** → enable FastFlow  
3. If the hotkey never fires: Privacy & Security → **Input Monitoring** → enable FastFlow  
4. Hold **Right Option** in Notes / Slack / a browser text field

## Phase 1 status

| Piece | Status |
|---|---|
| Menu bar + icon states | Real |
| Hotkey (Right Option) | Real |
| AVAudioEngine → 16 kHz mono | Real |
| Focus snapshot + InsertionResolver | Real |
| AX / Slack / clipboard insert + confirm UI | Real |
| Paste (clipboard + Cmd+V + restore) | Real (fallback strategy) |
| Plugin protocols + registry | Real |
| Stub ASR | Real |
| Parakeet via FluidAudio | Real (when `FASTFLOW_USE_FLUIDAUDIO` ≠ `0`) |
| Other engines (Moonshine, Whisper, VLM, wake word) | Stubs |
| XPC unload | Documented only |

## Docs

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — process + plugins + future XPC  
- [INSERTION.md](docs/INSERTION.md) — **focus verify + never silently guess**  
- [MEMORY.md](docs/MEMORY.md) — RSS budgets + Instruments checklist  
- [BENCHMARKS.md](docs/BENCHMARKS.md) — **cold-start latency gates** + `FastFlowBench`  
- [PRIVACY.md](docs/PRIVACY.md) — **OS vs software** privacy boundaries (read before claiming guarantees)  
- [MODEL_ZOO.md](docs/MODEL_ZOO.md) — registered engines  
- [CONTRIBUTING.md](CONTRIBUTING.md) — plugin PR checklist  

## Sandbox / network

| Build | Entitlements | Network |
|---|---|---|
| Ship main app | `entitlements/FastFlow.entitlements` | **Denied** (App Sandbox) |
| Network helper | `entitlements/FastFlowNetworkPluginHost.entitlements` | Allowed |
| Local debug MVP | `entitlements/FastFlow.debug.entitlements` | Unrestricted (sandbox off) |

`requiresNetwork` on plug-ins is advisory for UI. OS sandbox + `PluginCapabilityEnforcer` are the gates. Details: [PRIVACY.md](docs/PRIVACY.md).

## Cold-start benchmark

```bash
./scripts/run-cold-start-benchmark.sh stub
# after Xcode + models:
./scripts/run-cold-start-benchmark.sh parakeet
```

See [BENCHMARKS.md](docs/BENCHMARKS.md).

## Sandbox note (MVP)

Phase 1 daily-driver builds may still use the **debug** entitlement profile (non-sandboxed) until NetworkPluginHost XPC lands. Do not notarize that profile as “network-isolated.”
