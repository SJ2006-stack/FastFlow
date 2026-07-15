import Foundation

/// Which OS sandbox / entitlement profile this process was signed with.
///
/// Flags on `PluginManifest` are **advisory for UI**. This role + the
/// entitlements files under `entitlements/` are the real gate once the
/// app is sandboxed and notarized.
public enum ProcessSandboxRole: String, Sendable, Codable {
    /// Menu-bar app: App Sandbox ON, **no** `network.client`.
    case mainApp
    /// Future/helper XPC: App Sandbox ON, **with** `network.client`.
    case networkPluginHost
}

/// Capabilities a plug-in may request. Manifest `requiresNetwork` maps to `.outboundNetwork`.
public enum PluginCapability: String, Sendable, Codable, CaseIterable {
    case outboundNetwork
    case microphone
    case screenCapture
}

public enum PluginCapabilityError: LocalizedError, Sendable {
    case networkDeniedInMainProcess(pluginID: String)
    case hostUnavailable(pluginID: String)
    case roleMismatch(expected: ProcessSandboxRole, actual: ProcessSandboxRole)

    public var errorDescription: String? {
        switch self {
        case .networkDeniedInMainProcess(let id):
            return """
            Plugin '\(id)' requires outbound network and cannot activate in the main FastFlow process. \
            Load it only via NetworkPluginHost (entitlements/FastFlowNetworkPluginHost.entitlements). \
            Manifest flags are advisory; the OS sandbox on the main app denies sockets.
            """
        case .hostUnavailable(let id):
            return "NetworkPluginHost is not available to activate '\(id)' in this build (XPC host Phase 2)."
        case .roleMismatch(let expected, let actual):
            return "Process role is \(actual.rawValue); expected \(expected.rawValue)."
        }
    }
}

/// Enforces where networked / privileged plug-ins may load.
///
/// Phase 1 (no XPC yet):
/// - Main process refuses `requiresNetwork == true` community/untrusted plugins.
/// - Built-in Parakeet **inference** is allowlisted only when models are already on disk
///   (offline). First-run download must go through `NetworkPluginHost` (stub until XPC).
/// - Debug escape: `FASTFLOW_ALLOW_INPROCESS_NETWORK=1` (unsigned / non-sandbox only).
public struct PluginCapabilityEnforcer: Sendable {
    public var role: ProcessSandboxRole
    public var allowInProcessNetworkEscape: Bool

    /// Built-in engines whose *offline* activate() may run in main after models exist.
    public static let trustedOfflineASRAllowlist: Set<String> = [
        ParakeetTDTEngine.manifestID,
        StubASREngine.manifestID,
        MoonshineEngine.manifestID,
        WhisperCppEngine.manifestID,
    ]

    public init(
        role: ProcessSandboxRole = .mainApp,
        allowInProcessNetworkEscape: Bool = PluginCapabilityEnforcer.escapeFromEnvironment()
    ) {
        self.role = role
        self.allowInProcessNetworkEscape = allowInProcessNetworkEscape
    }

    /// UserDefaults key set only while the user runs **Download Speech Model…**
    public static let allowInProcessDownloadDefaultsKey = "fastflow.allowInProcessModelDownload"

    public static func escapeFromEnvironment() -> Bool {
        let v = ProcessInfo.processInfo.environment["FASTFLOW_ALLOW_INPROCESS_NETWORK"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if v == "1" || v == "true" || v == "yes" { return true }
        // Explicit menu action (slim package first-run) — temporary UserDefaults flag.
        return UserDefaults.standard.bool(forKey: allowInProcessDownloadDefaultsKey)
    }

    /// Enable a one-shot in-process model download (user-initiated). Caller must clear.
    public static func beginUserInitiatedModelDownload() {
        UserDefaults.standard.set(true, forKey: allowInProcessDownloadDefaultsKey)
    }

    public static func endUserInitiatedModelDownload() {
        UserDefaults.standard.set(false, forKey: allowInProcessDownloadDefaultsKey)
    }

    public static func roleFromEnvironment() -> ProcessSandboxRole {
        let v = ProcessInfo.processInfo.environment["FASTFLOW_PROCESS_ROLE"]?.lowercased()
        if v == "network" || v == "networkpluginhost" {
            return .networkPluginHost
        }
        return .mainApp
    }

    public func capabilities(for manifest: PluginManifest) -> Set<PluginCapability> {
        var caps: Set<PluginCapability> = []
        if manifest.requiresNetwork { caps.insert(.outboundNetwork) }
        if manifest.kind == .screenContext { caps.insert(.screenCapture) }
        if manifest.kind == .asr || manifest.kind == .vad {
            caps.insert(.microphone)
        }
        return caps
    }

    /// Call before `activate()` / model download.
    public func assertCanActivate(_ manifest: PluginManifest, modelsCached: Bool = false) throws {
        let caps = capabilities(for: manifest)
        guard caps.contains(.outboundNetwork) else { return }

        switch role {
        case .networkPluginHost:
            return
        case .mainApp:
            if allowInProcessNetworkEscape {
                return
            }
            // Trusted ASR with models already on disk: inference needs no network.
            if modelsCached, Self.trustedOfflineASRAllowlist.contains(manifest.id) {
                return
            }
            throw PluginCapabilityError.networkDeniedInMainProcess(pluginID: manifest.id)
        }
    }

    public func assertCanLoadIntoCurrentProcess(_ manifest: PluginManifest) throws {
        try assertCanActivate(manifest, modelsCached: false)
    }
}

/// Boundary for any plug-in that needs outbound network.
///
/// Phase 1: in-process stub that only succeeds when `role == .networkPluginHost`
/// or the debug escape is set. Phase 2: real XPC service signed with
/// `entitlements/FastFlowNetworkPluginHost.entitlements`.
public protocol NetworkPluginHost: Sendable {
    var role: ProcessSandboxRole { get }
    func activateNetworkedASR(id: String) async throws -> any ASREngine
    func downloadModelsIfNeeded(for manifest: PluginManifest) async throws
}

public final class StubNetworkPluginHost: NetworkPluginHost, @unchecked Sendable {
    public let role: ProcessSandboxRole
    private let enforcer: PluginCapabilityEnforcer

    public init(role: ProcessSandboxRole = PluginCapabilityEnforcer.roleFromEnvironment()) {
        self.role = role
        self.enforcer = PluginCapabilityEnforcer(role: role)
    }

    public func activateNetworkedASR(id: String) async throws -> any ASREngine {
        PluginBootstrap.registerBuiltins()
        guard let engine = PluginRegistry.shared.makeASR(id: id) else {
            throw PluginCapabilityError.hostUnavailable(pluginID: id)
        }
        try enforcer.assertCanActivate(engine.manifest, modelsCached: false)
        guard role == .networkPluginHost || enforcer.allowInProcessNetworkEscape else {
            throw PluginCapabilityError.networkDeniedInMainProcess(pluginID: id)
        }
        try await engine.activate()
        return engine
    }

    public func downloadModelsIfNeeded(for manifest: PluginManifest) async throws {
        try enforcer.assertCanActivate(manifest, modelsCached: false)
        guard role == .networkPluginHost || enforcer.allowInProcessNetworkEscape else {
            throw PluginCapabilityError.networkDeniedInMainProcess(pluginID: manifest.id)
        }
        // Phase 1: activation of Parakeet performs downloadAndLoad internally.
        // Phase 2 XPC host will own the HF download here without returning raw weights to UI.
        if let engine = PluginRegistry.shared.makeASR(id: manifest.id) {
            try await engine.activate()
            await engine.deactivate()
        }
    }
}
