import Foundation

/// Base contract for every FastFlow model-backed plug-in.
///
/// Design rules (enforced by core + docs):
/// 1. Lazy-load — nothing heavy until `activate()` / `load()`.
/// 2. No network unless `requiresNetwork == true`.
/// 3. Release memory on idle via `deactivate()` / `unload()`.
/// 4. Report approximate resident footprint via `approxActiveMemoryMB`.
public protocol FastFlowPlugin: AnyObject, Sendable {
    var manifest: PluginManifest { get }
    var isActive: Bool { get }

    /// Load model weights / allocate inference resources.
    func activate() async throws
    /// Tear down and free real memory.
    func deactivate() async
}

public extension FastFlowPlugin {
    var name: String { manifest.name }
    var requiresNetwork: Bool { manifest.requiresNetwork }
    var approxActiveMemoryMB: Int { manifest.approxActiveMemoryMB }
}
