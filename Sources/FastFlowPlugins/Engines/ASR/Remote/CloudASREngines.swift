import Foundation

/// Cloud ASR plug-ins — opt-in for better / customized inference.
/// Default FastFlow path stays **local free** (Parakeet / Moonshine / stub).
///
/// These engines require:
/// 1. User API key in ModelSelectionStore
/// 2. Network capability (main app debug escape or NetworkPluginHost)
/// 3. Explicit Model Zoo selection (never auto-default)

// MARK: - Hugging Face Inference API

public final class HuggingFaceASREngine: ASREngine, @unchecked Sendable {
    public static let manifestID = "asr.cloud.huggingface"
    public static let defaultModel = "openai/whisper-large-v3"

    public let manifest = PluginManifest(
        id: manifestID,
        name: "Hugging Face Whisper",
        kind: .asr,
        summary: "Cloud — Hugging Face Inference API (Whisper). Bring your HF token.",
        approxActiveMemoryMB: 20,
        requiresNetwork: true,
        inferenceTier: .cloudPlugin,
        providerFamily: .huggingface,
        remoteModelID: defaultModel
    )

    public private(set) var isActive = false
    public var modelID: String

    public init(modelID: String = HuggingFaceASREngine.defaultModel) {
        self.modelID = modelID
    }

    public func activate() async throws {
        let enforcer = PluginCapabilityEnforcer()
        try enforcer.assertCanActivate(manifest, modelsCached: false)
        guard ModelSelectionStore.hasAPIKey(for: .huggingface) else {
            throw ASREngineError.underlying(
                "Add a Hugging Face token: menu → Configure Cloud API Keys…"
            )
        }
        isActive = true
    }

    public func deactivate() async { isActive = false }

    public func transcribe(_ samples: [Float]) async throws -> String {
        guard isActive else { throw ASREngineError.notLoaded(name: name) }
        guard !samples.isEmpty else { throw ASREngineError.emptyAudio }
        guard let token = ModelSelectionStore.apiKey(for: .huggingface) else {
            throw ASREngineError.underlying("Missing Hugging Face API token.")
        }

        let wav = WAVEncoder.encodeMono16kHz(samples)
        let encoded = modelID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modelID
        let url = URL(string: "https://api-inference.huggingface.co/models/\(encoded)")!
        let (data, http) = try await RemoteASRHTTP.post(
            url: url,
            headers: ["Authorization": "Bearer \(token)"],
            body: wav,
            contentType: "audio/wav"
        )
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ASREngineError.underlying("Hugging Face HTTP \(http.statusCode): \(body.prefix(200))")
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = obj["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let text = arr.first?["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw ASREngineError.underlying("Unexpected Hugging Face response.")
    }
}

// MARK: - OpenRouter

public final class OpenRouterASREngine: ASREngine, @unchecked Sendable {
    public static let manifestID = "asr.cloud.openrouter"
    /// OpenRouter model that accepts audio input (adjustable).
    public static let defaultModel = "openai/gpt-4o-audio-preview"

    public let manifest = PluginManifest(
        id: manifestID,
        name: "OpenRouter Audio",
        kind: .asr,
        summary: "Cloud — OpenRouter (free & paid models). Bring your OpenRouter key.",
        approxActiveMemoryMB: 15,
        requiresNetwork: true,
        inferenceTier: .cloudPlugin,
        providerFamily: .openrouter,
        remoteModelID: defaultModel
    )

    public private(set) var isActive = false
    public var modelID: String

    public init(modelID: String = OpenRouterASREngine.defaultModel) {
        self.modelID = modelID
    }

    public func activate() async throws {
        let enforcer = PluginCapabilityEnforcer()
        try enforcer.assertCanActivate(manifest, modelsCached: false)
        guard ModelSelectionStore.hasAPIKey(for: .openrouter) else {
            throw ASREngineError.underlying(
                "Add an OpenRouter API key: menu → Configure Cloud API Keys…"
            )
        }
        isActive = true
    }

    public func deactivate() async { isActive = false }

