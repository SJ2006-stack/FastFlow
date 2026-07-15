import Foundation

/// In-process registry of plug-in factories + manifests for Settings / Model Zoo.
///
/// Community drop-ins under `fastflow-plugins/community/` can register at
/// launch via `PluginBootstrap.registerBuiltins()` (and later via manifests).
public final class PluginRegistry: @unchecked Sendable {
    public static let shared = PluginRegistry()

    private let lock = NSLock()
    private var manifests: [String: PluginManifest] = [:]
    private var asrFactories: [String: @Sendable () -> any ASREngine] = [:]
    private var vadFactories: [String: @Sendable () -> any VoiceActivityDetector] = [:]
    private var wakeFactories: [String: @Sendable () -> any WakeWordDetector] = [:]
    private var screenFactories: [String: @Sendable () -> any ScreenContextParser] = [:]
    private var biasFactories: [String: @Sendable () -> any BiasListStore] = [:]

    private init() {}

    public func registerASR(_ factory: @escaping @Sendable () -> any ASREngine) {
        let engine = factory()
        lock.lock()
        defer { lock.unlock() }
        manifests[engine.manifest.id] = engine.manifest
        asrFactories[engine.manifest.id] = factory
    }

    public func registerVAD(_ factory: @escaping @Sendable () -> any VoiceActivityDetector) {
        let engine = factory()
        lock.lock()
        defer { lock.unlock() }
        manifests[engine.manifest.id] = engine.manifest
        vadFactories[engine.manifest.id] = factory
    }

    public func registerWakeWord(_ factory: @escaping @Sendable () -> any WakeWordDetector) {
        let engine = factory()
        lock.lock()
        defer { lock.unlock() }
        manifests[engine.manifest.id] = engine.manifest
        wakeFactories[engine.manifest.id] = factory
    }

    public func registerScreen(_ factory: @escaping @Sendable () -> any ScreenContextParser) {
        let engine = factory()
        lock.lock()
        defer { lock.unlock() }
        manifests[engine.manifest.id] = engine.manifest
        screenFactories[engine.manifest.id] = factory
    }

    public func registerBiasStore(_ factory: @escaping @Sendable () -> any BiasListStore) {
        let engine = factory()
        lock.lock()
        defer { lock.unlock() }
        manifests[engine.manifest.id] = engine.manifest
        biasFactories[engine.manifest.id] = factory
    }

    public func allManifests(kind: PluginKind? = nil) -> [PluginManifest] {
        lock.lock()
        defer { lock.unlock() }
        let values = Array(manifests.values)
        guard let kind else { return values.sorted { $0.name < $1.name } }
        return values.filter { $0.kind == kind }.sorted { $0.name < $1.name }
    }

    public func makeASR(id: String) -> (any ASREngine)? {
        lock.lock()
        let factory = asrFactories[id]
        lock.unlock()
        return factory?()
    }

    /// Instantiates ASR and refuses networked plugins in the main process
    /// (unless models are cached for a trusted offline allowlist entry).
    public func makeASRAuthorized(
        id: String,
        enforcer: PluginCapabilityEnforcer = PluginCapabilityEnforcer(),
        modelsCached: Bool? = nil
    ) throws -> any ASREngine {
        guard let engine = makeASR(id: id) else {
            throw ASREngineError.underlying("Unknown ASR plugin id: \(id)")
        }
        let cached: Bool
        if let modelsCached {
            cached = modelsCached
        } else if id == ParakeetTDTEngine.manifestID {
            #if FASTFLOW_USE_FLUIDAUDIO
            cached = ParakeetTDTEngine.modelsCachedOnDisk()
            #else
            cached = false
            #endif
        } else {
            cached = !engine.manifest.requiresNetwork
        }
        try enforcer.assertCanActivate(engine.manifest, modelsCached: cached)
        return engine
    }

    public func makeVAD(id: String) -> (any VoiceActivityDetector)? {
        lock.lock()
        let factory = vadFactories[id]
        lock.unlock()
        return factory?()
    }

    public func makeWakeWord(id: String) -> (any WakeWordDetector)? {
        lock.lock()
        let factory = wakeFactories[id]
        lock.unlock()
        return factory?()
    }

    public func makeScreen(id: String) -> (any ScreenContextParser)? {
        lock.lock()
        let factory = screenFactories[id]
        lock.unlock()
        return factory?()
    }

    public func makeBiasStore(id: String) -> (any BiasListStore)? {
        lock.lock()
        let factory = biasFactories[id]
        lock.unlock()
        return factory?()
    }

    public func defaultASRID() -> String {
        #if FASTFLOW_USE_FLUIDAUDIO
        return ParakeetTDTEngine.manifestID
        #else
        return StubASREngine.manifestID
        #endif
    }
}
