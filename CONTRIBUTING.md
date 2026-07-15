# Contributing

## Plugin PR checklist

Before opening a PR that adds or changes a model plug-in:

1. **Protocol conformance** — implement the correct protocol (`ASREngine`, `VoiceActivityDetector`, `WakeWordDetector`, `ScreenContextParser`, or `BiasListStore`) plus `FastFlowPlugin`.
2. **Lazy-load** — no model I/O or network in `init()`. Heavy work only in `activate()`.
3. **Unload** — `deactivate()` must drop references so RSS can fall (verify with Instruments if possible).
4. **Footprint** — set honest `approxActiveMemoryMB` on the `PluginManifest`; update `docs/MEMORY.md` / `docs/MODEL_ZOO.md`.
5. **Network flag (advisory)** — set `requiresNetwork = true` if first-run download or online inference is required so the UI can warn. **This flag is not the security boundary.**
6. **OS sandbox (real gate)** — networked plug-ins must run only under `NetworkPluginHost` / `entitlements/FastFlowNetworkPluginHost.entitlements`. Main app uses `entitlements/FastFlow.entitlements` (**no** `network.client`). `PluginCapabilityEnforcer` refuses main-process activate for networked IDs (except trusted offline-cached ASR).
7. **Registration** — register a factory in `PluginBootstrap` (built-in) or ship `fastflow-plugins/community/<id>/plugin.json`.
8. **No core policy forks** — do not move idle-timeout, privacy indicator, raw media retention, capability enforcement, or **insertion resolution** (`InsertionResolver` / never-silently-guess) into the plug-in.
9. **Privacy honesty** — screen/audio retention claims must match `docs/PRIVACY.md` (in-process plug-ins can retain buffers unless isolated).
10. **Benchmarks** — ASR changes should note impact on `docs/BENCHMARKS.md` cold-start gates; run `swift run FastFlowBench` when possible.
11. **Tests** — unit test construct + activate contracts; capability denial for fake networked plug-ins in `.mainApp`.
12. **License** — model + code licenses must be compatible with Apache-2.0 / MIT-style redistribution.

## Local stub build

```bash
cp Package.stub.swift Package.swift
swift test
swift run FastFlowBench
FASTFLOW_ASR=stub swift run FastFlow
```

## Insertion adapters

App-specific text insertion: `Sources/FastFlow/Insertion/Strategies/`. Register early in `InsertionRouter` (before default AX / clipboard).

- Obey `InsertionResolver` — never auto-insert on `.ambiguous` / `.unavailable`
- Wake-word + unknown focus must always confirm
- Prefer clipboard when Electron AX is unreliable (see `SlackInsertionAdapter`)
- Document quirks in `docs/INSERTION.md`

## Code layout

- `Sources/FastFlow/` — app shell (hotkey, audio, insertion, UI, core policies)
- `Sources/FastFlowPlugins/` — protocols, types, registry, engines, `InsertionResolver`, capability enforcer, benchmarks
- `Sources/FastFlowBench/` — CLI cold-start harness
- `entitlements/` — sandbox profiles
- `fastflow-plugins/community/` — drop-in manifests
- `docs/PRIVACY.md`, `docs/BENCHMARKS.md`, `docs/INSERTION.md`
