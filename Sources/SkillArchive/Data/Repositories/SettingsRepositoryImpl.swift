import Foundation

final class SettingsRepositoryImpl: SettingsRepositoryProtocol {
    private let store: SettingsStore
    private let enabledAgentsKey = "skillhub.enabledAgentIDs.v1"

    init(store: SettingsStore) {
        self.store = store
    }

    var canonicalStorePath: String {
        get { store.canonicalStorePath }
        set { store.canonicalStorePath = newValue }
    }

    var canonicalDirURL: URL {
        store.canonicalDirURL
    }

    var isDefault: Bool {
        store.isDefault
    }

    var enabledAgentIDs: Set<String> {
        get {
            if let saved = UserDefaults.standard.array(forKey: enabledAgentsKey) as? [String] {
                return Set(saved)
            }
            return Set(Registry.agents.map(\.id))
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: enabledAgentsKey)
        }
    }
}
