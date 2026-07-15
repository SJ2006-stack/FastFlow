# Model Zoo

Built-in plug-ins registered by `PluginBootstrap.registerBuiltins()`.

## ASR

| ID | Name | Network | Streaming | Status |
|---|---|---|---|---|
| `asr.stub` | Stub ASR | no | no | **Real** — paste-path testing |
| `asr.parakeet.tdt.v3` | Parakeet TDT v3 | first-run download | no | **Real** via FluidAudio |
| `asr.moonshine` | Moonshine Tiny | no | no | Stub |
| `asr.whispercpp` | whisper.cpp | no | no | Stub |

## VAD

| ID | Name | Status |
|---|---|---|
| `vad.energy` | Energy VAD | **Real** (RMS threshold) |
| `vad.silero` | Silero VAD | Stub (delegates to energy) |

## Wake word

| ID | Name | Status |
|---|---|---|
| `wake.openwakeword` | OpenWakeWord | Stub |
| `wake.porcupine` | Porcupine | Stub (`requiresNetwork`) |

## Screen

| ID | Name | Status |
|---|---|---|
| `screen.vlm.quantized` | Quantized VLM | Stub |

## Bias

| ID | Name | Status |
|---|---|---|
| `bias.memory` | In-Memory Bias List | **Real** |
| `bias.sqlite` | SQLite Bias List | **Real** (JSON file skeleton under Application Support) |

## Community drop-ins

Place a folder under `fastflow-plugins/community/<plugin-id>/` with `plugin.json`:

```json
{
  "id": "asr.community.example",
  "name": "Community Example ASR",
  "kind": "asr",
  "version": "0.1.0",
  "summary": "Example community manifest.",
  "approxActiveMemoryMB": 100,
  "requiresNetwork": false,
  "supportsStreaming": false,
  "isBuiltin": false
}
```

Phase 1 registers metadata + a stub factory. See `CONTRIBUTING.md` for the PR checklist.
