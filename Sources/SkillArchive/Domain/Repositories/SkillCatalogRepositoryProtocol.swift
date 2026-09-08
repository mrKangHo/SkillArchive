import Foundation

protocol SkillCatalogRepositoryProtocol: Sendable {
    func scanCatalog(projects: [ProjectLocation], canonicalDir: URL) -> [CatalogEntry]
    func backupToCanonical(_ folder: SkillFolder, canonicalDir: URL) throws
    func linkProjectToCanonical(name: String, projectFolder: SkillFolder, canonicalDir: URL) throws
    func install(skillName: String, into agent: AgentLocation, canonicalDir: URL) throws
    func removeFromAgent(skillName: String, agent: AgentLocation) throws
    func migrateCanonicalStore(from oldDir: URL, to newDir: URL) throws
    func prefetchDownload(_ url: URL)
}
