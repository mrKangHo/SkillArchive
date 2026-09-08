import Foundation

final class ProjectRepositoryImpl: ProjectRepositoryProtocol {
    private let store: ProjectStore

    init(store: ProjectStore) {
        self.store = store
    }

    var projects: [ProjectLocation] {
        store.projects
    }

    func add(url: URL) {
        store.add(url: url)
    }

    func remove(_ loc: ProjectLocation) {
        store.remove(loc)
    }
}
