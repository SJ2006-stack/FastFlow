import Foundation

/// Registers built-in engines so Settings can list the Model Zoo without a rebuild.
public enum PluginBootstrap {
    private static let once = NSLock()
    private static var didRegister = false

    public static func registerBuiltins() {
        once.lock()
        defer { once.unlock() }
        guard !didRegister else { return }
        didRegister = true

        let registry = PluginRegistry.shared

        // Wake word
        registry.registerWakeWord { OpenWakeWordDetector() }
        registry.registerWakeWord { PorcupineDetector() }

        // VAD
        registry.registerVAD { EnergyVADDetector() }
        registry.registerVAD { SileroVADDetector() }

        // ASR
        registry.registerASR { StubASREngine() }
        registry.registerASR { MoonshineEngine() }
        registry.registerASR { WhisperCppEngine() }
        #if FASTFLOW_USE_FLUIDAUDIO
        registry.registerASR { ParakeetTDTEngine() }
        #endif

        // Screen
        registry.registerScreen { QuantizedVLMParser() }

        // Bias
        registry.registerBiasStore { InMemoryBiasListStore() }
        registry.registerBiasStore { SQLiteBiasListStore() }

        // Load community JSON manifests (metadata only for MVP).
        CommunityPluginLoader.loadManifestsIntoRegistry()
    }
}
