import Foundation

final class SkillCatalogRepositoryImpl: SkillCatalogRepositoryProtocol {
    init() {}

    func scanCatalog(projects: [ProjectLocation], canonicalDir: URL) -> [CatalogEntry] {
        Scanner.buildCatalog(projects: projects, canonicalDir: canonicalDir)
    }

    func backupToCanonical(_ folder: SkillFolder, canonicalDir: URL) throws {
        try Operations.backupToCanonical(folder, canonicalDir: canonicalDir)
    }

    func linkProjectToCanonical(name: String, projectFolder: SkillFolder, canonicalDir: URL) throws {
        try Operations.linkProjectToCanonical(name: name, projectFolder: projectFolder, canonicalDir: canonicalDir)
    }

    func install(skillName: String, into agent: AgentLocation, canonicalDir: URL) throws {
        try Operations.install(skillName: skillName, into: agent, canonicalDir: canonicalDir)
    }

    func removeFromAgent(skillName: String, agent: AgentLocation) throws {
        try Operations.removeFromAgent(skillName: skillName, agent: agent)
    }

    func migrateCanonicalStore(from oldDir: URL, to newDir: URL) throws {
        try Operations.migrateCanonicalStore(from: oldDir, to: newDir)
    }

    func prefetchDownload(_ url: URL) {
        Operations.prefetchDownload(url)
    }
}
