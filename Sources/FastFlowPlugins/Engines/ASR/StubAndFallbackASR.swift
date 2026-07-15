import Foundation

/// Deterministic stub ASR for path validation without CoreML downloads.
public final class StubASREngine: ASREngine, @unchecked Sendable {
    public static let manifestID = "asr.stub"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "Stub ASR",
        kind: .asr,
        summary: "Echo stub — returns a timed placeholder for paste-path testing.",
        approxActiveMemoryMB: 5,
        requiresNetwork: false,
        supportsStreaming: false
    )
    public private(set) var isActive = false
    private var bias: [BiasedWord] = []

    public init() {}

    public func activate() async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
        isActive = true
    }

    public func deactivate() async {
        isActive = false
    }

    public func transcribe(_ samples: [Float]) async throws -> String {
        guard isActive else {
            throw ASREngineError.notLoaded(name: name)
        }
        let seconds = Double(samples.count) / 16_000.0
        let biasHint = bias.isEmpty ? "" : " bias=\(bias.map(\.word).joined(separator: ","))"
        return "FastFlow stub transcript (\(String(format: "%.1f", seconds))s audio)\(biasHint)"
    }

    public func applyBiasList(_ words: [BiasedWord]) async {
        bias = words
    }
}

public final class MoonshineEngine: ASREngine, @unchecked Sendable {
    public static let manifestID = "asr.moonshine"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "Moonshine Tiny",
        kind: .asr,
        summary: "Stub — smaller RSS fallback if Parakeet exceeds active RAM budget.",
        approxActiveMemoryMB: 120,
        requiresNetwork: false,
        supportsStreaming: false
    )
    public private(set) var isActive = false

    public init() {}

    public func activate() async throws {
        throw ASREngineError.notImplemented(name: name)
    }

    public func deactivate() async { isActive = false }

    public func transcribe(_ samples: [Float]) async throws -> String {
        _ = samples
        throw ASREngineError.notImplemented(name: name)
    }
}

public final class WhisperCppEngine: ASREngine, @unchecked Sendable {
    public static let manifestID = "asr.whispercpp"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "whisper.cpp",
        kind: .asr,
        summary: "Stub — whisper.cpp CoreML/Metal backend (community plug-in target).",
        approxActiveMemoryMB: 300,
        requiresNetwork: false,
        supportsStreaming: false
    )
    public private(set) var isActive = false

    public init() {}

    public func activate() async throws {
        throw ASREngineError.notImplemented(name: name)
    }

    public func deactivate() async { isActive = false }

    public func transcribe(_ samples: [Float]) async throws -> String {
        _ = samples
        throw ASREngineError.notImplemented(name: name)
    }
}

public enum ASREngineError: LocalizedError {
    case notLoaded(name: String)
    case notImplemented(name: String)
    case emptyAudio
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .notLoaded(let name):
            return "\(name) is not loaded — call activate()/load() first."
        case .notImplemented(let name):
            return "\(name) is a stub and is not implemented yet."
        case .emptyAudio:
            return "No audio captured."
        case .underlying(let message):
            return message
        }
    }
}
