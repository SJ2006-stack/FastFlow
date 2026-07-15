import Foundation
import os

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
    private let words = OSAllocatedUnfairLock(initialState: [String: BiasedWord]())

    public init() {}

    public func activate() async throws { isActive = true }
    public func deactivate() async { isActive = false }

    public func allWords() async throws -> [BiasedWord] {
        words.withLock { dict in
            Array(dict.values).sorted { $0.word < $1.word }
        }
    }

    public func upsert(_ word: BiasedWord) async throws {
        words.withLock { $0[word.word.lowercased()] = word }
    }

    public func remove(word: String) async throws {
        words.withLock { $0.removeValue(forKey: word.lowercased()) }
    }
}

/// File-backed bias store under Application Support (JSON skeleton).
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
    private let cache = OSAllocatedUnfairLock(initialState: [String: BiasedWord]())

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
        let loaded = Self.load(from: fileURL)
        cache.withLock { $0 = loaded }
        isActive = true
    }

    public func deactivate() async {
        cache.withLock { $0.removeAll() }
        isActive = false
    }

    public func allWords() async throws -> [BiasedWord] {
        cache.withLock { dict in
            Array(dict.values).sorted { $0.word < $1.word }
        }
    }

    public func upsert(_ word: BiasedWord) async throws {
        let snapshot: [BiasedWord] = cache.withLock { dict in
            dict[word.word.lowercased()] = word
            return Array(dict.values)
        }
        try Self.save(snapshot, to: fileURL)
    }

    public func remove(word: String) async throws {
        let snapshot: [BiasedWord] = cache.withLock { dict in
            dict.removeValue(forKey: word.lowercased())
            return Array(dict.values)
        }
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