    public func transcribe(_ samples: [Float]) async throws -> String {
        guard isActive else { throw ASREngineError.notLoaded(name: name) }
        guard !samples.isEmpty else { throw ASREngineError.emptyAudio }
        guard let token = ModelSelectionStore.apiKey(for: .openrouter) else {
            throw ASREngineError.underlying("Missing OpenRouter API key.")
        }

        let wav = WAVEncoder.encodeMono16kHz(samples)
        let b64 = wav.base64EncodedString()
        let payload: [String: Any] = [
            "model": modelID,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Transcribe this audio to plain text only. No commentary.",
                        ],
                        [
                            "type": "input_audio",
                            "input_audio": [
                                "data": b64,
                                "format": "wav",
                            ],
                        ],
                    ],
                ],
            ],
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        let (data, http) = try await RemoteASRHTTP.post(
            url: url,
            headers: [
                "Authorization": "Bearer \(token)",
                "HTTP-Referer": "https://github.com/SJ2006-stack/FastFlow",
                "X-Title": "FastFlow",
            ],
            body: body,
            contentType: "application/json"
        )
        guard (200..<300).contains(http.statusCode) else {
            let err = String(data: data, encoding: .utf8) ?? ""
            throw ASREngineError.underlying("OpenRouter HTTP \(http.statusCode): \(err.prefix(240))")
        }
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else {
            throw ASREngineError.underlying("Unexpected OpenRouter response.")
        }
        if let text = message["content"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Some models return content as array of parts.
        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { $0["text"] as? String }.joined()
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw ASREngineError.underlying("OpenRouter response had no text content.")
    }
}

// MARK: - Google Gemini

public final class GeminiASREngine: ASREngine, @unchecked Sendable {
    public static let manifestID = "asr.cloud.gemini"
    public static let defaultModel = "gemini-2.0-flash"

    public let manifest = PluginManifest(
        id: manifestID,
        name: "Google Gemini",
        kind: .asr,
        summary: "Cloud — Gemini API audio understanding. Bring your Google AI Studio key.",
        approxActiveMemoryMB: 15,
        requiresNetwork: true,
        inferenceTier: .cloudPlugin,
        providerFamily: .gemini,
        remoteModelID: defaultModel
    )

    public private(set) var isActive = false
    public var modelID: String

    public init(modelID: String = GeminiASREngine.defaultModel) {
        self.modelID = modelID
    }

    public func activate() async throws {
        let enforcer = PluginCapabilityEnforcer()
        try enforcer.assertCanActivate(manifest, modelsCached: false)
        guard ModelSelectionStore.hasAPIKey(for: .gemini) else {
            throw ASREngineError.underlying(
                "Add a Gemini API key: menu → Configure Cloud API Keys…"
            )
        }
        isActive = true
    }

    public func deactivate() async { isActive = false }

    public func transcribe(_ samples: [Float]) async throws -> String {
        guard isActive else { throw ASREngineError.notLoaded(name: name) }
        guard !samples.isEmpty else { throw ASREngineError.emptyAudio }
        guard let key = ModelSelectionStore.apiKey(for: .gemini) else {
            throw ASREngineError.underlying("Missing Gemini API key.")
        }

        let wav = WAVEncoder.encodeMono16kHz(samples)
        let b64 = wav.base64EncodedString()
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "text": "Transcribe this audio to plain text only. No commentary.",
                        ],
                        [
                            "inline_data": [
                                "mime_type": "audio/wav",
                                "data": b64,
                            ],
                        ],
                    ],
                ],
            ],
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let encoded = modelID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modelID
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encoded):generateContent?key=\(key)")!
        let (data, http) = try await RemoteASRHTTP.post(
            url: url,
            headers: [:],
            body: body,
            contentType: "application/json"
        )
        guard (200..<300).contains(http.statusCode) else {
            let err = String(data: data, encoding: .utf8) ?? ""
            throw ASREngineError.underlying("Gemini HTTP \(http.statusCode): \(err.prefix(240))")
        }
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw ASREngineError.underlying("Unexpected Gemini response.")
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
