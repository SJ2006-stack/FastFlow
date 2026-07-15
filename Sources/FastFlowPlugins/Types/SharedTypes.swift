import Foundation

// MARK: - Audio

/// One chunk of PCM audio for plugin pipelines.
public struct AudioFrame: Sendable, Equatable {
    public let samples: [Float]
    public let sampleRate: Double
    public let channelCount: Int
    public let timestamp: TimeInterval

    public init(
        samples: [Float],
        sampleRate: Double = 16_000,
        channelCount: Int = 1,
        timestamp: TimeInterval = 0
    ) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.timestamp = timestamp
    }

    public var durationSeconds: TimeInterval {
        guard sampleRate > 0, channelCount > 0 else { return 0 }
        return Double(samples.count) / sampleRate / Double(channelCount)
    }
}

/// Compact identity for an utterance (optional future privacy / dedupe).
public struct AudioFingerprint: Sendable, Hashable, Codable {
    public let sha256Hex: String
    public let durationSeconds: TimeInterval
    public let sampleRate: Double

    public init(sha256Hex: String, durationSeconds: TimeInterval, sampleRate: Double) {
        self.sha256Hex = sha256Hex
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
    }
}

// MARK: - ASR streaming

public struct TranscriptPartial: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool
    public let confidence: Float?

    public init(text: String, isFinal: Bool, confidence: Float? = nil) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
    }
}

// MARK: - Bias list

public struct BiasedWord: Sendable, Hashable, Codable, Identifiable {
    public var id: String { word.lowercased() }
    public var word: String
    public var weight: Double
    public var notes: String?

    public init(word: String, weight: Double = 1.0, notes: String? = nil) {
        self.word = word
        self.weight = weight
        self.notes = notes
    }
}

// MARK: - Screen context

public enum FieldType: String, Sendable, Codable, CaseIterable {
    case unknown
    case plainText
    case search
    case chat
    case code
    case email
    case url
    case password
}

public struct CapturedFrame: Sendable {
    public let width: Int
    public let height: Int
    /// Raw RGBA/BGRA bytes when a capture backend is active; empty for stubs.
    public let pixelData: Data
    public let capturedAt: Date

    public init(width: Int, height: Int, pixelData: Data = Data(), capturedAt: Date = .now) {
        self.width = width
        self.height = height
        self.pixelData = pixelData
        self.capturedAt = capturedAt
    }
}

public struct ScreenContext: Sendable, Equatable {
    public let appBundleID: String?
    public let windowTitle: String?
    public let fieldType: FieldType
    public let nearbyLabels: [String]
    public let suggestedBias: [String]

    public init(
        appBundleID: String? = nil,
        windowTitle: String? = nil,
        fieldType: FieldType = .unknown,
        nearbyLabels: [String] = [],
        suggestedBias: [String] = []
    ) {
        self.appBundleID = appBundleID
        self.windowTitle = windowTitle
        self.fieldType = fieldType
        self.nearbyLabels = nearbyLabels
        self.suggestedBias = suggestedBias
    }

    public static let empty = ScreenContext()
}

// MARK: - Plugin metadata

public enum PluginKind: String, Sendable, Codable, CaseIterable {
    case vad
    case asr
    case screenContext
    case biasList
}

/// Where inference runs. Default product promise = local free.
public enum InferenceTier: String, Sendable, Codable, CaseIterable {
    /// Offline / on-device, no API key — FastFlow default.
    case localFree
    /// Larger local model (still on-device).
    case localEnhanced
    /// Remote API plug-in (Hugging Face, OpenRouter, Gemini, …) — opt-in.
    case cloudPlugin
}

/// Catalog family for Model Zoo grouping / credential lookup.
public enum ModelProviderFamily: String, Sendable, Codable, CaseIterable {
    case local
    case huggingface
    case openrouter
    case gemini
    case custom
}

public struct PluginManifest: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var name: String
    public var kind: PluginKind
    public var version: String
    public var summary: String
    public var approxActiveMemoryMB: Int
    public var requiresNetwork: Bool
    public var supportsStreaming: Bool
    public var isBuiltin: Bool
    /// Default = localFree. Cloud plugins must set `.cloudPlugin`.
    public var inferenceTier: InferenceTier
    public var providerFamily: ModelProviderFamily
    /// Optional remote model id (HF repo, OpenRouter slug, Gemini model name).
    public var remoteModelID: String?

    public init(
        id: String,
        name: String,
        kind: PluginKind,
        version: String = "0.1.0",
        summary: String,
        approxActiveMemoryMB: Int,
        requiresNetwork: Bool = false,
        supportsStreaming: Bool = false,
        isBuiltin: Bool = true,
        inferenceTier: InferenceTier = .localFree,
        providerFamily: ModelProviderFamily = .local,
        remoteModelID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.version = version
        self.summary = summary
        self.approxActiveMemoryMB = approxActiveMemoryMB
        self.requiresNetwork = requiresNetwork
        self.supportsStreaming = supportsStreaming
        self.isBuiltin = isBuiltin
        self.inferenceTier = inferenceTier
        self.providerFamily = providerFamily
        self.remoteModelID = remoteModelID
    }

    public var isCloudPlugin: Bool { inferenceTier == .cloudPlugin }
    public var isLocalDefaultCandidate: Bool {
        inferenceTier == .localFree || inferenceTier == .localEnhanced
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, version, summary, approxActiveMemoryMB
        case requiresNetwork, supportsStreaming, isBuiltin
        case inferenceTier, providerFamily, remoteModelID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(PluginKind.self, forKey: .kind)
        version = try c.decodeIfPresent(String.self, forKey: .version) ?? "0.1.0"
        summary = try c.decode(String.self, forKey: .summary)
        approxActiveMemoryMB = try c.decode(Int.self, forKey: .approxActiveMemoryMB)
        requiresNetwork = try c.decodeIfPresent(Bool.self, forKey: .requiresNetwork) ?? false
        supportsStreaming = try c.decodeIfPresent(Bool.self, forKey: .supportsStreaming) ?? false
        isBuiltin = try c.decodeIfPresent(Bool.self, forKey: .isBuiltin) ?? false
        inferenceTier = try c.decodeIfPresent(InferenceTier.self, forKey: .inferenceTier)
            ?? (requiresNetwork ? .cloudPlugin : .localFree)
        providerFamily = try c.decodeIfPresent(ModelProviderFamily.self, forKey: .providerFamily)
            ?? (requiresNetwork ? .custom : .local)
        remoteModelID = try c.decodeIfPresent(String.self, forKey: .remoteModelID)
    }
}
