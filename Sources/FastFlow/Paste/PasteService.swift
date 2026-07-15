import AppKit
import CoreGraphics
import Foundation

/// Clipboard + synthetic Cmd+V, restoring the previous clipboard contents.
@MainActor
enum PasteService {
    private static let commandKey: CGKeyCode = 0x37
    private static let vKey: CGKeyCode = 0x09

    @discardableResult
    static func paste(_ text: String, restoreClipboard: Bool = true) -> Bool {
        let pb = NSPasteboard.general
        let previous: [NSPasteboard.PasteboardType: Data] = {
            guard restoreClipboard else { return [:] }
            var snapshot: [NSPasteboard.PasteboardType: Data] = [:]
            for type in pb.types ?? [] {
                if let data = pb.data(forType: type) {
                    snapshot[type] = data
                }
            }
            return snapshot
        }()

        pb.clearContents()
        guard pb.setString(text, forType: .string) else { return false }

        let source = CGEventSource(stateID: .hidSystemState)
        let steps: [(CGKeyCode, Bool, CGEventFlags)] = [
            (commandKey, true, .maskCommand),
            (vKey, true, .maskCommand),
            (vKey, false, .maskCommand),
            (commandKey, false, []),
        ]
        for (key, down, flags) in steps {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else {
                return false
            }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }

        if restoreClipboard, !previous.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                pb.clearContents()
                for (type, data) in previous {
                    pb.setData(data, forType: type)
                }
            }
        }
        return true
    }
}
