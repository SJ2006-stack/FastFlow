import AppKit
import FastFlowPlugins
import Foundation

/// First-launch (and “Change Model…”) picker.
/// FREE local defaults vs BYO / cloud for higher accuracy — FastFlow as the interface.
@MainActor
enum FirstRunModelPicker {
    enum Choice: Equatable {
        case freeLocalParakeet
        case freeLocalStub
        case cloudHuggingFace
        case cloudOpenRouter
        case cloudGemini
        case byoCustom
    }

    /// Blocks until the user picks. Returns the choice (and may collect BYO fields).
    static func runModal(isFirstLaunch: Bool) -> Choice {
        let alert = NSAlert()
        alert.messageText = isFirstLaunch ? "Welcome to FastFlow" : "Choose your speech model"
        alert.informativeText = """
        FastFlow is a dictation interface. Pick how transcription runs:

        • FREE — on-device models (private, low memory, no API key)
        • BYO / Cloud — fuse your own model or API for higher accuracy

        Hold Right Option anytime to dictate after you choose.
        """

        // Accessory: radio-style popup
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 420, height: 28), pullsDown: false)
        popup.addItem(withTitle: "FREE — Parakeet (local, recommended)")
        popup.addItem(withTitle: "FREE — Stub (tiny, testing only)")
        popup.addItem(withTitle: "BYO — Hugging Face (your token + model)")
        popup.addItem(withTitle: "BYO — OpenRouter (your key + model)")
        popup.addItem(withTitle: "BYO — Gemini (your Google AI key)")
        popup.addItem(withTitle: "BYO — Custom HTTPS endpoint (developers)")
        popup.selectItem(at: 0)

        let hint = NSTextField(wrappingLabelWithString: """
        Developers: treat FastFlow as a framework — implement ASREngine or register a BYO endpoint. Free local engines work with zero code.
        """)
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.preferredMaxLayoutWidth = 420

        stack.addArrangedSubview(popup)
        stack.addArrangedSubview(hint)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 90))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        alert.accessoryView = container
        alert.addButton(withTitle: "Continue")
        if !isFirstLaunch {
            alert.addButton(withTitle: "Cancel")
        }

        let response = alert.runModal()
        if !isFirstLaunch, response != .alertFirstButtonReturn {
            return .freeLocalStub // ignored by caller on cancel — use optional instead
        }

        switch popup.indexOfSelectedItem {
        case 0: return .freeLocalParakeet
        case 1: return .freeLocalStub
        case 2: return .cloudHuggingFace
        case 3: return .cloudOpenRouter
        case 4: return .cloudGemini
        default: return .byoCustom
        }
    }

    /// Returns nil if user cancelled a non-first-launch picker.
    static func runModalOptional(isFirstLaunch: Bool) -> Choice? {
        if isFirstLaunch {
            return runModal(isFirstLaunch: true)
        }
        let alert = NSAlert()
        alert.messageText = "Choose your speech model"
        alert.informativeText = """
        FREE = on-device, no key. BYO = your model or API for higher accuracy.
        FastFlow stays the same interface either way.
        """
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 420, height: 28), pullsDown: false)
        popup.addItem(withTitle: "FREE — Parakeet (local, recommended)")
        popup.addItem(withTitle: "FREE — Stub (tiny, testing only)")
        popup.addItem(withTitle: "BYO — Hugging Face")
        popup.addItem(withTitle: "BYO — OpenRouter")
        popup.addItem(withTitle: "BYO — Gemini")
        popup.addItem(withTitle: "BYO — Custom HTTPS endpoint")
        popup.selectItem(at: 0)
        alert.accessoryView = popup
        alert.addButton(withTitle: "Use this model")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        switch popup.indexOfSelectedItem {
        case 0: return .freeLocalParakeet
        case 1: return .freeLocalStub
        case 2: return .cloudHuggingFace
        case 3: return .cloudOpenRouter
        case 4: return .cloudGemini
        default: return .byoCustom
        }
    }

    /// Collect BYO custom endpoint fields.
    static func promptBYOConfig() -> ModelSelectionStore.BYOModelConfig? {
        let alert = NSAlert()
        alert.messageText = "Bring your own model"
        alert.informativeText = """
        Point FastFlow at any HTTPS ASR endpoint.
        WAV body (audio/wav) or JSON {\"audio_base64\",\"model\"}.
        Response JSON should include \"text\" or \"transcript\".
        """

        let nameField = NSTextField(string: "My ASR")
        nameField.placeholderString = "Display name"
        let urlField = NSTextField(string: "https://")
        urlField.placeholderString = "https://api.example.com/transcribe"
        let modelField = NSTextField(string: "")
        modelField.placeholderString = "Optional model id"
        let keyField = NSSecureTextField(string: "")
        keyField.placeholderString = "API key (optional for local LAN)"

        let stack = NSStackView(views: [
            labeled("Name", nameField),
            labeled("Endpoint", urlField),
            labeled("Model id", modelField),
            labeled("API key", keyField),
        ])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.alignment = .leading
        let wrap = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 140))
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            stack.topAnchor.constraint(equalTo: wrap.topAnchor),
            stack.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
        ])
        alert.accessoryView = wrap
        alert.addButton(withTitle: "Add model")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, url.hasPrefix("http") else { return nil }

        var config = ModelSelectionStore.BYOModelConfig(
            displayName: "BYO — \(name)",
            endpointURL: url,
            remoteModelID: modelField.stringValue.isEmpty ? nil : modelField.stringValue,
            bodyStyle: "audioWav"
        )
        // Prefer JSON if model id set (common for custom APIs).
        if config.remoteModelID != nil {
            config.bodyStyle = "jsonBase64"
        }
        ModelSelectionStore.upsertBYO(config)
        ModelSelectionStore.setBYOAPIKey(keyField.stringValue, forConfigID: config.id)
        return config
    }

    private static func labeled(_ title: String, _ field: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 360).isActive = true
        let row = NSStackView(views: [label, field])
        row.orientation = .vertical
        row.alignment = .leading
        row.spacing = 2
        return row
    }
}
