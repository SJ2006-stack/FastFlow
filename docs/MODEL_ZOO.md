# Model Zoo

FastFlow is **local-first**. Out of the box you get free on-device models. Cloud engines are **optional plugins** for better or more customized inference (Hugging Face, OpenRouter, Gemini, …).

Dictation always starts with the **Right Option** hotkey.

## Default: local free

| ID | Name | Network | Status |
|---|---|---|---|
| `asr.stub` | Stub ASR | no | **Real** — path testing |
| `asr.parakeet.tdt.v3` | Parakeet TDT v3 | first-run download only | **Real** via FluidAudio / CoreML |
| `asr.moonshine` | Moonshine Tiny | no | Stub (local free fallback) |

Menu → **Download Parakeet (local)…** caches weights once; then ASR is offline and free.

## Local enhanced

| ID | Name | Status |
|---|---|---|
| `asr.whispercpp` | whisper.cpp | Stub — community CoreML/Metal target |

## Cloud plugins (opt-in)

Bring your own API key. Audio leaves the device only when you select a cloud engine.

| ID | Provider | Default remote model | Status |
|---|---|---|---|
| `asr.cloud.huggingface` | Hugging Face Inference | `openai/whisper-large-v3` | **Real** HTTP |
| `asr.cloud.openrouter` | OpenRouter | `openai/gpt-4o-audio-preview` | **Real** HTTP |
| `asr.cloud.gemini` | Google Gemini | `gemini-2.0-flash` | **Real** HTTP |

1. Menu → **Configure Cloud API Keys…**
2. Pick an engine under **Cloud plugins**
3. Hold Right Option to dictate

Keys are stored in Keychain (with UserDefaults fallback). See [PROVIDERS.md](PROVIDERS.md).

## VAD / Screen / Bias

Unchanged — see registry manifests (`vad.*`, `screen.*`, `bias.*`).

## Community drop-ins

`fastflow-plugins/community/<id>/plugin.json` — set `"inferenceTier": "cloudPlugin"` and `"providerFamily": "custom"` for remote community engines. See `CONTRIBUTING.md`.
