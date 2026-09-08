import Foundation

protocol ManageSettingsUseCaseProtocol: AnyObject {
    var canonicalStorePath: String { get set }
    var canonicalDirURL: URL { get }
    var isDefault: Bool { get }
    var enabledAgentIDs: Set<String> { get set }
}

final class ManageSettingsUseCase: ManageSettingsUseCaseProtocol {
    private let repository: SettingsRepositoryProtocol

    init(repository: SettingsRepositoryProtocol) {
        self.repository = repository
    }

    var canonicalStorePath: String {
        get { repository.canonicalStorePath }
        set { repository.canonicalStorePath = newValue }
    }

    var canonicalDirURL: URL {
        repository.canonicalDirURL
    }

    var isDefault: Bool {
        repository.isDefault
    }

    var enabledAgentIDs: Set<String> {
        get { repository.enabledAgentIDs }
        set { repository.enabledAgentIDs = newValue }
    }
}
