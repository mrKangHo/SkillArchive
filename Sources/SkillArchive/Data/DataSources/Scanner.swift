import Foundation

enum Scanner {
    private static let fm = FileManager.default

    /// List immediate subdirectories of `dir` that look like skill folders (contain SKILL.md),
    /// skipping hidden/system entries and names in `exclude`.
    static func scanFolder(_ dir: URL, exclude: Set<String> = []) -> [SkillFolder] {
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var result: [SkillFolder] = []
        for item in items {
            let name = item.lastPathComponent
            if name.hasPrefix(".") || exclude.contains(name) { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let skillMD = item.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillMD.path) else { continue }
            let isSymlink = (try? fm.destinationOfSymbolicLink(atPath: item.path)) != nil
            let desc = parseDescription(skillMD)
            result.append(SkillFolder(name: name, url: item, origin: .canonical, description: desc, isSymlink: isSymlink))
        }
        return result.sorted { $0.name < $1.name }
    }

    static func scanAgent(_ agent: AgentLocation) -> [SkillFolder] {
        scanFolder(agent.resolvedURL, exclude: agent.excludeNames).map {
            SkillFolder(name: $0.name, url: $0.url, origin: .agent(agentID: agent.id), description: $0.description, isSymlink: $0.isSymlink)
        }
    }

    static func scanProject(_ project: ProjectLocation) -> [SkillFolder] {
        scanFolder(project.resolvedURL).map {
            SkillFolder(name: $0.name, url: $0.url, origin: .project(projectPath: project.path), description: $0.description, isSymlink: $0.isSymlink)
        }
    }

    static func scanCanonical(_ canonicalDir: URL) -> [SkillFolder] {
        scanFolder(canonicalDir)
    }

    /// Very small YAML frontmatter reader: pulls `description:` out of SKILL.md.
    private static func parseDescription(_ skillMD: URL) -> String? {
        guard let text = try? String(contentsOf: skillMD, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n").prefix(30) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("description:") {
                var value = String(trimmed.dropFirst("description:".count)).trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count > 1 {
                    value = String(value.dropFirst().dropLast())
                }
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    /// Build the unified catalog from every known source.
    static func buildCatalog(projects: [ProjectLocation], canonicalDir: URL) -> [CatalogEntry] {
        var entries: [String: CatalogEntry] = [:]

        func upsert(_ folder: SkillFolder, agentID: String? = nil, project: ProjectLocation? = nil, isCanonical: Bool = false) {
            var entry = entries[folder.name] ?? CatalogEntry(name: folder.name, description: folder.description)
            if entry.description == nil { entry.description = folder.description }
            if isCanonical { entry.canonical = folder }
            if let agentID { entry.agentCopies[agentID] = folder }
            if let project { entry.projectCopies[project] = folder }
            entries[folder.name] = entry
        }

        for folder in scanCanonical(canonicalDir) {
            upsert(folder, isCanonical: true)
        }
        for agent in Registry.agents {
            for folder in scanAgent(agent) {
                upsert(folder, agentID: agent.id)
            }
        }
        for project in projects {
            for folder in scanProject(project) {
                upsert(folder, project: project)
            }
        }

        let allAgentIDs = Set(Registry.agents.map { $0.id })
        for (name, var entry) in entries {
            let have = Set(entry.agentCopies.keys)
            entry.missingAgents = allAgentIDs.subtracting(have).sorted()
            entries[name] = entry
        }

        return entries.values.sorted { $0.name < $1.name }
    }
}
