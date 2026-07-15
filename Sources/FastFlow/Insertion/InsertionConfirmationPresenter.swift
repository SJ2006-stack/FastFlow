import AppKit
import Foundation

/// Floating confirmation when insertion is ambiguous/unavailable.
/// Never silently guess — user places or copies.
@MainActor
final class InsertionConfirmationPresenter {
    private var panel: NSPanel?
    private var textView: NSTextView?

    func present(transcript: String, reason: String) {
        dismiss()

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "FastFlow — confirm insert"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.center()

        let container = NSView(frame: panel.contentView!.bounds)
        container.autoresizingMask = [.width, .height]

        let reasonLabel = NSTextField(wrappingLabelWithString: reason)
        reasonLabel.frame = NSRect(x: 16, y: 168, width: 388, height: 36)
        reasonLabel.textColor = .secondaryLabelColor
        reasonLabel.font = .systemFont(ofSize: 12)
        container.addSubview(reasonLabel)

        let scroll = NSScrollView(frame: NSRect(x: 16, y: 56, width: 388, height: 104))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autoresizingMask = [.width, .height]

        let tv = NSTextView(frame: scroll.contentView.bounds)
        tv.string = transcript
        tv.isEditable = true
        tv.font = .systemFont(ofSize: 13)
        tv.autoresizingMask = [.width]
        scroll.documentView = tv
        container.addSubview(scroll)
        textView = tv

        let copyBtn = NSButton(
            title: "Copy",
            target: self,
            action: #selector(copyTranscript)
        )
        copyBtn.frame = NSRect(x: 16, y: 14, width: 90, height: 32)
        container.addSubview(copyBtn)

        let pasteBtn = NSButton(
            title: "Paste now",
            target: self,
            action: #selector(pasteNow)
        )
        pasteBtn.frame = NSRect(x: 116, y: 14, width: 110, height: 32)
        pasteBtn.keyEquivalent = "\r"
        container.addSubview(pasteBtn)

        let dismissBtn = NSButton(
            title: "Dismiss",
            target: self,
            action: #selector(dismissAction)
        )
        dismissBtn.frame = NSRect(x: 314, y: 14, width: 90, height: 32)
        container.addSubview(dismissBtn)

        panel.contentView = container
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        textView = nil
    }

    @objc private func copyTranscript() {
        let text = textView?.string ?? ""
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func pasteNow() {
        let text = textView?.string ?? ""
        dismiss()
        // Explicit user action — clipboard paste is intentional, not a silent guess.
        _ = PasteService.paste(text)
    }

    @objc private func dismissAction() {
        dismiss()
    }
}
