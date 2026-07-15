import Foundation

/// Registers built-in engines so Settings can list the Model Zoo without a rebuild.
public enum PluginBootstrap {
    private static let once = NSLock()
    /// Guarded by `once`; marked unsafe for Swift 6 global mutable state rules.
    nonisolated(unsafe) private static var didRegister = false

    public static func registerBuiltins() {
        once.lock()
        defer { once.unlock() }
        guard !didRegister else { return }
        didRegister = true

        let registry = PluginRegistry.shared

        // VAD (optional gate — dictation itself is hotkey / push-to-talk only)
        registry.registerVAD { EnergyVADDetector() }
        registry.registerVAD { SileroVADDetector() }

        // ASR
        registry.registerASR { StubASREngine() }
        registry.registerASR { MoonshineEngine() }
        registry.registerASR { WhisperCppEngine() }
        #if FASTFLOW_USE_FLUIDAUDIO
        registry.registerASR { ParakeetTDTEngine() }
        #endif

        registry.registerScreen { QuantizedVLMParser() }

        registry.registerBiasStore { InMemoryBiasListStore() }
        registry.registerBiasStore { SQLiteBiasListStore() }

        CommunityPluginLoader.loadManifestsIntoRegistry()
    }
}
