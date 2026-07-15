# Architecture

## Phase 1 — single process

```
CGEventTap (Right Option) or wake word (later)
  → capture FocusSnapshot (Option A) + TriggerSource into DictationSessionContext
  → AudioCapture (AVAudioEngine → 16 kHz mono Float32)
  → ASREngine (ParakeetTDTEngine | StubASREngine | …)
  → InsertionRouter (re-query focus Option B → InsertionResolver)
       → verified → AX / Slack / clipboard strategy
       → ambiguous|unavailable → confirmation panel (never silent guess)
```

Menu bar UI (`StatusItemController`) reflects `idle` / `listening` / `transcribing` / `error` / `loading`.

`DictationSession` owns the utterance buffer, privacy indicator, idle-unload scheduler, and insertion router. Raw PCM is discarded after transcription (**software policy** — see `docs/PRIVACY.md`).

Text insertion details: `docs/INSERTION.md`.

Cold-start timings after idle unload: `docs/BENCHMARKS.md` + `FastFlowBench`.

## Plug-in architecture

FastFlow separates the **app shell** from **models**. Every model-driven stage is a Swift protocol under `Sources/FastFlowPlugins/`.

### Principles

1. **Lazy-load** — no weights until `activate()` / `load()`
2. **Network** — `requiresNetwork` is **advisory for UI**; **OS App Sandbox** is the real gate (main app has no `network.client`)
3. **Release on idle** — `deactivate()` / `unload()` must free real memory
4. **Report footprint** — `approxActiveMemoryMB` on every `PluginManifest`

### Capability enforcement

| Layer | Role |
|---|---|
| `PluginManifest.requiresNetwork` | UI warning / Model Zoo badge |
| `PluginCapabilityEnforcer` | Refuses to activate networked plug-ins in `.mainApp` unless trusted offline cache or debug escape |
| `NetworkPluginHost` | Only process role that may download / run networked plug-ins |
| `entitlements/FastFlow.entitlements` | Sandbox ON, **no** outbound network |
| `entitlements/FastFlowNetworkPluginHost.entitlements` | Sandbox ON, **with** `network.client` |
| `entitlements/FastFlow.debug.entitlements` | Sandbox OFF — local PTT MVP only |

A plug-in that lies `requiresNetwork = false` still cannot open sockets in a properly signed main app. See `docs/PRIVACY.md`.

### Protocols

| Protocol | Role |
|---|---|
| `WakeWordDetector` | Optional always-on wake (stubbed in Phase 1; PTT hotkey is core) |
| `VoiceActivityDetector` | Speech gate (`EnergyVADDetector` real; Silero stub) |
| `ASREngine` | Speech-to-text (`SpeechRecognizer` typealias) |
| `ScreenContextParser` | Field / UI understanding (stub) |
| `BiasListStore` | Correction / boost vocabulary |
| `FastFlowPlugin` | Shared activate/deactivate + manifest |

Shared types: `AudioFrame`, `TranscriptPartial`, `BiasedWord`, `AudioFingerprint`, `CapturedFrame`, `ScreenContext`, `FieldType`, `PluginManifest`, `PluginKind`.

### Registration / Model Zoo

`PluginBootstrap.registerBuiltins()` registers factories into `PluginRegistry`. Settings / menu **List Model Zoo** reads manifests without knowing concrete types.

Community drop-ins live in `fastflow-plugins/community/<name>/plugin.json`. Phase 1 loads **metadata** (and stub factories); shipping dynamic bundles is later.

### What stays in CORE (not pluggable)

- Idle-timeout / unload scheduler (`IdleUnloadScheduler`)
- Privacy indicator for mic / screen capture (`PrivacyIndicator`)
- Raw audio / pixel retention policy (`RawMediaRetentionPolicy`) — **software policy**
- Hotkey tap, TCC permission prompts
- **Insertion resolution policy** (`InsertionResolver`) — never silently guess; confirmation UI is mandatory on ambiguity
- `PluginCapabilityEnforcer` / process sandbox role

Per-app **insertion adapters** are pluggable (`TextInsertionStrategy`); the resolve rules above are not.

## Phase 2 — XPC process split (design only; not implemented)

After Phase 1 is daily-usable, Instruments numbers exist in `MEMORY.md`, and cold-start gates in `BENCHMARKS.md` pass.

```
FastFlow.app (menu bar; sandbox, no network)
  │  NSXPCConnection
  ├── FastFlowEngine.xpc          (ASR, optional VAD; no network)
  └── FastFlowNetworkPluginHost   (model download / networked plugins only)
```

### Design sketch

- **UI process:** hotkey, mic permission UX, paste, icon — never loads CoreML; **no network entitlement**.
- **Engine XPC:** owns `ASREngine`; prefer **capture in UI, send PCM** over XPC so TCC prompts stay on the main app.
- **Network host XPC:** first-run HF download, Porcupine, any `requiresNetwork` plug-in.
- **Idle unload:** UI invalidates the engine connection after 30–60s; engine unloads models and exits.
- **Memory gate:** idle RSS of `FastFlow.app` alone must hit **50–80 MB**.
- **Screen parse (later):** capture+parse in XPC returning **only** `ScreenContext` (no raw frames to main/plugins) — see `docs/PRIVACY.md`.

Do not start XPC implementation until the single-process MVP feels usable **and** cold-start numbers are measured.

## Phase 3+ (parked)

- ScreenCaptureKit → `ScreenContextParser` (with XPC parse-only boundary)
- Rich bias UI on `BiasListStore`
- Moonshine Tiny if Parakeet fails the active RAM or cold-start gate
