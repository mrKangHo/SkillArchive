import Foundation

protocol ManageProjectsUseCaseProtocol: AnyObject {
    var projects: [ProjectLocation] { get }
    func add(url: URL)
    func remove(_ loc: ProjectLocation)
}

final class ManageProjectsUseCase: ManageProjectsUseCaseProtocol {
    private let repository: ProjectRepositoryProtocol

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    var projects: [ProjectLocation] {
        repository.projects
    }

    func add(url: URL) {
        repository.add(url: url)
    }

    func remove(_ loc: ProjectLocation) {
        repository.remove(loc)
    }
}
