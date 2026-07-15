import CoreGraphics
import Foundation

/// Persisted push-to-talk hotkey (default: Spacebar).
enum HotkeyPreferences {
    private static let idKey = "fastflow.hotkey.presetID"
    private static let setupKey = "fastflow.hasCompletedSetupWizard"

    static var hasCompletedSetupWizard: Bool {
        get { UserDefaults.standard.bool(forKey: setupKey) }
        set { UserDefaults.standard.set(newValue, forKey: setupKey) }
    }

    static var presetID: String {
        get {
            UserDefaults.standard.string(forKey: idKey) ?? HotkeyMonitor.Preset.space.id
        }
        set {
            UserDefaults.standard.set(newValue, forKey: idKey)
        }
    }

    static var currentPreset: HotkeyMonitor.Preset {
        HotkeyMonitor.Preset.all.first { $0.id == presetID } ?? .space
    }
}

/// Where the living status blob docks on screen.
enum BlobCorner: String, CaseIterable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var displayName: String {
        switch self {
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        }
    }
}

enum BlobPreferences {
    private static let cornerKey = "fastflow.blob.corner"
    private static let visibleKey = "fastflow.blob.visible"

    static var corner: BlobCorner {
        get {
            if let raw = UserDefaults.standard.string(forKey: cornerKey),
               let c = BlobCorner(rawValue: raw) {
                return c
            }
            return .bottomRight
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: cornerKey) }
    }

    static var isVisible: Bool {
        get {
            if UserDefaults.standard.object(forKey: visibleKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: visibleKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: visibleKey) }
    }
}
