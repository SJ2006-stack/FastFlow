import Foundation

/// Default in-memory bias list (always available).
public final class InMemoryBiasListStore: BiasListStore, @unchecked Sendable {
    public static let manifestID = "bias.memory"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "In-Memory Bias List",
        kind: .biasList,
        summary: "Ephemeral boost vocabulary for the current process.",
        approxActiveMemoryMB: 1,
        requiresNetwork: false
    )
    public private(set) var isActive = false
    private var words: [String: BiasedWord] = [:]
    private let lock = NSLock()

    public init() {}

    public func activate() async throws { isActive = true }
    public func deactivate() async { isActive = false }

    public func allWords() async throws -> [BiasedWord] {
        lock.lock(); defer { lock.unlock() }
        return Array(words.values).sorted { $0.word < $1.word }
    }

    public func upsert(_ word: BiasedWord) async throws {
        lock.lock(); defer { lock.unlock() }
        words[word.word.lowercased()] = word
    }

    public func remove(word: String) async throws {
        lock.lock(); defer { lock.unlock() }
        words.removeValue(forKey: word.lowercased())
    }
}

/// SQLite-backed store skeleton (Application Support). Uses Foundation only —
/// full GRDB integration can replace the file format later without changing
/// the `BiasListStore` protocol.
public final class SQLiteBiasListStore: BiasListStore, @unchecked Sendable {
    public static let manifestID = "bias.sqlite"
    public let manifest = PluginManifest(
        id: manifestID,
        name: "SQLite Bias List",
        kind: .biasList,
        summary: "Persists boost words under Application Support (JSON-lines skeleton).",
        approxActiveMemoryMB: 2,
        requiresNetwork: false
    )
    public private(set) var isActive = false
    private let fileURL: URL
    private var cache: [String: BiasedWord] = [:]
    private let lock = NSLock()

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("FastFlow", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("bias-list.jsonl")
        }
    }

    public func activate() async throws {
        lock.lock()
        defer { lock.unlock() }
        cache = Self.load(from: fileURL)
        isActive = true
    }

    public func deactivate() async {
        lock.lock()
        cache.removeAll()
        isActive = false
        lock.unlock()
    }

    public func allWords() async throws -> [BiasedWord] {
        lock.lock(); defer { lock.unlock() }
        return Array(cache.values).sorted { $0.word < $1.word }
    }

    public func upsert(_ word: BiasedWord) async throws {
        lock.lock()
        cache[word.word.lowercased()] = word
        let snapshot = Array(cache.values)
        lock.unlock()
        try Self.save(snapshot, to: fileURL)
    }

    public func remove(word: String) async throws {
        lock.lock()
        cache.removeValue(forKey: word.lowercased())
        let snapshot = Array(cache.values)
        lock.unlock()
        try Self.save(snapshot, to: fileURL)
    }

    private static func load(from url: URL) -> [String: BiasedWord] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([BiasedWord].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: decoded.map { ($0.word.lowercased(), $0) })
    }

    private static func save(_ words: [BiasedWord], to url: URL) throws {
        let data = try JSONEncoder().encode(words.sorted { $0.word < $1.word })
        try data.write(to: url, options: .atomic)
    }
}
