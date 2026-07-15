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

        registry.registerWakeWord { OpenWakeWordDetector() }
        registry.registerWakeWord { PorcupineDetector() }

        registry.registerVAD { EnergyVADDetector() }
        registry.registerVAD { SileroVADDetector() }

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
