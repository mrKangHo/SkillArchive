import Foundation

struct AgentLocation: Identifiable, Hashable {
    let id: String
    let displayName: String
    let globalSkillsPath: String   // may contain ~
    let excludeNames: Set<String>  // folder names to hide (agent built-in skills)

    var resolvedURL: URL {
        URL(fileURLWithPath: (globalSkillsPath as NSString).expandingTildeInPath)
    }

    /// Whether this agent's config folder exists on this machine at all — the skills
    /// subfolder itself may not exist yet, so this checks one level up.
    var isInstalledOnDisk: Bool {
        FileManager.default.fileExists(atPath: resolvedURL.deletingLastPathComponent().path)
    }
}

struct ProjectLocation: Identifiable, Hashable, Codable {
    var id: String { path }
    let projectName: String
    let path: String // absolute path to a *skills* folder inside a project

    var resolvedURL: URL {
        URL(fileURLWithPath: path)
    }
}

enum SkillOrigin: Hashable {
    case agent(agentID: String)
    case project(projectPath: String)
    case canonical
}

struct SkillFolder: Identifiable, Hashable {
    var id: String { origin.hashValue.description + "/" + name }
    let name: String
    let url: URL
    let origin: SkillOrigin
    let description: String?
    let isSymlink: Bool
}

/// One row in the unified catalog: a skill name aggregated across every place it was found.
struct CatalogEntry: Identifiable {
    var id: String { name }
    let name: String
    var description: String?
    var canonical: SkillFolder?
    var agentCopies: [String: SkillFolder] = [:]     // agentID -> folder
    var projectCopies: [ProjectLocation: SkillFolder] = [:]

    var isPromotable: Bool { canonical == nil && !projectCopies.isEmpty }
    var isBackupable: Bool { canonical == nil && !agentCopies.isEmpty && projectCopies.isEmpty }
    var missingAgents: [String] = [] // agentIDs that could receive this skill but don't have it
}
