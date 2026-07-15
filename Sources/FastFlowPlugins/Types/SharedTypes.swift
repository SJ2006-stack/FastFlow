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
    case wakeWord
    case vad
    case asr
    case screenContext
    case biasList
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

    public init(
        id: String,
        name: String,
        kind: PluginKind,
        version: String = "0.1.0",
        summary: String,
        approxActiveMemoryMB: Int,
        requiresNetwork: Bool = false,
        supportsStreaming: Bool = false,
        isBuiltin: Bool = true
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
    }
}
