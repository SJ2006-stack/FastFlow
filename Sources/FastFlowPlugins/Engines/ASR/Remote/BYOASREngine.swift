import Foundation

/// Bring-your-own ASR — generic HTTP endpoint so developers fuse any model.
///
/// FastFlow is the interface: register a BYO config (or `PluginRegistry.registerASR`)
/// and dictation / insertion keep working unchanged.
public final class BYOASREngine: ASREngine, @unchecked Sendable {
    public let manifest: PluginManifest
    public private(set) var isActive = false
    public let config: ModelSelectionStore.BYOModelConfig

    public init(config: ModelSelectionStore.BYOModelConfig) {
        self.config = config
        self.manifest = PluginManifest(
            id: config.id,
            name: config.displayName,
            kind: .asr,
            summary: "BYO — \(config.endpointURL)",
            approxActiveMemoryMB: 15,
            requiresNetwork: true,
            inferenceTier: .cloudPlugin,
            providerFamily: .custom,
            remoteModelID: config.remoteModelID
        )
    }

    public func activate() async throws {
        let enforcer = PluginCapabilityEnforcer()
        try enforcer.assertCanActivate(manifest, modelsCached: false)
        guard let url = URL(string: config.endpointURL), url.scheme == "https" || url.scheme == "http" else {
            throw ASREngineError.underlying("BYO endpoint must be a valid http(s) URL.")
        }
        _ = url
        // Key optional for local LAN endpoints; recommended for public APIs.
        isActive = true
    }

    public func deactivate() async { isActive = false }

    public func transcribe(_ samples: [Float]) async throws -> String {
        guard isActive else { throw ASREngineError.notLoaded(name: name) }
        guard !samples.isEmpty else { throw ASREngineError.emptyAudio }
        guard let url = URL(string: config.endpointURL) else {
            throw ASREngineError.underlying("Invalid BYO endpoint URL.")
        }

        let wav = WAVEncoder.encodeMono16kHz(samples)
        var headers: [String: String] = [:]
        if let key = ModelSelectionStore.byoAPIKey(forConfigID: config.id), !key.isEmpty {
            switch config.authStyle {
            case "header":
                let name = config.customHeaderName ?? "X-API-Key"
                headers[name] = key
            default:
                headers["Authorization"] = "Bearer \(key)"
            }
        }

        let body: Data
        let contentType: String
        switch config.bodyStyle {
        case "jsonBase64":
            var payload: [String: Any] = ["audio_base64": wav.base64EncodedString()]
            if let model = config.remoteModelID { payload["model"] = model }
            body = try JSONSerialization.data(withJSONObject: payload)
            contentType = "application/json"
        default:
            body = wav
            contentType = "audio/wav"
        }

        let (data, http) = try await RemoteASRHTTP.post(
            url: url,
            headers: headers,
            body: body,
            contentType: contentType
        )
        guard (200..<300).contains(http.statusCode) else {
            let err = String(data: data, encoding: .utf8) ?? ""
            throw ASREngineError.underlying("BYO HTTP \(http.statusCode): \(err.prefix(240))")
        }

        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let text = obj["text"] as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
            if let text = obj["transcript"] as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty,
           !text.hasPrefix("{") {
            return text
        }
        throw ASREngineError.underlying("BYO response had no recognizable transcript field.")
    }
}

/// Registers persisted BYO configs into the live plugin registry (framework hook).
public enum BYOPluginRegistrar {
    public static func registerAllPersisted() {
        for config in ModelSelectionStore.byoConfigs() {
            let captured = config
            PluginRegistry.shared.registerASR {
                BYOASREngine(config: captured)
            }
        }
    }
}
