# FastFlow as a framework interface

FastFlow is the **dictation shell** (hotkey → audio → insert). Models are pluggable.

## Product promise

| Tier | Label in UI | Who it’s for |
|---|---|---|
| **FREE** | `FREE — local` | Everyone — Parakeet / stub on-device, private, low RAM |
| **BYO** | `BYO — …` | Power users & developers — your API or HTTPS endpoint for higher accuracy |

First launch always asks which path to use. Users can reopen **Change Model…** anytime.

## For end users

1. Install `FastFlow.dmg` → drag to Applications  
2. On first open: pick **FREE — Parakeet** (recommended) or **BYO**  
3. Hold **Right Option** to dictate  

## For developers (fuse your own model)

### Option A — BYO HTTPS endpoint (no code)

Menu → **Add BYO Model…**

- Endpoint must accept `audio/wav` **or** JSON `{"audio_base64","model"}`  
- Respond with JSON `{"text":"..."}` or `{"transcript":"..."}`  
- Optional Bearer API key (Keychain)

### Option B — Implement `ASREngine` in-process

```swift
import FastFlowPlugins

final class MyTeamASR: ASREngine, @unchecked Sendable {
    let manifest = PluginManifest(
        id: "asr.myteam.v1",
        name: "MyTeam ASR",
        kind: .asr,
        summary: "Our fine-tuned model",
        approxActiveMemoryMB: 200,
        requiresNetwork: false,
        inferenceTier: .localEnhanced, // or .cloudPlugin
        providerFamily: .custom
    )
    private(set) var isActive = false

    func activate() async throws { /* load weights */ isActive = true }
    func deactivate() async { isActive = false }
    func transcribe(_ samples: [Float]) async throws -> String {
        // 16 kHz mono Float32 → your inference
        "…"
    }
}

// At app launch (or in your host app):
PluginRegistry.shared.registerASR { MyTeamASR() }
ModelSelectionStore.selectedASRID = "asr.myteam.v1"
```

### Option C — Community `plugin.json`

Drop manifests under `fastflow-plugins/community/` — see `CONTRIBUTING.md`.

## What stays in core (not yours to reimplement)

- Hotkey / push-to-talk  
- Focus-verified text insertion  
- Idle unload / privacy indicator  
- Model picker + FREE vs BYO labeling  

You only fuse **models**. FastFlow is the interface.
