import Foundation
import FastFlowPlugins

enum ASRBackendPreference: String {
    case stub
    case parakeet
    /// Slim default: stub until Parakeet is cached on disk, then Parakeet.
    case auto
}

/// Resolves which ASREngine to use. Slim packages default to low-RAM stub
/// until the user downloads models.
enum AppConfig {
    static let capabilityEnforcer = PluginCapabilityEnforcer()

    /// `FASTFLOW_ASR=stub|parakeet|auto`. Default **auto** for smooth slim installs.
    static var preferredBackend: ASRBackendPreference {
        let env = ProcessInfo.processInfo.environment["FASTFLOW_ASR"]?.lowercased()
        switch env {
        case "stub": return .stub
        case "parakeet": return .parakeet
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
        switch preference {
        case .stub:
            return stubEngine()
        case .parakeet:
            return parakeetOrStub()
        case .auto:
            // Slim download path: stay on stub (tiny RAM) until models exist.
            if parakeetModelsCached {
                return parakeetOrStub()
            }
            return stubEngine()
        }
    }

    private static func stubEngine() -> any ASREngine {
        (try? PluginRegistry.shared.makeASRAuthorized(id: StubASREngine.manifestID))
            ?? StubASREngine()
    }

    private static func parakeetOrStub() -> any ASREngine {
        #if FASTFLOW_USE_FLUIDAUDIO
        do {
            return try PluginRegistry.shared.makeASRAuthorized(id: ParakeetTDTEngine.manifestID)
        } catch {
            NSLog(
                "FastFlow: Parakeet blocked (\(error.localizedDescription)); using stub. Menu → Download Speech Model…"
            )
            return stubEngine()
        }
        #else
        return stubEngine()
        #endif
    }
}
