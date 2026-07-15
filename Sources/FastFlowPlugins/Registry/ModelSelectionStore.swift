import Foundation
import Security

/// User-selected ASR plug-in id + API keys for cloud providers.
///
/// Local free models need no keys. Cloud plugins (HF / OpenRouter / Gemini)
/// store keys in the Keychain when possible, with UserDefaults fallback for MVP.
public enum ModelSelectionStore {
    private static let selectedKey = "fastflow.selectedASRPluginID"
    private static let service = "app.fastflow.macos.providers"

    /// Preferred ASR id. Empty → resolve local default.
    public static var selectedASRID: String? {
        get {
            let v = UserDefaults.standard.string(forKey: selectedKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (v?.isEmpty == false) ? v : nil
        }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: selectedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: selectedKey)
            }
        }
    }

    public static func clearSelection() {
        selectedASRID = nil
    }

    public static func apiKey(for family: ModelProviderFamily) -> String? {
        guard family != .local else { return nil }
        if let key = keychainGet(account: family.rawValue), !key.isEmpty { return key }
        let legacy = UserDefaults.standard.string(forKey: "fastflow.apikey.\(family.rawValue)")
        return (legacy?.isEmpty == false) ? legacy : nil
    }

    public static func setAPIKey(_ key: String?, for family: ModelProviderFamily) {
        guard family != .local else { return }
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            _ = keychainSet(account: family.rawValue, value: trimmed)
            UserDefaults.standard.set(trimmed, forKey: "fastflow.apikey.\(family.rawValue)")
        } else {
            _ = keychainDelete(account: family.rawValue)
            UserDefaults.standard.removeObject(forKey: "fastflow.apikey.\(family.rawValue)")
        }
    }

    public static func hasAPIKey(for family: ModelProviderFamily) -> Bool {
        apiKey(for: family) != nil
    }

    // MARK: - Keychain helpers (module-internal for BYO)

    static func keychainSet(account: String, value: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func keychainGet(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func keychainDelete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
