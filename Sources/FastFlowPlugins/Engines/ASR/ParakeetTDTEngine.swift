import Foundation
import os

#if FASTFLOW_USE_FLUIDAUDIO
import FluidAudio

/// Parakeet TDT 0.6B v3 via FluidAudio / CoreML / ANE.
///
/// Lazy-loads on `activate()`. Call `deactivate()` to drop the manager and
/// free resident memory (Phase 2 XPC will make idle unload automatic).
public final class ParakeetTDTEngine: ASREngine, @unchecked Sendable {
    public static let manifestID = "asr.parakeet.tdt.v3"

    public let manifest = PluginManifest(
        id: manifestID,
        name: "Parakeet TDT v3",
        kind: .asr,
        version: "0.6.0",
        summary: "FluidAudio Parakeet TDT 0.6B v3 (CoreML, multilingual). First activate downloads ~500–600 MB.",
        approxActiveMemoryMB: 350,
        requiresNetwork: true, // first-run download only; offline after cache
        supportsStreaming: false
    )

    private struct State {
        var isActive = false
        var manager: AsrManager?
        var bias: [BiasedWord] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public var isActive: Bool {
        state.withLock(\.isActive)
    }

    public init() {}

    /// True when FluidAudio's v3 cache directory already has model files (offline-capable).
    public static func modelsCachedOnDisk() -> Bool {
        let dir = AsrModels.defaultCacheDirectory(for: .v3)
        return AsrModels.modelsExist(at: dir)
    }

    public func activate() async throws {
        if state.withLock({ $0.isActive && $0.manager != nil }) { return }

        let cached = Self.modelsCachedOnDisk()
        let enforcer = PluginCapabilityEnforcer()
        try enforcer.assertCanActivate(manifest, modelsCached: cached)

        let models: AsrModels
        if cached {
            models = try await AsrModels.loadFromCache(version: .v3)
        } else {
            models = try await AsrModels.downloadAndLoad(version: .v3)
        }
        let asr = AsrManager(config: .default, models: models)

        state.withLock {
            $0.manager = asr
            $0.isActive = true
        }
    }

    public func deactivate() async {
        let asr = state.withLock { s -> AsrManager? in
            let m = s.manager
            s.manager = nil
            s.isActive = false
            return m
        }
        if let asr {
            await asr.cleanup()
        }
    }

    public func transcribe(_ samples: [Float]) async throws -> String {
        let asr = state.withLock(\.manager)
        guard let asr else {
            throw ASREngineError.notLoaded(name: name)
        }
        guard !samples.isEmpty else {
            throw ASREngineError.emptyAudio
        }

        var decoderState = try TdtDecoderState()
        let result = try await asr.transcribe(samples, decoderState: &decoderState, language: nil)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func applyBiasList(_ words: [BiasedWord]) async {
        state.withLock { $0.bias = words }
    }
}

#else

/// Placeholder when FluidAudio is not linked (`FASTFLOW_USE_FLUIDAUDIO=0`).
public final class ParakeetTDTEngine: ASREngine, @unchecked Sendable {
    public static let manifestID = "asr.parakeet.tdt.v3"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "Parakeet TDT v3",
        kind: .asr,
        summary: "Disabled — rebuild with FluidAudio (default) to enable.",
        approxActiveMemoryMB: 350,
        requiresNetwork: true
    )
    public private(set) var isActive = false

    public init() {}

    public static func modelsCachedOnDisk() -> Bool { false }

    public func activate() async throws {
        throw ASREngineError.underlying(
            "Parakeet requires FluidAudio. Build without swapping to Package.stub.swift."
        )
    }

    public func deactivate() async { isActive = false }

    public func transcribe(_ samples: [Float]) async throws -> String {
        _ = samples
        throw ASREngineError.notImplemented(name: name)
    }
}

#endif
