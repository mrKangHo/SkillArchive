import Foundation

protocol ManageSkillUseCaseProtocol: Sendable {
    func backupToCanonical(_ folder: SkillFolder, canonicalDir: URL) throws
    func linkProjectToCanonical(name: String, projectFolder: SkillFolder, canonicalDir: URL) throws
    func install(skillName: String, into agent: AgentLocation, canonicalDir: URL) throws
    func removeFromAgent(skillName: String, agent: AgentLocation) throws
    func migrateCanonicalStore(from oldDir: URL, to newDir: URL) throws
    func prefetchDownload(_ url: URL)
}

final class ManageSkillUseCase: ManageSkillUseCaseProtocol {
    private let repository: SkillCatalogRepositoryProtocol

    init(repository: SkillCatalogRepositoryProtocol) {
        self.repository = repository
    }

    func backupToCanonical(_ folder: SkillFolder, canonicalDir: URL) throws {
        try repository.backupToCanonical(folder, canonicalDir: canonicalDir)
    }

    func linkProjectToCanonical(name: String, projectFolder: SkillFolder, canonicalDir: URL) throws {
        try repository.linkProjectToCanonical(name: name, projectFolder: projectFolder, canonicalDir: canonicalDir)
    }

    func install(skillName: String, into agent: AgentLocation, canonicalDir: URL) throws {
        try repository.install(skillName: skillName, into: agent, canonicalDir: canonicalDir)
    }

    func removeFromAgent(skillName: String, agent: AgentLocation) throws {
        try repository.removeFromAgent(skillName: skillName, agent: agent)
    }

    func migrateCanonicalStore(from oldDir: URL, to newDir: URL) throws {
        try repository.migrateCanonicalStore(from: oldDir, to: newDir)
    }

    func prefetchDownload(_ url: URL) {
        repository.prefetchDownload(url)
    }
}
