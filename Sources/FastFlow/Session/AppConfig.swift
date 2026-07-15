import Foundation
import FastFlowPlugins

enum ASRBackendPreference: String {
    case stub
    case parakeet
    case auto
}

/// Resolves which ASREngine to use and whether to force stub mode.
enum AppConfig {
    static let capabilityEnforcer = PluginCapabilityEnforcer()

    /// Set `FASTFLOW_ASR=stub` to force stub without FluidAudio warm-up.
    static var preferredBackend: ASRBackendPreference {
        let env = ProcessInfo.processInfo.environment["FASTFLOW_ASR"]?.lowercased()
        switch env {
        case "stub": return .stub
        case "parakeet": return .parakeet
        default:
            #if FASTFLOW_USE_FLUIDAUDIO
            return .parakeet
            #else
            return .stub
            #endif
        }
    }

    static func makeASREngine(preference: ASRBackendPreference = preferredBackend) -> any ASREngine {
        PluginBootstrap.registerBuiltins()
        switch preference {
        case .stub:
            return (try? PluginRegistry.shared.makeASRAuthorized(id: StubASREngine.manifestID))
                ?? StubASREngine()
        case .parakeet:
            #if FASTFLOW_USE_FLUIDAUDIO
            do {
                return try PluginRegistry.shared.makeASRAuthorized(id: ParakeetTDTEngine.manifestID)
            } catch {
                NSLog("FastFlow: Parakeet blocked by capability policy (\(error.localizedDescription)); falling back to stub. Use NetworkPluginHost or FASTFLOW_ALLOW_INPROCESS_NETWORK=1 for first download.")
                return StubASREngine()
            }
            #else
            return StubASREngine()
            #endif
        case .auto:
            #if FASTFLOW_USE_FLUIDAUDIO
            return (try? PluginRegistry.shared.makeASRAuthorized(id: ParakeetTDTEngine.manifestID))
                ?? StubASREngine()
            #else
            return StubASREngine()
            #endif
        }
    }
}
