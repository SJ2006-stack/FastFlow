import AppKit
import AVFoundation
import FastFlowPlugins
import Foundation

/// First-run: permissions → custom hotkey (default Spacebar) → blob corner.
@MainActor
enum SetupWizard {
    /// Runs once until completed. Returns chosen hotkey + corner.
    static func runIfNeeded() -> (hotkey: HotkeyMonitor.Preset, corner: BlobCorner) {
        if HotkeyPreferences.hasCompletedSetupWizard {
            return (HotkeyPreferences.currentPreset, BlobPreferences.corner)
        }
        NSApp.activate(ignoringOtherApps: true)
        runPermissionsStep()
        let hotkey = runHotkeyStep()
        let corner = runCornerStep()
        HotkeyPreferences.presetID = hotkey.id
        BlobPreferences.corner = corner
        BlobPreferences.isVisible = true
        HotkeyPreferences.hasCompletedSetupWizard = true
        return (hotkey, corner)
    }

    // MARK: - Permissions

    private static func runPermissionsStep() {
        while true {
            let alert = NSAlert()
            alert.messageText = "Allow FastFlow to work"
            alert.informativeText = """
            FastFlow needs a couple of Mac permissions so push-to-talk and paste work:

            • Microphone — hear what you dictate
            • Accessibility — global hotkey + insert text at the cursor

            Turn both on, then continue to pick your hotkey.
            """

            let micOK = PermissionGate.microphoneAuthorized()
            let axOK = PermissionGate.accessibilityTrusted()
            let status = NSTextField(labelWithString: """
            Microphone: \(micOK ? "Allowed ✓" : "Not allowed yet")
            Accessibility: \(axOK ? "Allowed ✓" : "Not allowed yet")
            """)
            status.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            alert.accessoryView = status

            if micOK, axOK {
                alert.addButton(withTitle: "Continue")
                alert.addButton(withTitle: "Open Settings")
                let r = alert.runModal()
                if r == .alertFirstButtonReturn { return }
                PermissionGate.openSystemSettings(for: .microphone)
                PermissionGate.promptAccessibility()
                continue
            }

            alert.addButton(withTitle: "Enable Microphone")
            alert.addButton(withTitle: "Enable Accessibility")
            alert.addButton(withTitle: "I’ve enabled them — Continue")
            let r = alert.runModal()
            switch r {
            case .alertFirstButtonReturn:
                Task { _ = await PermissionGate.requestMicrophone() }
                // Brief wait so the system prompt can appear.
                Thread.sleep(forTimeInterval: 0.4)
                if !PermissionGate.microphoneAuthorized() {
                    PermissionGate.openSystemSettings(for: .microphone)
                }
            case .alertSecondButtonReturn:
                PermissionGate.promptAccessibility()
                PermissionGate.openSystemSettings(for: .accessibility)
            default:
                if PermissionGate.microphoneAuthorized(), PermissionGate.accessibilityTrusted() {
                    return
                }
                // Allow continue anyway so power users aren’t stuck; hotkey may fail until granted.
                return
            }
        }
    }

    // MARK: - Hotkey

    private static func runHotkeyStep() -> HotkeyMonitor.Preset {
        let alert = NSAlert()
        alert.messageText = "Choose your push-to-talk key"
        alert.informativeText = """
        Hold the key to dictate, release to insert text.

        Default is Spacebar — great for hands-on typing workflows.
        (While you hold it, FastFlow keeps Space from typing into the field.)
        """

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 320, height: 28), pullsDown: false)
        for preset in HotkeyMonitor.Preset.all {
            popup.addItem(withTitle: preset.name)
            popup.lastItem?.representedObject = preset.id
        }
        // Default selection: Spacebar
        if let idx = HotkeyMonitor.Preset.all.firstIndex(where: { $0.id == HotkeyMonitor.Preset.space.id }) {
            popup.selectItem(at: idx)
        }
        alert.accessoryView = popup
        alert.addButton(withTitle: "Use this hotkey")

        _ = alert.runModal()
        let id = (popup.selectedItem?.representedObject as? String) ?? HotkeyMonitor.Preset.space.id
        return HotkeyMonitor.Preset.all.first { $0.id == id } ?? .space
    }

    // MARK: - Blob corner

    private static func runCornerStep() -> BlobCorner {
        let alert = NSAlert()
        alert.messageText = "Park the FastFlow blob"
        alert.informativeText = """
        A tiny living blob stays on your screen so you always know FastFlow is around.

        Pick a corner — you can move it later from the menu bar.
        """

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 28), pullsDown: false)
        for corner in BlobCorner.allCases {
            popup.addItem(withTitle: corner.displayName)
            popup.lastItem?.representedObject = corner.rawValue
        }
        if let idx = BlobCorner.allCases.firstIndex(of: .bottomRight) {
            popup.selectItem(at: idx)
        }
        alert.accessoryView = popup
        alert.addButton(withTitle: "Finish setup")
        _ = alert.runModal()

        let raw = (popup.selectedItem?.representedObject as? String) ?? BlobCorner.bottomRight.rawValue
        return BlobCorner(rawValue: raw) ?? .bottomRight
    }
}
