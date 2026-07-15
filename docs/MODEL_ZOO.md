# Model Zoo

FastFlow is a **dictation interface**. Models plug in.

On first launch the app asks which model to use. **FREE** = on-device. **BYO** = your API or custom endpoint for higher accuracy.

## FREE — local (default)

| ID | Name | Status |
|---|---|---|
| `asr.parakeet.tdt.v3` | FREE — Parakeet TDT v3 | **Real** CoreML (download once) |
| `asr.stub` | FREE — Stub | **Real** path testing |
| `asr.moonshine` | FREE — Moonshine Tiny | Stub slot |

## BYO — higher accuracy / custom

| ID | Name | Status |
|---|---|---|
| `asr.cloud.huggingface` | BYO — Hugging Face | **Real** HTTP |
| `asr.cloud.openrouter` | BYO — OpenRouter | **Real** HTTP |
| `asr.cloud.gemini` | BYO — Gemini | **Real** HTTP |
| `asr.byo.*` | BYO — Custom HTTPS | **Real** (user-defined) |

Menu → **Add BYO Model…** or **Change Model…**. Developers: [FRAMEWORK.md](FRAMEWORK.md).

## VAD / Screen / Bias

Unchanged — see registry manifests.
