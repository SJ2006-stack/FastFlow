import Foundation

/// Loads community `plugin.json` manifests from `fastflow-plugins/community/`.
///
/// Phase 1 registers metadata only so Settings can list community plug-ins
/// without shipping dynamic libraries. Full dylib/bundle loading is Phase 2+.
public enum CommunityPluginLoader {
    public static func communityRoot() -> URL {
        // Prefer repo-relative path when running from a checkout; else Application Support.
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let checkout = cwd.appendingPathComponent("fastflow-plugins/community", isDirectory: true)
        if FileManager.default.fileExists(atPath: checkout.path) {
            return checkout
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FastFlow/plugins/community", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support
    }

    public static func loadManifestsIntoRegistry() {
        let root = communityRoot()
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for dir in entries {
            let manifestURL = dir.appendingPathComponent("plugin.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  var manifest = try? JSONDecoder().decode(PluginManifest.self, from: data)
            else { continue }
            manifest.isBuiltin = false
            // Register as ASR stub factory if kind matches — contributors replace later.
            switch manifest.kind {
            case .asr:
                let captured = manifest
                PluginRegistry.shared.registerASR {
                    CommunityStubASREngine(manifest: captured)
                }
            case .vad:
                let captured = manifest
                PluginRegistry.shared.registerVAD {
                    CommunityStubVAD(manifest: captured)
                }
            case .wakeWord:
                let captured = manifest
                PluginRegistry.shared.registerWakeWord {
                    CommunityStubWake(manifest: captured)
                }
            case .screenContext:
                let captured = manifest
                PluginRegistry.shared.registerScreen {
                    CommunityStubScreen(manifest: captured)
                }
            case .biasList:
                break
            }
        }
    }
}

private final class CommunityStubASREngine: ASREngine, @unchecked Sendable {
    let manifest: PluginManifest
    private(set) var isActive = false
    init(manifest: PluginManifest) { self.manifest = manifest }
    func activate() async throws { isActive = true }
    func deactivate() async { isActive = false }
    func transcribe(_ samples: [Float]) async throws -> String {
        _ = samples
        throw ASREngineError.notImplemented(name: name)
    }
}

private final class CommunityStubVAD: VoiceActivityDetector, @unchecked Sendable {
    let manifest: PluginManifest
    private(set) var isActive = false
    init(manifest: PluginManifest) { self.manifest = manifest }
    func activate() async throws { isActive = true }
    func deactivate() async { isActive = false }
    func isSpeech(_ frame: AudioFrame) async -> Bool { _ = frame; return false }
}

private final class CommunityStubWake: WakeWordDetector, @unchecked Sendable {
    let manifest: PluginManifest
    private(set) var isActive = false
    init(manifest: PluginManifest) { self.manifest = manifest }
    func activate() async throws { isActive = true }
    func deactivate() async { isActive = false }
    func process(_ frame: AudioFrame) async -> Bool { _ = frame; return false }
}

private final class CommunityStubScreen: ScreenContextParser, @unchecked Sendable {
    let manifest: PluginManifest
    private(set) var isActive = false
    init(manifest: PluginManifest) { self.manifest = manifest }
    func activate() async throws { isActive = true }
    func deactivate() async { isActive = false }
    func parse(_ frame: CapturedFrame) async throws -> ScreenContext {
        _ = frame
        return .empty
    }
}
