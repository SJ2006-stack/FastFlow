import Foundation
import FastFlowPlugins

enum ASRBackendPreference: String {
    case stub
    case parakeet
    case moonshine
    case huggingface
    case openrouter
    case gemini
    /// Local-first: selected plug-in, else Parakeet if cached, else stub.
    case auto
}

/// Resolves ASR. **Default = local free.** Cloud engines only when explicitly selected.
enum AppConfig {
    static let capabilityEnforcer = PluginCapabilityEnforcer()

    static var preferredBackend: ASRBackendPreference {
        let env = ProcessInfo.processInfo.environment["FASTFLOW_ASR"]?.lowercased()
        switch env {
        case "stub": return .stub
        case "parakeet": return .parakeet
        case "moonshine": return .moonshine
        case "huggingface", "hf": return .huggingface
        case "openrouter": return .openrouter
        case "gemini": return .gemini
        case "auto": return .auto
        default:
            return .auto
        }
    }

    static var parakeetModelsCached: Bool {
        #if FASTFLOW_USE_FLUIDAUDIO
        return ParakeetTDTEngine.modelsCachedOnDisk()
        #else
        return false
        #endif
    }

    static func makeASREngine(preference: ASRBackendPreference = preferredBackend) -> any ASREngine {
        PluginBootstrap.registerBuiltins()

        // Explicit user Model Zoo selection wins (unless env forced stub).
        if preference == .auto, let id = ModelSelectionStore.selectedASRID {
            if let engine = try? PluginRegistry.shared.makeASRAuthorized(id: id) {
                return engine
            }
        }

        switch preference {
        case .stub:
            return stubEngine()
        case .parakeet:
            return engineOrStub(ParakeetTDTEngine.manifestID)
        case .moonshine:
            return engineOrStub(MoonshineEngine.manifestID)
        case .huggingface:
            return engineOrStub(HuggingFaceASREngine.manifestID)
        case .openrouter:
            return engineOrStub(OpenRouterASREngine.manifestID)
        case .gemini:
            return engineOrStub(GeminiASREngine.manifestID)
        case .auto:
            // Local free default — never auto-pick cloud.
            if parakeetModelsCached {
                return engineOrStub(ParakeetTDTEngine.manifestID)
            }
            return stubEngine()
        }
    }

    static func selectEngine(id: String) -> any ASREngine {
        ModelSelectionStore.selectedASRID = id
        return (try? PluginRegistry.shared.makeASRAuthorized(id: id)) ?? stubEngine()
    }

    static func localASRManifests() -> [PluginManifest] {
        PluginRegistry.shared.allManifests(kind: .asr)
            .filter(\.isLocalDefaultCandidate)
    }

    static func cloudASRManifests() -> [PluginManifest] {
        PluginRegistry.shared.allManifests(kind: .asr)
            .filter(\.isCloudPlugin)
    }

    private static func stubEngine() -> any ASREngine {
        (try? PluginRegistry.shared.makeASRAuthorized(id: StubASREngine.manifestID))
            ?? StubASREngine()
    }

    private static func engineOrStub(_ id: String) -> any ASREngine {
        do {
            return try PluginRegistry.shared.makeASRAuthorized(id: id)
        } catch {
            NSLog("FastFlow: engine \(id) unavailable (\(error.localizedDescription)); using local stub.")
            return stubEngine()
        }
    }
}
