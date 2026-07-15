import Foundation

/// Simple energy-based VAD used as the default local gate.
public final class EnergyVADDetector: VoiceActivityDetector, @unchecked Sendable {
    public static let manifestID = "vad.energy"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "Energy VAD",
        kind: .vad,
        summary: "RMS energy threshold — no ML weights.",
        approxActiveMemoryMB: 1,
        requiresNetwork: false
    )
    public private(set) var isActive = false
    public var threshold: Float = 0.01

    public init() {}

    public func activate() async throws { isActive = true }
    public func deactivate() async { isActive = false }

    public func isSpeech(_ frame: AudioFrame) async -> Bool {
        guard !frame.samples.isEmpty else { return false }
        let sumSquares = frame.samples.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = sqrt(sumSquares / Float(frame.samples.count))
        return rms >= threshold
    }
}

public final class SileroVADDetector: VoiceActivityDetector, @unchecked Sendable {
    public static let manifestID = "vad.silero"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "Silero VAD",
        kind: .vad,
        summary: "Stub — Silero ONNX/CoreML VAD (optional gate; PTT hotkey starts dictation).",
        approxActiveMemoryMB: 25,
        requiresNetwork: false
    )
    public private(set) var isActive = false
    private let fallback = EnergyVADDetector()

    public init() {}

    public func activate() async throws {
        try await fallback.activate()
        isActive = true
    }

    public func deactivate() async {
        await fallback.deactivate()
        isActive = false
    }

    public func isSpeech(_ frame: AudioFrame) async -> Bool {
        await fallback.isSpeech(frame)
    }
}
