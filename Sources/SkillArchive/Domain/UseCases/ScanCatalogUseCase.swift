import Foundation

protocol ScanCatalogUseCaseProtocol: Sendable {
    func execute(projects: [ProjectLocation], canonicalDir: URL) -> [CatalogEntry]
}

final class ScanCatalogUseCase: ScanCatalogUseCaseProtocol {
    private let repository: SkillCatalogRepositoryProtocol

    init(repository: SkillCatalogRepositoryProtocol) {
        self.repository = repository
    }

    func execute(projects: [ProjectLocation], canonicalDir: URL) -> [CatalogEntry] {
        repository.scanCatalog(projects: projects, canonicalDir: canonicalDir)
    }
}
