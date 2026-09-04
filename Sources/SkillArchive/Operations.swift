import Foundation

enum SkillOpError: LocalizedError {
    case alreadyExists(String)
    case sourceMissing(String)
    case fileManager(Error)

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let p): return String(localized: "이미 존재함: \(p)")
        case .sourceMissing(let p): return String(localized: "원본 없음: \(p)")
        case .fileManager(let e): return e.localizedDescription
        }
    }
}

enum Operations {
    private static let fm = FileManager.default

    /// Copy a skill folder (from an agent's global dir, or a project) into the canonical store.
    static func backupToCanonical(_ folder: SkillFolder, canonicalDir: URL) throws {
        try fm.createDirectory(at: canonicalDir, withIntermediateDirectories: true)
        let dest = canonicalDir.appendingPathComponent(folder.name)
        guard !fm.fileExists(atPath: dest.path) else { throw SkillOpError.alreadyExists(dest.path) }
        guard fm.fileExists(atPath: folder.url.path) else { throw SkillOpError.sourceMissing(folder.url.path) }
        do {
            try copyResolvingSymlinks(from: folder.url, to: dest)
        } catch {
            throw SkillOpError.fileManager(error)
        }
    }

    /// Replace a project's local copy with a symlink pointing at the canonical copy.
    static func linkProjectToCanonical(name: String, projectFolder: SkillFolder, canonicalDir: URL) throws {
        let canonical = canonicalDir.appendingPathComponent(name)
        guard fm.fileExists(atPath: canonical.path) else { throw SkillOpError.sourceMissing(canonical.path) }
        do {
            if fm.fileExists(atPath: projectFolder.url.path) {
                try fm.removeItem(at: projectFolder.url)
            }
            try fm.createSymbolicLink(at: projectFolder.url, withDestinationURL: canonical)
        } catch {
            throw SkillOpError.fileManager(error)
        }
    }

    /// Install a canonical skill into one agent's global skills folder (always a real copy,
    /// so each agent's install is independent and survives the canonical store moving/renaming).
    static func install(skillName: String, into agent: AgentLocation, canonicalDir: URL) throws {
        let canonical = canonicalDir.appendingPathComponent(skillName)
        guard fm.fileExists(atPath: canonical.path) else { throw SkillOpError.sourceMissing(canonical.path) }
        let agentDir = agent.resolvedURL
        try fm.createDirectory(at: agentDir, withIntermediateDirectories: true)
        let dest = agentDir.appendingPathComponent(skillName)
        if fm.fileExists(atPath: dest.path) || isSymlink(dest) {
            try fm.removeItem(at: dest)
        }
        do {
            try copyResolvingSymlinks(from: canonical, to: dest)
        } catch {
            throw SkillOpError.fileManager(error)
        }
    }

    /// Move every skill folder from one canonical store location to another (used when the
    /// user changes the backup location in Settings). Existing same-named folders at the
    /// destination are left untouched rather than overwritten.
    static func migrateCanonicalStore(from oldDir: URL, to newDir: URL) throws {
        guard fm.fileExists(atPath: oldDir.path) else { return }
        try fm.createDirectory(at: newDir, withIntermediateDirectories: true)
        let items = try fm.contentsOfDirectory(at: oldDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for item in items {
            let dest = newDir.appendingPathComponent(item.lastPathComponent)
            if fm.fileExists(atPath: dest.path) { continue }
            try fm.moveItem(at: item, to: dest)
        }
    }

    /// Best-effort: recursively ask iCloud to start downloading every file under `url`.
    /// Evicted iCloud Drive files otherwise only download the moment something tries to read
    /// them (e.g. inside `copyItem`), which serializes an entire folder's download behind
    /// whatever operation happens to touch it first.
    static func prefetchDownload(_ url: URL) {
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) else { return }
        for case let fileURL as URL in enumerator {
            try? fm.startDownloadingUbiquitousItem(at: fileURL)
        }
    }

    static func removeFromAgent(skillName: String, agent: AgentLocation) throws {
        let dest = agent.resolvedURL.appendingPathComponent(skillName)
        guard fm.fileExists(atPath: dest.path) || isSymlink(dest) else { return }
        try fm.removeItem(at: dest)
    }

    private static func isSymlink(_ url: URL) -> Bool {
        (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    /// Copy a directory; if the source itself is a symlink, copy what it points to.
    private static func copyResolvingSymlinks(from: URL, to: URL) throws {
        let realSource: URL
        if let dest = try? fm.destinationOfSymbolicLink(atPath: from.path) {
            realSource = URL(fileURLWithPath: dest, relativeTo: from.deletingLastPathComponent()).standardizedFileURL
        } else {
            realSource = from
        }
        try fm.copyItem(at: realSource, to: to)
    }
}
