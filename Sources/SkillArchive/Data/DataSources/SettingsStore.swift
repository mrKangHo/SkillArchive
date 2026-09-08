import Foundation

/// Persists where the canonical skill store lives. Defaults to iCloud Drive so a backup
/// survives an OS reinstall or a move to a new Mac; editable from Settings.
final class SettingsStore: ObservableObject {
    private let key = "skillhub.canonicalStorePath.v1"

    @Published var canonicalStorePath: String {
        didSet { UserDefaults.standard.set(canonicalStorePath, forKey: key) }
    }

    init() {
        canonicalStorePath = UserDefaults.standard.string(forKey: key)
            ?? Registry.expand(Registry.defaultCanonicalStorePath)
    }

    var canonicalDirURL: URL {
        URL(fileURLWithPath: canonicalStorePath)
    }

    var isDefault: Bool {
        canonicalStorePath == Registry.expand(Registry.defaultCanonicalStorePath)
    }
}
