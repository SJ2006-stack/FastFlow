import XCTest
@testable import FastFlowPlugins

final class PluginRegistryTests: XCTestCase {
    func testBuiltinRegistrationListsASREngines() {
        PluginBootstrap.registerBuiltins()
        let asr = PluginRegistry.shared.allManifests(kind: .asr)
        XCTAssertTrue(asr.contains(where: { $0.id == StubASREngine.manifestID }))
        XCTAssertFalse(asr.isEmpty)
    }

    func testStubTranscribe() async throws {
        let engine = StubASREngine()
        try await engine.activate()
        let text = try await engine.transcribe([Float](repeating: 0.1, count: 16_000))
        XCTAssertTrue(text.contains("stub"))
        await engine.deactivate()
        XCTAssertFalse(engine.isActive)
    }

    func testEnergyVAD() async throws {
        let vad = EnergyVADDetector()
        try await vad.activate()
        let silent = AudioFrame(samples: [Float](repeating: 0, count: 1600))
        let loud = AudioFrame(samples: [Float](repeating: 0.5, count: 1600))
        let speechSilent = await vad.isSpeech(silent)
        let speechLoud = await vad.isSpeech(loud)
        XCTAssertFalse(speechSilent)
        XCTAssertTrue(speechLoud)
    }

    func testBiasStoreRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fastflow-bias-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = SQLiteBiasListStore(fileURL: url)
        try await store.activate()
        try await store.upsert(BiasedWord(word: "FastFlow", weight: 2))
        let words = try await store.allWords()
        XCTAssertEqual(words.first?.word, "FastFlow")
    }

    func testCapabilityEnforcerDeniesNetworkInMain() {
        let enforcer = PluginCapabilityEnforcer(role: .mainApp, allowInProcessNetworkEscape: false)
        let networked = PluginManifest(
            id: "asr.evil",
            name: "Evil",
            kind: .asr,
            summary: "lies",
            approxActiveMemoryMB: 10,
            requiresNetwork: true
        )
        XCTAssertThrowsError(try enforcer.assertCanActivate(networked, modelsCached: false))
    }

    func testCapabilityEnforcerAllowsNetworkHost() throws {
        let enforcer = PluginCapabilityEnforcer(role: .networkPluginHost, allowInProcessNetworkEscape: false)
        let networked = PluginManifest(
            id: "asr.remote",
            name: "Remote",
            kind: .asr,
            summary: "ok on host",
            approxActiveMemoryMB: 10,
            requiresNetwork: true
        )
        try enforcer.assertCanActivate(networked, modelsCached: false)
    }

    func testColdStartStubBenchmark() async throws {
        let engine = StubASREngine()
        let result = try await ASRColdStartBenchmark.run(engine: engine, mode: "cold")
        XCTAssertGreaterThanOrEqual(result.loadMilliseconds, 0)
        XCTAssertLessThan(result.loadMilliseconds, ColdStartAcceptance.timeToReadyAfterIdleMS)
        XCTAssertFalse(result.transcriptPreview.isEmpty)
    }
}
