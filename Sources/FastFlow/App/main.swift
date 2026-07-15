import AppKit
import FastFlowPlugins
import Foundation

@main
enum FastFlowMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // LSUIElement-style menu bar app
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

        // Lazy by default — do not download Parakeet until first warm-up or first release.
        // Still activate stub instantly for path testing.
        if preference == .stub {
            Task { await session.warmUp() }
        }

        NSLog("FastFlow ready — hold Right Option to dictate (engine=\(session.engineName))")
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
            guard let self else { return }
            self.preference = .stub
            Task {
                await self.session.replaceEngine(AppConfig.makeASREngine(preference: .stub))
                await self.session.warmUp()
                self.refreshMenu()
            }
        }
        status.onUseParakeet = { [weak self] in
            guard let self else { return }
            self.preference = .parakeet
            Task {
                await self.session.replaceEngine(AppConfig.makeASREngine(preference: .parakeet))
                await self.session.warmUp()
                self.refreshMenu()
            }
        }
        status.onShowPlugins = { [weak self] in
            self?.showModelZooAlert()
        }
    }

    private func refreshMenu() {
        let count = PluginRegistry.shared.allManifests().count
        status.rebuildMenu(engineName: session.engineName, pluginCount: count)
    }

    private func showModelZooAlert() {
        let manifests = PluginRegistry.shared.allManifests()
        let lines = manifests.map { m in
            "• [\(m.kind.rawValue)] \(m.name) — ~\(m.approxActiveMemoryMB) MB\(m.requiresNetwork ? " (network)" : "")"
        }.joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = "FastFlow Model Zoo"
        alert.informativeText = lines.isEmpty ? "No plugins registered." : lines
        alert.runModal()
    }
}
