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
    private var blob: CornerBlobHUD!
    private var preference: ASRBackendPreference = AppConfig.preferredBackend

    func applicationDidFinishLaunching(_ notification: Notification) {
        PluginBootstrap.registerBuiltins()

        // 1) Model choice
        if !ModelSelectionStore.hasCompletedModelOnboarding {
            NSApp.activate(ignoringOtherApps: true)
            applyModelChoice(FirstRunModelPicker.runModal(isFirstLaunch: true), markOnboardingComplete: true)
        }

        // 2) Permissions → custom hotkey (default Spacebar) → blob corner
        let setup = SetupWizard.runIfNeeded()

        let engine = AppConfig.makeASREngine(preference: preference)
        session = DictationSession(engine: engine)
        status = StatusItemController()
        status.setHotkeyLabel(setup.hotkey.name)
        blob = CornerBlobHUD(corner: setup.corner)
        blob.show()
        wireUI()
        refreshMenu()

        session.onStateChange = { [weak self] state in
            self?.status.setState(state)
            self?.blob.setState(state)
        }
        session.onEngineChange = { [weak self] _ in
            self?.refreshMenu()
        }

        hotkey = HotkeyMonitor(choice: setup.hotkey)
        hotkey.onDown = { [weak self] in self?.session.beginListening() }
        hotkey.onUp = { [weak self] in self?.session.endListening() }

        do {
            try hotkey.start()
        } catch {
            NSLog("FastFlow hotkey: \(error.localizedDescription)")
            PermissionGate.promptAccessibility()
            status.setState(.error)
            blob.setState(.error)
        }

        Task { await session.warmUp() }

        if preference == .parakeet || ModelSelectionStore.selectedASRID == ParakeetTDTEngine.manifestID,
           !AppConfig.parakeetModelsCached {
            downloadSpeechModel(silentConfirm: ModelSelectionStore.hasCompletedModelOnboarding)
        }

        NSLog(
            "FastFlow ready — hotkey=\(setup.hotkey.name) blob=\(setup.corner.rawValue) engine=\(session.engineName)"
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey?.stop()
        blob?.hide()
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
        status.onChangeModel = { [weak self] in
            self?.reopenModelPicker()
        }
        status.onAddBYO = { [weak self] in
            self?.addBYOModel()
        }
        status.onChangeHotkey = { [weak self] in
            self?.changeHotkey()
        }
        status.onShowBlob = { [weak self] in
            BlobPreferences.isVisible = true
            self?.blob.show()
        }
        status.onMoveBlob = { [weak self] in
            self?.moveBlobCorner()
        }
        status.onRerunSetup = { [weak self] in
            HotkeyPreferences.hasCompletedSetupWizard = false
            let setup = SetupWizard.runIfNeeded()
            self?.status.setHotkeyLabel(setup.hotkey.name)
            do {
                try self?.hotkey.applyPreset(setup.hotkey)
            } catch {
                NSLog("FastFlow hotkey restart failed: \(error.localizedDescription)")
            }
            self?.blob.setCorner(setup.corner)
            BlobPreferences.isVisible = true
            self?.blob.show()
            self?.refreshMenu()
        }
    }

    private func changeHotkey() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Choose your push-to-talk key"
        alert.informativeText = "Hold to dictate, release to insert. Default is Spacebar."
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28), pullsDown: false)
        for preset in HotkeyMonitor.Preset.all {
            popup.addItem(withTitle: preset.name)
            popup.lastItem?.representedObject = preset.id
            if preset.id == HotkeyPreferences.presetID {
                popup.select(popup.lastItem)
            }
        }
        alert.accessoryView = popup
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let id = (popup.selectedItem?.representedObject as? String) ?? HotkeyMonitor.Preset.space.id
        let preset = HotkeyMonitor.Preset.all.first { $0.id == id } ?? .space
        do {
            try hotkey.applyPreset(preset)
            status.setHotkeyLabel(preset.name)
            refreshMenu()
        } catch {
            NSLog("FastFlow hotkey change failed: \(error.localizedDescription)")
            PermissionGate.promptAccessibility()
        }
    }

    private func moveBlobCorner() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Park the FastFlow blob"
        alert.informativeText = "Click the blob anytime to cycle corners."
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 28), pullsDown: false)
        for corner in BlobCorner.allCases {
            popup.addItem(withTitle: corner.displayName)
            popup.lastItem?.representedObject = corner.rawValue
            if corner == BlobPreferences.corner {
                popup.select(popup.lastItem)
            }
        }
        alert.accessoryView = popup
        alert.addButton(withTitle: "Move")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let raw = (popup.selectedItem?.representedObject as? String) ?? BlobCorner.bottomRight.rawValue
        let corner = BlobCorner(rawValue: raw) ?? .bottomRight
        BlobPreferences.isVisible = true
        blob.setCorner(corner)
        blob.show()
    }

    private func reopenModelPicker() {
        NSApp.activate(ignoringOtherApps: true)
        guard let choice = FirstRunModelPicker.runModalOptional(isFirstLaunch: false) else { return }
        applyModelChoice(choice, markOnboardingComplete: true)
        Task {
            status.setState(.loading)
            await session.replaceEngine(AppConfig.makeASREngine(preference: preference))
            await session.warmUp()
            refreshMenu()
        }
    }

    private func addBYOModel() {
        NSApp.activate(ignoringOtherApps: true)
        guard let config = FirstRunModelPicker.promptBYOConfig() else { return }
        BYOPluginRegistrar.registerAllPersisted()
        applyModelChoice(.byoCustom, markOnboardingComplete: true, byoID: config.id)
        Task {
            status.setState(.loading)
            PluginCapabilityEnforcer.beginUserInitiatedModelDownload()
            defer { PluginCapabilityEnforcer.endUserInitiatedModelDownload() }
            await session.replaceEngine(AppConfig.selectEngine(id: config.id))
            await session.warmUp()
            refreshMenu()
        }
    }

    /// Maps picker choice → selection store + preference (+ optional key prompts).
    private func applyModelChoice(
        _ choice: FirstRunModelPicker.Choice,
        markOnboardingComplete: Bool,
        byoID: String? = nil
    ) {
        switch choice {
        case .freeLocalParakeet:
            preference = .parakeet
            ModelSelectionStore.selectedASRID = ParakeetTDTEngine.manifestID
        case .freeLocalStub:
            preference = .stub
            ModelSelectionStore.selectedASRID = StubASREngine.manifestID
        case .cloudHuggingFace:
            preference = .huggingface
            ModelSelectionStore.selectedASRID = HuggingFaceASREngine.manifestID
            promptSingleAPIKey(family: .huggingface, label: "Hugging Face token")
        case .cloudOpenRouter:
            preference = .openrouter
            ModelSelectionStore.selectedASRID = OpenRouterASREngine.manifestID
            promptSingleAPIKey(family: .openrouter, label: "OpenRouter API key")
        case .cloudGemini:
            preference = .gemini
            ModelSelectionStore.selectedASRID = GeminiASREngine.manifestID
            promptSingleAPIKey(family: .gemini, label: "Gemini API key")
        case .byoCustom:
            if let byoID {
                preference = .auto
                ModelSelectionStore.selectedASRID = byoID
            } else if let config = FirstRunModelPicker.promptBYOConfig() {
                BYOPluginRegistrar.registerAllPersisted()
                preference = .auto
                ModelSelectionStore.selectedASRID = config.id
            } else {
                preference = .stub
                ModelSelectionStore.selectedASRID = StubASREngine.manifestID
            }
        }
        if markOnboardingComplete {
            ModelSelectionStore.hasCompletedModelOnboarding = true
        }
    }

    private func promptSingleAPIKey(family: ModelProviderFamily, label: String) {
        let alert = NSAlert()
        alert.messageText = label
        alert.informativeText = "Required for this BYO cloud engine. Stored in Keychain on this Mac."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = ModelSelectionStore.apiKey(for: family) ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            ModelSelectionStore.setAPIKey(field.stringValue, for: family)
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
            let isCloud = AppConfig.cloudASRManifests().contains(where: { $0.id == id })
                || id.hasPrefix("asr.byo.")
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

    private func downloadSpeechModel(silentConfirm: Bool = false) {
        if !silentConfirm {
            let alert = NSAlert()
            alert.messageText = "Download FREE local speech model?"
            alert.informativeText = """
            Parakeet TDT v3 (~500–600 MB) — free, on-device, offline after download.

            BYO / cloud models are separate (menu → Change Model… or Add BYO Model…).
            """
            alert.addButton(withTitle: "Download FREE model")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        preference = .parakeet
        ModelSelectionStore.selectedASRID = ParakeetTDTEngine.manifestID
        Task {
            status.setState(.loading)
            PluginCapabilityEnforcer.beginUserInitiatedModelDownload()
            defer { PluginCapabilityEnforcer.endUserInitiatedModelDownload() }
            // Session may not exist yet during first-run before session init.
            if session != nil {
                await session.replaceEngine(AppConfig.makeASREngine(preference: .parakeet))
                await session.warmUp()
                refreshMenu()
            }
            if AppConfig.parakeetModelsCached {
                let done = NSAlert()
                done.messageText = "FREE local model ready"
                done.informativeText = "Parakeet is cached. Hold \(HotkeyPreferences.currentPreset.name) — private & offline."
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
            promptSingleAPIKey(family: family, label: label)
        }
        refreshMenu()
    }

    private func refreshMenu() {
        guard session != nil, status != nil else { return }
        let selected = ModelSelectionStore.selectedASRID ?? session.engineID
        let byo = ModelSelectionStore.byoConfigs().map {
            PluginManifest(
                id: $0.id,
                name: $0.displayName,
                kind: .asr,
                summary: "BYO",
                approxActiveMemoryMB: 15,
                requiresNetwork: true,
                inferenceTier: .cloudPlugin,
                providerFamily: .custom,
                remoteModelID: $0.remoteModelID
            )
        }
        status.rebuildMenu(
            engineName: session.engineName,
            pluginCount: PluginRegistry.shared.allManifests().count,
            modelsCached: AppConfig.parakeetModelsCached,
            localEngines: AppConfig.localASRManifests(),
            cloudEngines: AppConfig.cloudASRManifests() + byo,
            selectedID: selected
        )
    }

    private func showModelZooAlert() {
        let local = AppConfig.localASRManifests().map {
            "• FREE [\($0.inferenceTier.rawValue)] \($0.name)"
        }
        let cloud = AppConfig.cloudASRManifests().map {
            let keyed = ModelSelectionStore.hasAPIKey(for: $0.providerFamily) ? "key✓" : "key✗"
            return "• BYO [\($0.providerFamily.rawValue)] \($0.name) (\(keyed))"
        }
        let byo = ModelSelectionStore.byoConfigs().map {
            "• BYO custom \($0.displayName)"
        }
        let body = (
            ["FREE — local (default):"] + local + [""]
                + ["BYO — cloud / your models:"] + cloud + byo + [""]
                + ["Devs: implement ASREngine or Add BYO Model… — FastFlow is the interface."]
        ).joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = "FastFlow Model Zoo"
        alert.informativeText = body
        alert.runModal()
    }
}
