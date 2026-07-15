import Foundation

extension ModelSelectionStore {
    private static let onboardingKey = "fastflow.hasCompletedModelOnboarding"
    private static let byoConfigsKey = "fastflow.byoModelConfigsJSON"

    /// First-launch model picker must run until the user picks FREE or BYO.
    public static var hasCompletedModelOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    public static func resetOnboardingForTesting() {
        hasCompletedModelOnboarding = false
    }

    // MARK: - BYO model configs (developer / power-user)

    public struct BYOModelConfig: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var displayName: String
        /// Full HTTPS endpoint that accepts audio (WAV) or JSON with base64.
        public var endpointURL: String
        public var remoteModelID: String?
        /// `bearer` → Authorization: Bearer <key>; `header` uses customHeaderName.
        public var authStyle: String
        public var customHeaderName: String?
        /// `audioWav` posts raw WAV; `jsonBase64` posts `{"audio_base64":"...","model":"..."}`.
        public var bodyStyle: String

        public init(
            id: String = "asr.byo.\(UUID().uuidString.prefix(8))",
            displayName: String,
            endpointURL: String,
            remoteModelID: String? = nil,
            authStyle: String = "bearer",
            customHeaderName: String? = nil,
            bodyStyle: String = "audioWav"
        ) {
            self.id = id
            self.displayName = displayName
            self.endpointURL = endpointURL
            self.remoteModelID = remoteModelID
            self.authStyle = authStyle
            self.customHeaderName = customHeaderName
            self.bodyStyle = bodyStyle
        }
    }

    public static func byoConfigs() -> [BYOModelConfig] {
        guard let data = UserDefaults.standard.data(forKey: byoConfigsKey),
              let decoded = try? JSONDecoder().decode([BYOModelConfig].self, from: data)
        else { return [] }
        return decoded
    }

    public static func saveBYOConfigs(_ configs: [BYOModelConfig]) {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: byoConfigsKey)
        }
    }

    public static func upsertBYO(_ config: BYOModelConfig) {
        var all = byoConfigs().filter { $0.id != config.id }
        all.append(config)
        saveBYOConfigs(all)
    }

    public static func removeBYO(id: String) {
        saveBYOConfigs(byoConfigs().filter { $0.id != id })
    }

    /// API key for a BYO model (stored under its id).
    public static func byoAPIKey(forConfigID id: String) -> String? {
        if let key = keychainGet(account: "byo.\(id)"), !key.isEmpty { return key }
        return UserDefaults.standard.string(forKey: "fastflow.apikey.byo.\(id)")
    }

    public static func setBYOAPIKey(_ key: String?, forConfigID id: String) {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = "byo.\(id)"
        if let trimmed, !trimmed.isEmpty {
            _ = keychainSet(account: account, value: trimmed)
            UserDefaults.standard.set(trimmed, forKey: "fastflow.apikey.byo.\(id)")
        } else {
            _ = keychainDelete(account: account)
            UserDefaults.standard.removeObject(forKey: "fastflow.apikey.byo.\(id)")
        }
    }
}
