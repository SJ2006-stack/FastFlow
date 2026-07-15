import AppKit
import AudioToolbox
import Foundation
import FastFlowPlugins

enum MenuBarIconState: Equatable {
    case idle
    case listening(level: Float)
    case transcribing
    case error
    case loading
}

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private var menu: NSMenu
    var onQuit: (() -> Void)?
    var onWarmUp: (() -> Void)?
    var onUseStub: (() -> Void)?
    var onUseParakeet: (() -> Void)?
    var onDownloadModel: (() -> Void)?
    var onShowPlugins: (() -> Void)?
    var onSelectEngine: ((String) -> Void)?
    var onConfigureAPIKeys: (() -> Void)?

    private(set) var state: MenuBarIconState = .idle {
        didSet { render() }
    }

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        super.init()
        if let button = statusItem.button {
            button.image = Self.symbol("mic")
            button.image?.isTemplate = true
        }
        rebuildMenu()
        statusItem.menu = menu
        render()
    }

    func setState(_ state: MenuBarIconState) {
        self.state = state
    }

    func rebuildMenu(
        engineName: String = "—",
        pluginCount: Int = 0,
        modelsCached: Bool = false,
        localEngines: [PluginManifest] = [],
        cloudEngines: [PluginManifest] = [],
        selectedID: String? = nil
    ) {
        menu.removeAllItems()
        menu.addItem(withTitle: "FastFlow", action: nil, keyEquivalent: "")
        menu.items.last?.isEnabled = false
        menu.addItem(withTitle: "Dictate: hold Right Option", action: nil, keyEquivalent: "")
        menu.items.last?.isEnabled = false
        menu.addItem(withTitle: "Engine: \(engineName)", action: nil, keyEquivalent: "")
        menu.items.last?.isEnabled = false
        let modelStatus = modelsCached
            ? "Local model: ready (on disk)"
            : "Local model: stub (download Parakeet for free offline ASR)"
        menu.addItem(withTitle: modelStatus, action: nil, keyEquivalent: "")
        menu.items.last?.isEnabled = false
        menu.addItem(.separator())

        // Local free / enhanced
        let localHeader = NSMenuItem(title: "Local (free, default)", action: nil, keyEquivalent: "")
        localHeader.isEnabled = false
        menu.addItem(localHeader)
        if !modelsCached {
            menu.addItem(
                withTitle: "Download Parakeet (local)…",
                action: #selector(downloadModel),
                keyEquivalent: "d"
            )
        }
        for m in localEngines {
            let mark = (m.id == selectedID) ? "✓ " : "    "
            let item = NSMenuItem(
                title: "\(mark)\(m.name)",
                action: #selector(selectEngine(_:)),
                keyEquivalent: ""
            )
            item.representedObject = m.id
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let cloudHeader = NSMenuItem(
            title: "Cloud plugins (better / custom)",
            action: nil,
            keyEquivalent: ""
        )
        cloudHeader.isEnabled = false
        menu.addItem(cloudHeader)
        for m in cloudEngines {
            let mark = (m.id == selectedID) ? "✓ " : "    "
            let item = NSMenuItem(
                title: "\(mark)\(m.name)",
                action: #selector(selectEngine(_:)),
                keyEquivalent: ""
            )
            item.representedObject = m.id
            menu.addItem(item)
        }
        menu.addItem(
            withTitle: "Configure Cloud API Keys…",
            action: #selector(configureKeys),
            keyEquivalent: ""
        )

        menu.addItem(.separator())
        menu.addItem(withTitle: "Warm Up Model", action: #selector(warmUp), keyEquivalent: "w")
        menu.addItem(withTitle: "List Model Zoo…", action: #selector(showPlugins), keyEquivalent: "")
        menu.addItem(.separator())
        let perms = NSMenuItem(title: "Permissions: \(PermissionGate.statusSummary())", action: nil, keyEquivalent: "")
        perms.isEnabled = false
        menu.addItem(perms)
        menu.addItem(withTitle: "Request Microphone…", action: #selector(reqMic), keyEquivalent: "")
        menu.addItem(withTitle: "Request Accessibility…", action: #selector(reqAX), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit FastFlow", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items where item.action != nil {
            item.target = self
        }
        statusItem.menu = menu
        _ = pluginCount
    }

    private func render() {
        guard let button = statusItem.button else { return }
        switch state {
        case .idle:
            button.image = Self.symbol("mic")
            button.title = ""
            button.contentTintColor = nil
        case .listening(let level):
            button.image = Self.symbol("mic.fill")
            let bars = Int((level * 4).rounded())
            button.title = String(repeating: "▌", count: max(1, bars))
            button.contentTintColor = .systemRed
        case .transcribing:
            button.image = Self.symbol("ellipsis.circle")
            button.title = ""
            button.contentTintColor = .systemOrange
        case .error:
            button.image = Self.symbol("exclamationmark.triangle")
            button.title = ""
            button.contentTintColor = .systemRed
        case .loading:
            button.image = Self.symbol("arrow.down.circle")
            button.title = ""
            button.contentTintColor = .systemBlue
        }
        button.image?.isTemplate = true
    }

    private static func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: name)
    }

    @objc private func quit() { onQuit?() }
    @objc private func warmUp() { onWarmUp?() }
    @objc private func useStub() { onUseStub?() }
    @objc private func useParakeet() { onUseParakeet?() }
    @objc private func downloadModel() { onDownloadModel?() }
    @objc private func showPlugins() { onShowPlugins?() }
    @objc private func configureKeys() { onConfigureAPIKeys?() }
    @objc private func selectEngine(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        onSelectEngine?(id)
    }
    @objc private func reqMic() {
        Task { _ = await PermissionGate.requestMicrophone() }
    }
    @objc private func reqAX() { PermissionGate.promptAccessibility() }
}

enum ChimePlayer {
    static func playStart() {
        AudioServicesPlaySystemSound(1113)
    }

    static func playStop() {
        AudioServicesPlaySystemSound(1114)
    }
}
