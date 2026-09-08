import Foundation

protocol SettingsRepositoryProtocol: AnyObject {
    var canonicalStorePath: String { get set }
    var canonicalDirURL: URL { get }
    var isDefault: Bool { get }
    var enabledAgentIDs: Set<String> { get set }
}
