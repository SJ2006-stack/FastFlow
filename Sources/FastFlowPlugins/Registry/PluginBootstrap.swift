import Foundation

/// Registers built-in engines so Settings can list the Model Zoo without a rebuild.
///
/// **Default product promise:** local free on-device ASR.
/// Cloud plug-ins (HF / OpenRouter / Gemini) are opt-in for better / customized inference.
public enum PluginBootstrap {
    private static let once = NSLock()
    nonisolated(unsafe) private static var didRegister = false

    public static func registerBuiltins() {
        once.lock()
        defer { once.unlock() }
        guard !didRegister else { return }
        didRegister = true

        let registry = PluginRegistry.shared

        registry.registerVAD { EnergyVADDetector() }
        registry.registerVAD { SileroVADDetector() }

        // —— Local free (default tier) ——
        registry.registerASR { StubASREngine() }
        registry.registerASR { MoonshineEngine() }
        #if FASTFLOW_USE_FLUIDAUDIO
        registry.registerASR { ParakeetTDTEngine() }
        #endif

        // —— Local enhanced ——
        registry.registerASR { WhisperCppEngine() }

        // —— Cloud plugins (opt-in, API keys required) ——
        registry.registerASR { HuggingFaceASREngine() }
        registry.registerASR { OpenRouterASREngine() }
        registry.registerASR { GeminiASREngine() }

        // BYO persisted endpoints (developers / power users)
        BYOPluginRegistrar.registerAllPersisted()

        registry.registerScreen { QuantizedVLMParser() }

        registry.registerBiasStore { InMemoryBiasListStore() }
        registry.registerBiasStore { SQLiteBiasListStore() }

        CommunityPluginLoader.loadManifestsIntoRegistry()
    }
}
