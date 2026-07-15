# Cloud providers (opt-in plugins)

FastFlow’s **default** path is local free ASR (Parakeet / stub). Cloud plugins exist for users who want stronger or more customized inference.

## Privacy

| Mode | Audio leaves device? |
|---|---|
| Local free / enhanced | **No** (after model cached) |
| Hugging Face / OpenRouter / Gemini | **Yes** — only when that engine is selected |

Never auto-select a cloud engine. Users must pick it in the menu and supply a key.

## Configure keys

Menu bar → **Configure Cloud API Keys…**

| Provider | Where to get a key |
|---|---|
| Hugging Face | https://huggingface.co/settings/tokens |
| OpenRouter | https://openrouter.ai/keys (includes free-tier models) |
| Gemini | https://aistudio.google.com/apikey |

## Swap models

Each cloud engine has a `remoteModelID` / constructor `modelID`. Contributors can register additional factories with different IDs (e.g. a smaller Whisper on HF, or a free OpenRouter slug).

## Network sandbox

Ship builds deny sockets in the main app. Until `NetworkPluginHost` XPC exists, selecting a cloud engine temporarily allows in-process download/network for that activate (same escape as Parakeet first download). Prefer moving cloud ASR into the network helper for production.
