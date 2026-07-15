import AppKit
import FastFlowPlugins
import Foundation

@main
enum FastFlowMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: StatusItemController!
    private var hotkey: HotkeyMonitor!
    private var session: DictationSession!
    private var preference: ASRBackendPreference = AppConfig.preferredBackend

    func applicationDidFinishLaunching(_ notification: Notification) {
        PluginBootstrap.registerBuiltins()

        let engine = AppConfig.makeASREngine(preference: preference)
        session = DictationSession(engine: engine)
        status = StatusItemController()
        wireUI()
        refreshMenu()

        session.onStateChange = { [weak self] state in
            self?.status.setState(state)
        }
        session.onEngineChange = { [weak self] _ in
            self?.refreshMenu()
        }

        hotkey = HotkeyMonitor()
        hotkey.onDown = { [weak self] in self?.session.beginListening() }
        hotkey.onUp = { [weak self] in self?.session.endListening() }

        do {
            try hotkey.start()
        } catch {
            NSLog("FastFlow hotkey: \(error.localizedDescription)")
            PermissionGate.promptAccessibility()
            status.setState(.error)
        }

        // Local free default — warm stub/Parakeet path without cloud.
        Task { await session.warmUp() }

        NSLog(
            "FastFlow ready — local-first engine=\(session.engineName). Hold Right Option. Cloud plugins optional."
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey?.stop()
        let session = self.session
        let sem = DispatchSemaphore(value: 0)
        Task { @MainActor in
            await session?.shutdown()
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 2)
    }

    private func wireUI() {
        status.onQuit = { NSApp.terminate(nil) }
        status.onWarmUp = { [weak self] in
            Task { await self?.session.warmUp() }
        }
        status.onUseStub = { [weak self] in
            self?.switchTo(preference: .stub, id: StubASREngine.manifestID)
        }
        status.onUseParakeet = { [weak self] in
            self?.switchTo(preference: .parakeet, id: ParakeetTDTEngine.manifestID)
        }
        status.onDownloadModel = { [weak self] in
            self?.downloadSpeechModel()
        }
        status.onShowPlugins = { [weak self] in
            self?.showModelZooAlert()
        }
        status.onSelectEngine = { [weak self] id in
            self?.switchToEngineID(id)
        }
        status.onConfigureAPIKeys = { [weak self] in
            self?.configureAPIKeys()
        }
    }

    private func switchTo(preference: ASRBackendPreference, id: String) {
        self.preference = preference
        ModelSelectionStore.selectedASRID = id
        Task {
            status.setState(.loading)
            await session.replaceEngine(AppConfig.makeASREngine(preference: preference))
            await session.warmUp()
            refreshMenu()
        }
    }

    private func switchToEngineID(_ id: String) {
        ModelSelectionStore.selectedASRID = id
        preference = .auto
        Task {
            status.setState(.loading)
            // Cloud engines need in-process network until NetworkPluginHost ships.
            let isCloud = AppConfig.cloudASRManifests().contains(where: { $0.id == id })
            if isCloud {
                PluginCapabilityEnforcer.beginUserInitiatedModelDownload()
            }
            defer {
                if isCloud { PluginCapabilityEnforcer.endUserInitiatedModelDownload() }
            }
            await session.replaceEngine(AppConfig.selectEngine(id: id))
            await session.warmUp()
            refreshMenu()
        }
    }

    private func downloadSpeechModel() {
        let alert = NSAlert()
        alert.messageText = "Download free local speech model?"
        alert.informativeText = """
        FastFlow defaults to on-device models (no cloud).

        Parakeet TDT v3 is ~500–600 MB, downloaded once into Application Support, then works offline for free.

        Cloud plugins (Hugging Face / OpenRouter / Gemini) are separate — configure API keys if you want those.
        """
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        preference = .parakeet
        ModelSelectionStore.selectedASRID = ParakeetTDTEngine.manifestID
        Task {
            status.setState(.loading)
            PluginCapabilityEnforcer.beginUserInitiatedModelDownload()
            defer { PluginCapabilityEnforcer.endUserInitiatedModelDownload() }
            await session.replaceEngine(AppConfig.makeASREngine(preference: .parakeet))
            await session.warmUp()
            refreshMenu()
            if AppConfig.parakeetModelsCached {
                let done = NSAlert()
                done.messageText = "Local model ready"
                done.informativeText = "Parakeet is cached. Hold Right Option — works offline, no API key."
                done.runModal()
            }
        }
    }

    private func configureAPIKeys() {
        let families: [(ModelProviderFamily, String)] = [
            (.huggingface, "Hugging Face token"),
            (.openrouter, "OpenRouter API key"),
            (.gemini, "Google Gemini API key"),
        ]
        for (family, label) in families {
            let alert = NSAlert()
            alert.messageText = label
            alert.informativeText = """
            Paste your key for \(family.rawValue) cloud ASR plugins.
            Leave empty to clear. Keys stay on this Mac (Keychain).
            Local models never need a key.
            """
            let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
            field.stringValue = ModelSelectionStore.apiKey(for: family) ?? ""
            alert.accessoryView = field
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Skip")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                ModelSelectionStore.setAPIKey(field.stringValue, for: family)
            }
        }
        let done = NSAlert()
        done.messageText = "Cloud keys updated"
        done.informativeText = "Pick a cloud engine under “Cloud plugins” in the menu when you want remote inference."
        done.runModal()
        refreshMenu()
    }

    private func refreshMenu() {
        let selected = ModelSelectionStore.selectedASRID ?? session.engineID
        status.rebuildMenu(
            engineName: session.engineName,
            pluginCount: PluginRegistry.shared.allManifests().count,
            modelsCached: AppConfig.parakeetModelsCached,
            localEngines: AppConfig.localASRManifests(),
            cloudEngines: AppConfig.cloudASRManifests(),
            selectedID: selected
        )
    }

    private func showModelZooAlert() {
        let local = AppConfig.localASRManifests().map {
            "• [local/\($0.inferenceTier.rawValue)] \($0.name)"
        }
        let cloud = AppConfig.cloudASRManifests().map {
            let keyed = ModelSelectionStore.hasAPIKey(for: $0.providerFamily) ? "key✓" : "key✗"
            return "• [cloud/\($0.providerFamily.rawValue)] \($0.name) (\(keyed))"
        }
        let body = (["Local free / enhanced:"] + local + [""] + ["Cloud plugins:"] + cloud)
            .joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = "FastFlow Model Zoo"
        alert.informativeText = body
        alert.runModal()
    }
}
